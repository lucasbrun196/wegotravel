import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/services/media/local_media.dart';
import '../../../data/services/media/media_picker.dart';
import '../../../shared/widgets/feedback/app_toast.dart';
import '../../../shared/widgets/layout/app_sheet.dart';
import '../controllers/board_controllers.dart';
import 'caption_sheet.dart' show captionMaxLength;

/// Separa o que dá para postar do que fica de fora — arquivo que não é foto
/// nem vídeo, ou maior que o limite — e avisa o porquê.
List<LocalMedia> acceptMedia(List<LocalMedia> files) {
  final ok = <LocalMedia>[];
  final problems = <String>[];
  for (final file in files) {
    if (!file.isImage && !file.isVideo) {
      problems.add('${file.name} não é foto nem vídeo');
      file.dispose();
    } else if (file.sizeBytes > maxMediaBytes) {
      problems.add('${file.name} tem ${Fmt.fileSize(file.sizeBytes)}, e o limite é 150 MB');
      file.dispose();
    } else {
      ok.add(file);
    }
  }
  if (problems.isNotEmpty) {
    AppToast.warning(
      problems.length == 1
          ? problems.first
          : '${problems.length} arquivos ficaram de fora. ${problems.first}.',
    );
  }
  return ok;
}

/// A revisão antes de postar: o que foi escolhido, uma legenda para cada e
/// o botão de pôr mais — um por um, ou vários de novo.
///
/// Devolve os arquivos com a legenda de cada, ou `null` se a pessoa
/// desistiu.
Future<List<(LocalMedia, String?)>?> showImportReview(
  BuildContext context,
  List<LocalMedia> files,
) => showAppSheet<List<(LocalMedia, String?)>>(
  context: context,
  title: 'Postar no mural',
  maxWidth: 720,
  builder: (_) => _ImportReview(initial: files),
);

class _Item {
  _Item(this.media);

  final LocalMedia media;
  final caption = TextEditingController();
}

class _ImportReview extends StatefulWidget {
  const _ImportReview({required this.initial});

  final List<LocalMedia> initial;

  @override
  State<_ImportReview> createState() => _ImportReviewState();
}

class _ImportReviewState extends State<_ImportReview> {
  late final List<_Item> _items = [for (final m in widget.initial) _Item(m)];
  int _current = 0;

  /// Postado, os arquivos passam para a fila de envio, que cuida deles
  /// dali em diante. Desistindo, eles são liberados aqui.
  bool _handedOff = false;

  @override
  void dispose() {
    for (final item in _items) {
      item.caption.dispose();
      if (!_handedOff) item.media.dispose();
    }
    super.dispose();
  }

  Future<void> _addMore() async {
    final picked = acceptMedia(await pickMedia());
    if (!mounted || picked.isEmpty) return;
    setState(() {
      _current = _items.length;
      _items.addAll(picked.map(_Item.new));
    });
  }

  void _remove(int index) {
    final item = _items.removeAt(index);
    item.caption.dispose();
    item.media.dispose();
    if (_items.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _current = _current.clamp(0, _items.length - 1));
  }

  void _post() {
    _handedOff = true;
    Navigator.of(context).pop([
      for (final item in _items)
        (item.media, item.caption.text.trim().isEmpty ? null : item.caption.text.trim()),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_current];
    final videos = _items.where((i) => i.media.isVideo).length;
    final photos = _items.length - videos;
    final duration = context.reduceMotion ? Duration.zero : Motion.normal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Altura limitada: numa tela baixa a prévia empurraria a tira e
                // a legenda para fora da vista.
                SizedBox(
                  height: (MediaQuery.sizeOf(context).height * 0.34).clamp(180.0, 420.0),
                  child: ClipRRect(
                    borderRadius: Radii.brLg,
                    child: ColoredBox(
                      color: context.isDark ? AppColors.darkBackground : AppColors.night,
                      child: AnimatedSwitcher(
                        duration: duration,
                        switchInCurve: Motion.enter,
                        child: _Preview(key: ObjectKey(item.media), media: item.media),
                      ),
                    ),
                  ),
                ),
                Gap.vMd,
                Row(
                  children: [
                    Expanded(
                      child: Text(mediaCountLabel(photos, videos), style: context.text.labelLarge),
                    ),
                    TextButton.icon(
                      onPressed: () => _remove(_current),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(item.media.isVideo ? 'Remover este vídeo' : 'Remover esta foto'),
                    ),
                  ],
                ),
                Gap.vSm,
                SizedBox(
                  height: 68,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _items.length + 1,
                    separatorBuilder: (_, _) => Gap.hSm,
                    itemBuilder: (context, i) => i == _items.length
                        ? _AddTile(onTap: _addMore)
                        : _Thumb(
                            media: _items[i].media,
                            selected: i == _current,
                            onTap: () => setState(() => _current = i),
                          ),
                  ),
                ),
                Gap.vLg,
                TextField(
                  key: ObjectKey(item),
                  controller: item.caption,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: captionMaxLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: item.media.isVideo ? 'Legenda deste vídeo' : 'Legenda desta foto',
                    hintText: 'Opcional',
                  ),
                ),
              ],
            ),
          ),
        ),
        SheetActions(
          primaryLabel: _items.length == 1 ? 'Postar' : 'Postar ${_items.length}',
          onPrimary: _post,
          secondaryLabel: 'Cancelar',
          onSecondary: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// A prévia grande. Vídeo não tem quadro antes de ser processado: mostra o
/// nome e o tamanho.
class _Preview extends StatelessWidget {
  const _Preview({super.key, required this.media});

  final LocalMedia media;

  @override
  Widget build(BuildContext context) {
    final preview = media.preview;
    if (preview != null) {
      return SizedBox.expand(
        child: Image(
          // A foto de 12 MP decodificada inteira só para caber numa prévia
          // gastaria memória à toa.
          image: ResizeImage(preview, width: 1400, policy: ResizeImagePolicy.fit),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _FileCard(media: media),
        ),
      );
    }
    return _FileCard(media: media);
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.media});

  final LocalMedia media;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              media.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
              size: 40,
              color: Colors.white70,
            ),
            Gap.vMd,
            Text(
              media.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall?.copyWith(color: Colors.white),
            ),
            Text(
              Fmt.fileSize(media.sizeBytes),
              style: context.text.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.media, required this.selected, required this.onTap});

  final LocalMedia media;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = media.preview;
    final duration = context.reduceMotion ? Duration.zero : Motion.normal;

    return Semantics(
      button: true,
      selected: selected,
      label: media.name,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: duration,
            // `Motion.enter`, e não `spring`: a folga vai a zero, e passar do
            // alvo a deixaria negativa.
            curve: Motion.enter,
            width: 68,
            padding: EdgeInsets.all(selected ? 3 : 0),
            decoration: BoxDecoration(
              borderRadius: Radii.brMd,
              border: Border.all(
                color: selected ? context.colors.primary : context.colors.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(selected ? Radii.sm : Radii.md - 1),
              child: ColoredBox(
                color: context.colors.surfaceContainerHigh,
                child: preview == null
                    ? Icon(
                        Icons.videocam_outlined,
                        size: 22,
                        color: context.colors.onSurfaceVariant,
                      )
                    : Image(
                        image: ResizeImage(preview, width: 160),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.image_outlined,
                          size: 22,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Pôr mais": abre o seletor de novo e soma ao que já está aqui.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Pôr mais fotos ou vídeos',
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.brMd,
        child: Container(
          width: 68,
          decoration: BoxDecoration(
            borderRadius: Radii.brMd,
            border: Border.all(color: context.colors.outline, width: 1.4),
          ),
          child: Icon(Icons.add_rounded, color: context.colors.onSurfaceVariant),
        ),
      ),
    );
  }
}
