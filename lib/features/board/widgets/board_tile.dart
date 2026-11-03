import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/initials.dart';
import '../../../data/models/board_post.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';
import 'board_image.dart';

/// O voo da foto entre a grade e a tela cheia: o canto arredondado do
/// quadro vira o canto reto da tela no caminho, em vez de trocar no fim.
Widget boardHeroShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromContext,
  BuildContext toContext,
) {
  final hero = (direction == HeroFlightDirection.push ? toContext.widget : fromContext.widget) as Hero;
  return AnimatedBuilder(
    animation: animation,
    child: hero.child,
    builder: (context, child) => ClipRRect(
      borderRadius: BorderRadius.circular(Radii.md * (1 - animation.value)),
      child: child,
    ),
  );
}

String boardHeroTag(BoardPost post) => 'mural-${post.id}';

/// Um quadro da grade do mural.
///
/// Com o mouse por cima, a foto se aproxima um pouco dentro da moldura e
/// sobe um véu com quem postou e a legenda. No modo de seleção, o quadro
/// escolhido encolhe dentro da célula e ganha a marca azul — o mesmo gesto
/// da galeria do celular.
class BoardTile extends StatefulWidget {
  const BoardTile({
    super.key,
    required this.post,
    required this.onTap,
    this.onLongPress,
    this.authorName,
    this.selecting = false,
    this.selected = false,
    this.busy = false,
  });

  final BoardPost post;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? authorName;
  final bool selecting;
  final bool selected;

  /// Uma ação está mexendo neste post (a exclusão): a foto apaga um pouco e
  /// um brilho de esqueleto passa por cima até ele sumir.
  final bool busy;

  @override
  State<BoardTile> createState() => _BoardTileState();
}

class _BoardTileState extends State<BoardTile> {
  bool _hovered = false;
  bool _pressed = false;

  /// Post que chegou agora há pouco — o da própria pessoa ou o de alguém da
  /// turma — entra crescendo, para ser notado.
  late final bool _arrived = _isFresh(widget.post);

  static bool _isFresh(BoardPost post) {
    final created = post.createdAt;
    return created == null || DateTime.now().difference(created) < const Duration(seconds: 12);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final still = context.reduceMotion;
    final duration = still ? Duration.zero : Motion.normal;
    final hovering = _hovered && !widget.selecting;

    Widget frame = ClipRRect(
      borderRadius: Radii.brMd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: boardHeroTag(post),
            flightShuttleBuilder: boardHeroShuttle,
            child: AnimatedScale(
              scale: hovering && !still ? 1.04 : 1,
              duration: Motion.lazy,
              curve: Motion.enter,
              child: BoardImage(path: post.gridPath, color: post.color, isVideo: post.isVideo),
            ),
          ),
          if (post.isVideo) Positioned(left: Gap.sm, bottom: Gap.sm, child: _VideoBadge(post: post)),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: hovering ? 1 : 0,
                duration: Motion.fast,
                curve: Motion.enter,
                child: _HoverVeil(post: post, authorName: widget.authorName),
              ),
            ),
          ),
          if (widget.busy)
            Positioned.fill(
              child: Skeleton(
                baseColor: AppColors.night.withValues(alpha: 0.45),
                highlightColor: Colors.white.withValues(alpha: 0.35),
                child: const ColoredBox(color: Colors.white),
              ),
            ),
          if (widget.selecting && !widget.busy)
            Positioned(
              top: Gap.sm,
              left: Gap.sm,
              child: _SelectMark(selected: widget.selected),
            ),
        ],
      ),
    );

    // Selecionado, o quadro encolhe na célula, que fica tingida de azul.
    // Sem o `Motion.spring`: ele passa do alvo, e a folga indo de 8 para 0
    // ficaria negativa no caminho — o Flutter recusa e o quadro pisca.
    frame = AnimatedContainer(
      duration: duration,
      curve: Motion.enter,
      padding: EdgeInsets.all(widget.selected ? Gap.sm : 0),
      decoration: BoxDecoration(
        color: widget.selected ? context.colors.primaryContainer : Colors.transparent,
        borderRadius: Radii.brMd,
      ),
      child: frame,
    );

    frame = AnimatedScale(
      scale: _pressed && !still ? 0.97 : 1,
      duration: Motion.instant,
      curve: Motion.enter,
      child: frame,
    );

    if (_arrived && !still) {
      frame = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.lazy,
        curve: Motion.spring,
        child: frame,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.86 + 0.14 * t, child: child),
        ),
      );
    }

    return Semantics(
      button: true,
      selected: widget.selecting ? widget.selected : null,
      label: _semanticLabel(post),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        // Só mouse de verdade: o Chrome do celular manda eventos de mouse
        // sintéticos ao tocar, e o véu ficaria preso.
        onEnter: (e) {
          if (e.kind == PointerDeviceKind.mouse) setState(() => _hovered = true);
        },
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: frame,
        ),
      ),
    );
  }

  String _semanticLabel(BoardPost post) {
    final what = post.isVideo ? 'Vídeo' : 'Foto';
    final who = widget.authorName ?? post.authorName;
    final when = '${Fmt.dayMonth(post.takenAt)}, ${Fmt.time(post.takenAt)}';
    return [what, if (who.isNotEmpty) 'de $who', when, if (post.hasCaption) post.caption!].join(', ');
  }
}

/// Selo de vídeo: o triângulo e a duração, sobre uma pílula escura.
class _VideoBadge extends StatelessWidget {
  const _VideoBadge({required this.post});

  final BoardPost post;

  @override
  Widget build(BuildContext context) {
    final duration = post.duration;
    return Container(
      padding: EdgeInsets.fromLTRB(Gap.xs, 2, duration == null ? Gap.xs : Gap.sm, 2),
      decoration: BoxDecoration(
        color: AppColors.night.withValues(alpha: 0.62),
        borderRadius: Radii.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
          if (duration != null) ...[
            const SizedBox(width: 2),
            Text(
              Fmt.duration(duration),
              style: AppTypography.numeric(size: 11.5, weight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

/// O véu de baixo, no hover: quem postou e o começo da legenda.
class _HoverVeil extends StatelessWidget {
  const _HoverVeil({required this.post, this.authorName});

  final BoardPost post;
  final String? authorName;

  @override
  Widget build(BuildContext context) {
    final name = (authorName ?? post.authorName).trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.45, 1],
          colors: [Colors.transparent, AppColors.night.withValues(alpha: 0.72)],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.fromLTRB(Gap.sm, 0, Gap.sm, post.isVideo ? 34 : Gap.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (name.isNotEmpty) ...[
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initialsOf(name),
                    style: context.text.labelSmall?.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.night,
                      height: 1,
                    ),
                  ),
                ),
                Gap.hSm,
              ],
              Expanded(
                child: Text(
                  post.hasCaption ? post.caption!.trim() : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(color: Colors.white, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O círculo de seleção: vazio com borda branca; marcado, azul com o visto.
class _SelectMark extends StatelessWidget {
  const _SelectMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final duration = context.reduceMotion ? Duration.zero : Motion.normal;
    return AnimatedContainer(
      duration: duration,
      curve: Motion.spring,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? context.colors.primary : AppColors.night.withValues(alpha: 0.25),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: duration,
        curve: Motion.spring,
        child: Icon(Icons.check_rounded, size: 15, color: context.colors.onPrimary),
      ),
    );
  }
}
