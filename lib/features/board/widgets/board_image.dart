import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';

/// Uma imagem do mural.
///
/// Pede o link ao Storage (que confere se a pessoa participa da viagem) e
/// mostra a foto quando ela chega, aparecendo por cima da cor média que o
/// quadro já tinha. Enquanto busca, essa cor brilha em esqueleto. Sem caminho — vídeo sem capa —, fica só a cor e o
/// ícone de vídeo.
class BoardImage extends ConsumerWidget {
  const BoardImage({
    super.key,
    required this.path,
    this.color,
    this.fit = BoxFit.cover,
    this.isVideo = false,
    this.iconSize = 22,
  });

  final String? path;
  final Color? color;
  final BoxFit fit;
  final bool isVideo;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = color ?? context.colors.surfaceContainerHigh;
    final onBase = base.computeLuminance() > 0.45
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.55);

    final path = this.path;

    Widget placeholder({IconData? icon, VoidCallback? onTap}) {
      final shown = icon ?? (isVideo && path == null ? Icons.videocam_outlined : null);
      final box = ColoredBox(
        color: base,
        child: shown == null ? null : Center(child: Icon(shown, size: iconSize, color: onBase)),
      );
      return onTap == null ? box : GestureDetector(onTap: onTap, child: box);
    }

    // Buscando o link ou baixando a foto: a cor do quadro brilha.
    Widget loading() => Skeleton(
          baseColor: base,
          highlightColor: Color.lerp(base, Colors.white, context.isDark ? 0.14 : 0.3),
          child: const ColoredBox(color: Colors.white, child: SizedBox.expand()),
        );

    if (path == null) return placeholder();

    final url = ref.watch(mediaUrlProvider(path));
    return url.when(
      loading: loading,
      // Sem rede, o link não sai: tocar no quadro pede de novo.
      error: (_, _) => placeholder(
        icon: Icons.refresh_rounded,
        onTap: () => ref.invalidate(mediaUrlProvider(path)),
      ),
      data: (url) => Image.network(
        url,
        fit: fit,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, sync) {
          if (sync) return child;
          return Stack(
            fit: StackFit.expand,
            children: [
              frame == null ? loading() : placeholder(),
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: context.reduceMotion ? Duration.zero : Motion.slow,
                curve: Motion.enter,
                child: child,
              ),
            ],
          );
        },
        errorBuilder: (_, _, _) => placeholder(icon: Icons.broken_image_outlined),
      ),
    );
  }
}
