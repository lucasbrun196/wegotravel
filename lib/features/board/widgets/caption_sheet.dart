import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/board_post.dart';
import '../../../shared/widgets/feedback/app_toast.dart';
import '../../../shared/widgets/layout/app_sheet.dart';

/// Legenda máxima, a mesma das regras do Firestore.
const captionMaxLength = 500;

Future<void> showCaptionSheet(BuildContext context, BoardPost post) => showAppSheet<void>(
      context: context,
      title: post.hasCaption ? 'Editar legenda' : 'Escrever legenda',
      builder: (_) => _CaptionForm(post: post),
    );

class _CaptionForm extends ConsumerStatefulWidget {
  const _CaptionForm({required this.post});

  final BoardPost post;

  @override
  ConsumerState<_CaptionForm> createState() => _CaptionFormState();
}

class _CaptionFormState extends ConsumerState<_CaptionForm> {
  late final _text = TextEditingController(text: widget.post.caption ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(boardRepositoryProvider)
          .updateCaption(ref.read(currentTripIdProvider), widget.post.id, _text.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.success('Legenda salva');
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      AppToast.error('Não deu para salvar a legenda');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            // Folga no topo para o rótulo flutuante não ser cortado.
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.lg),
            child: TextField(
              controller: _text,
              autofocus: true,
              minLines: 2,
              maxLines: 6,
              maxLength: captionMaxLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Legenda',
                hintText: 'Onde foi, quem estava junto',
              ),
            ),
          ),
        ),
        SheetActions(
          primaryLabel: 'Salvar',
          onPrimary: _save,
          secondaryLabel: 'Cancelar',
          onSecondary: () => Navigator.of(context).pop(),
          isLoading: _saving,
        ),
      ],
    );
  }
}
