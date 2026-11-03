import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/providers.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/board_post.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';

/// O vídeo na tela cheia.
///
/// O player só nasce quando a página do vídeo está na frente ([active]) —
/// passar por um vídeo no carrossel não baixa nada. Sai da frente, pausa.
/// A barra de controles fica com o visualizador, embaixo, junto da legenda
/// e das miniaturas: [onController] entrega o player a ela.
class BoardVideoPlayer extends ConsumerStatefulWidget {
  const BoardVideoPlayer({
    super.key,
    required this.post,
    required this.active,
    required this.togglePlay,
    required this.onTap,
    this.autoplay = false,
    this.onEnded,
    this.onController,
  });

  final BoardPost post;
  final bool active;

  /// Toque no vídeo fora do botão: mostra e esconde os controles.
  final VoidCallback onTap;

  /// Cada aviso alterna tocar e pausar — a barra de espaço do teclado.
  final Listenable togglePlay;
  final bool autoplay;

  /// Chamado quando o vídeo chega ao fim: a apresentação segue adiante.
  final VoidCallback? onEnded;

  /// O player pronto enquanto a página está na frente; `null` fora dela.
  final ValueChanged<VideoPlayerController?>? onController;

  @override
  ConsumerState<BoardVideoPlayer> createState() => _BoardVideoPlayerState();
}

class _BoardVideoPlayerState extends ConsumerState<BoardVideoPlayer> {
  VideoPlayerController? _controller;

  /// Por que o vídeo não toca aqui, quando não toca.
  String? _problem;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    widget.togglePlay.addListener(_onToggleKey);
    if (widget.active) _start(autoplay: widget.autoplay);
  }

  @override
  void didUpdateWidget(BoardVideoPlayer old) {
    super.didUpdateWidget(old);
    if (old.togglePlay != widget.togglePlay) {
      old.togglePlay.removeListener(_onToggleKey);
      widget.togglePlay.addListener(_onToggleKey);
    }
    if (widget.active && !old.active) {
      if (_controller == null) {
        _start(autoplay: widget.autoplay);
      } else if (widget.autoplay) {
        _controller!.play();
      }
    } else if (!widget.active && old.active) {
      _controller?.pause();
    }
    if (widget.active != old.active) _report();
  }

  /// Avisa o visualizador depois do quadro: trocar o player no meio de um
  /// build reconstruiria a barra de controles durante a construção.
  void _report() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ready = _controller?.value.isInitialized ?? false;
      widget.onController?.call(widget.active && ready ? _controller : null);
    });
  }

  @override
  void dispose() {
    widget.togglePlay.removeListener(_onToggleKey);
    if (widget.active) widget.onController?.call(null);
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start({required bool autoplay}) async {
    setState(() => _problem = null);
    try {
      final url = await ref.read(mediaUrlProvider(widget.post.storagePath).future);
      if (!mounted) return;
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;

      // Vídeo gravado pelo próprio navegador (WebM) costuma vir sem a duração
      // no arquivo. O player trata isso como transmissão ao vivo: a posição
      // fica presa numa duração negativa e o play não sai do lugar.
      if (controller.value.duration <= Duration.zero) {
        _controller = null;
        unawaited(controller.dispose());
        setState(
          () => _problem =
              'Este vídeo veio sem a duração gravada e não toca aqui. '
              'Baixe para assistir no aparelho.',
        );
        return;
      }

      controller.addListener(_onTick);
      setState(() {});
      _report();
      if (autoplay && widget.active) await controller.play();
    } catch (_) {
      if (mounted) setState(() => _problem = _unreadable);
    }
  }

  static const _unreadable =
      'Este vídeo não abre neste navegador. Baixe para assistir no aparelho.';

  void _onTick() {
    final value = _controller!.value;

    // O navegador recusa tocar com som sem um toque antes (Safari): o
    // player vira erro. Recomeça parado, esperando o play.
    if (value.hasError) {
      final blocked = value.errorDescription?.contains('NotAllowed') ?? false;
      _controller!.removeListener(_onTick);
      final old = _controller!;
      _controller = null;
      widget.onController?.call(null);
      unawaited(old.dispose());
      if (blocked) {
        _start(autoplay: false);
      } else if (mounted) {
        setState(() => _problem = _unreadable);
      }
      return;
    }

    final ended =
        value.isInitialized &&
        value.duration > Duration.zero &&
        !value.isPlaying &&
        (value.isCompleted || value.position >= value.duration - const Duration(milliseconds: 250));
    if (ended && !_ended) widget.onEnded?.call();
    if (ended != _ended) setState(() => _ended = ended);
  }

  void _onToggleKey() {
    if (widget.active) _togglePlay();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) {
      if (widget.active) _start(autoplay: true);
      return;
    }
    if (!controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      if (_ended) controller.seekTo(Duration.zero);
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final duration = context.reduceMotion ? Duration.zero : Motion.normal;

    if (_problem case final problem?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
            decoration: BoxDecoration(
              color: AppColors.night.withValues(alpha: 0.8),
              borderRadius: Radii.brLg,
            ),
            child: Text(
              problem,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // O vídeo aparece por cima da capa quando o primeiro quadro chega.
        AnimatedOpacity(
          opacity: ready ? 1 : 0,
          duration: duration,
          child: ready
              ? Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Por cima do vídeo, e não atrás: na Web o vídeo é um elemento da
        // página, e o que está atrás dele não recebe o toque.
        GestureDetector(behavior: HitTestBehavior.translucent, onTap: widget.onTap),
        if (controller != null)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) => _CenterButton(
              visible: !value.isPlaying,
              loading: !value.isInitialized,
              replay: _ended,
              onTap: _togglePlay,
            ),
          )
        else
          _CenterButton(visible: true, loading: widget.active, onTap: _togglePlay),
      ],
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({
    required this.visible,
    required this.onTap,
    this.replay = false,
    this.loading = false,
  });

  final bool visible;
  final VoidCallback onTap;
  final bool replay;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final duration = context.reduceMotion ? Duration.zero : Motion.normal;
    return Center(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: duration,
          child: AnimatedScale(
            scale: visible ? 1 : 0.8,
            duration: duration,
            curve: Motion.spring,
            // Carregando, o botão inteiro vira um círculo em esqueleto sobre a
            // capa; pronto, volta a ser o botão de tocar.
            child: loading
                ? Semantics(
                    label: 'Carregando o vídeo',
                    child: const ShimmerBox(
                      circle: true,
                      height: 64,
                      baseColor: Color(0x33FFFFFF),
                      highlightColor: Color(0xB3FFFFFF),
                    ),
                  )
                : Semantics(
                    button: true,
                    label: replay ? 'Ver de novo' : 'Tocar o vídeo',
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onTap,
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: Icon(
                            replay ? Icons.replay_rounded : Icons.play_arrow_rounded,
                            size: 34,
                            color: AppColors.night,
                          ),
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

/// Tocar e pausar, o tempo, a linha arrastável e o som.
class VideoControlBar extends StatelessWidget {
  const VideoControlBar({super.key, required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final timeStyle = AppTypography.numeric(size: 12.5, color: Colors.white);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          // Sem duração conhecida não há linha do tempo para mostrar.
          final known = value.duration > Duration.zero;
          return Row(
            children: [
              IconButton(
                onPressed: () {
                  if (value.isPlaying) {
                    controller.pause();
                  } else {
                    if (value.position >= value.duration) controller.seekTo(Duration.zero);
                    controller.play();
                  }
                },
                tooltip: value.isPlaying ? 'Pausar' : 'Tocar',
                icon: Icon(
                  value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
              ),
              if (known) ...[Text(Fmt.duration(value.position), style: timeStyle), Gap.hMd],
              Expanded(
                child: !known
                    ? const SizedBox.shrink()
                    : SizedBox(
                        height: 24,
                        child: Center(
                          child: VideoProgressIndicator(
                            controller,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            colors: VideoProgressColors(
                              playedColor: AppColors.darkSky,
                              bufferedColor: Colors.white.withValues(alpha: 0.32),
                              backgroundColor: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                        ),
                      ),
              ),
              if (known) ...[Gap.hMd, Text(Fmt.duration(value.duration), style: timeStyle)],
              IconButton(
                onPressed: () => controller.setVolume(value.volume > 0 ? 0 : 1),
                tooltip: value.volume > 0 ? 'Tirar o som' : 'Ligar o som',
                icon: Icon(
                  value.volume > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
