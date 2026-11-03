import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/services/media/local_media.dart';
import '../../../data/services/media/media_picker.dart';
import '../../../shared/widgets/feedback/loading_shimmer.dart';

/// Abre a câmera do app. Devolve as fotos tiradas — vazio se a pessoa saiu
/// sem postar.
///
/// Vai para o Navigator raiz, por cima da barra de navegação: a câmera
/// ocupa a tela toda. Não lê provider nenhum, então não precisa do escopo
/// da viagem.
Future<List<LocalMedia>> openBoardCamera(BuildContext context) async {
  final still = context.reduceMotion;
  final shots = await Navigator.of(context, rootNavigator: true).push<List<LocalMedia>>(
    PageRouteBuilder(
      transitionDuration: still ? Duration.zero : Motion.slow,
      reverseTransitionDuration: still ? Duration.zero : Motion.normal,
      pageBuilder: (_, _, _) => Theme(data: AppTheme.dark, child: const BoardCameraScreen()),
      transitionsBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Motion.enter,
          reverseCurve: Motion.exit,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child),
        );
      },
    ),
  );
  return shots ?? const [];
}

/// A câmera: a imagem ao vivo, o disparador e a pilha do que já foi
/// tirado. Dá para tirar várias seguidas e postar todas de uma vez.
class BoardCameraScreen extends StatefulWidget {
  const BoardCameraScreen({super.key});

  @override
  State<BoardCameraScreen> createState() => _BoardCameraScreenState();
}

class _BoardCameraScreenState extends State<BoardCameraScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  int _cameraIndex = 0;
  String? _error;
  bool _capturing = false;
  final _shots = <MemoryLocalMedia>[];
  final _focus = FocusNode(debugLabel: 'Câmera');

  /// O clarão do disparo.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _flashOpacity = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.85), weight: 15),
    TweenSequenceItem(tween: Tween(begin: 0.85, end: 0.0), weight: 85),
  ]).animate(_flash);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _flash.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// No celular o sistema toma a câmera quando o app vai para segundo
  /// plano; ela precisa ser aberta de novo na volta.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    if (state == AppLifecycleState.inactive) {
      final old = _controller;
      setState(() => _controller = null);
      old?.dispose();
    } else if (state == AppLifecycleState.resumed && _controller == null && _error == null) {
      _open(_cameraIndex);
    }
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      // Na Web é aqui que o navegador pede a permissão.
      _cameras = await availableCameras();
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = _describe(e));
      return;
    }
    if (_cameras.isEmpty) {
      if (mounted) setState(() => _error = 'Nenhuma câmera encontrada neste aparelho.');
      return;
    }
    final back = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    await _open(back < 0 ? 0 : back);
  }

  Future<void> _open(int index) async {
    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      if (mounted) setState(() => _error = _describe(e));
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    final old = _controller;
    setState(() {
      _controller = controller;
      _cameraIndex = index;
      _error = null;
    });
    await old?.dispose();
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    await _open((_cameraIndex + 1) % _cameras.length);
  }

  Future<void> _shoot() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) return;

    setState(() => _capturing = true);
    if (!context.reduceMotion) _flash.forward(from: 0);
    unawaited(HapticFeedback.mediumImpact());

    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      final now = DateTime.now();
      if (!mounted) return;
      setState(() {
        _shots.add(
          MemoryLocalMedia(
            bytes: bytes,
            name: 'foto-${DateFormat('yyyyMMdd-HHmmss').format(now)}.jpg',
            mimeType: 'image/jpeg',
            lastModified: now,
          ),
        );
      });
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = _describe(e));
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// O plano B da Web: a câmera do próprio sistema, pelo seletor de
  /// arquivo. No celular ela abre direto.
  Future<void> _systemCamera() async {
    final files = await captureWithSystemCamera();
    if (!mounted || files.isEmpty) return;
    Navigator.of(context).pop([..._shots, ...files]);
  }

  Future<void> _close() async {
    if (_shots.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_shots.length == 1 ? 'Descartar a foto?' : 'Descartar ${_shots.length} fotos?'),
        content: Text(
          _shots.length == 1
              ? 'Ela ainda não foi postada no mural.'
              : 'Elas ainda não foram postadas no mural.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar aqui'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  void _post() => Navigator.of(context).pop(List<LocalMedia>.of(_shots));

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter) {
      _shoot();
    } else if (key == LogicalKeyboardKey.escape) {
      _close();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  static String _describe(CameraException e) {
    final code = e.code.toLowerCase();
    if (code.contains('denied') || code.contains('permission')) {
      return 'Sem acesso à câmera. Libere a câmera para este site nas configurações do '
          'navegador e tente de novo.';
    }
    if (code.contains('notfound')) return 'Nenhuma câmera encontrada neste aparelho.';
    if (code.contains('notreadable') || code.contains('abort')) {
      return 'A câmera está sendo usada por outro app. Feche o outro app e tente de novo.';
    }
    if (code.contains('notsupported') || code.contains('security')) {
      return 'Este navegador não deixa o app usar a câmera.';
    }
    return 'Não deu para abrir a câmera.';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final wide = !context.isMobile;

    return PopScope(
      canPop: _shots.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: AppColors.darkBackground,
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? Gap.xxl : 0,
                    wide ? 72 : 64,
                    wide ? Gap.xxl : 0,
                    wide ? 136 : 128,
                  ),
                  child: Center(
                    child: _error != null
                        ? _ErrorPanel(
                            message: _error!,
                            onRetry: _start,
                            onSystemCamera: kIsWeb ? _systemCamera : null,
                          )
                        : ready
                        ? ClipRRect(
                            borderRadius: wide ? Radii.brXl : BorderRadius.zero,
                            child: CameraPreview(controller),
                          )
                        // Abrindo a câmera: o quadro da imagem ao vivo, em
                        // esqueleto, no formato em que ela vai aparecer.
                        : AspectRatio(
                            aspectRatio: wide ? 16 / 9 : 3 / 4,
                            child: ShimmerBox(
                              height: double.infinity,
                              width: double.infinity,
                              borderRadius: wide ? Radii.brXl : BorderRadius.zero,
                              baseColor: Colors.white.withValues(alpha: 0.06),
                              highlightColor: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                  ),
                ),
                // O clarão cobre a tela inteira por um instante.
                IgnorePointer(
                  child: FadeTransition(
                    opacity: _flashOpacity,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
                Positioned(
                  top: Gap.sm,
                  left: Gap.sm,
                  right: Gap.md,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Fechar',
                        onPressed: _close,
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: context.reduceMotion ? Duration.zero : Motion.normal,
                        transitionBuilder: (child, animation) => ScaleTransition(
                          scale: CurvedAnimation(parent: animation, curve: Motion.spring),
                          child: FadeTransition(opacity: animation, child: child),
                        ),
                        child: _shots.isEmpty
                            ? const SizedBox.shrink()
                            : FilledButton(
                                key: const ValueKey('postar'),
                                onPressed: _post,
                                child: Text(
                                  _shots.length == 1 ? 'Postar' : 'Postar ${_shots.length}',
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                // Sem câmera, o disparador apagado só confundiria.
                if (_error == null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: Gap.xl,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(width: 64, height: 64, child: _ShotStack(shots: _shots)),
                        _Shutter(enabled: ready && !_capturing, onTap: _shoot),
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: _cameras.length > 1
                              ? IconButton(
                                  tooltip: 'Trocar de câmera',
                                  onPressed: ready ? _switchCamera : null,
                                  icon: const Icon(
                                    Icons.cameraswitch_outlined,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// O disparador: anel branco com o miolo amarelo do sol, que afunda no
/// toque.
class _Shutter extends StatefulWidget {
  const _Shutter({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_Shutter> createState() => _ShutterState();
}

class _ShutterState extends State<_Shutter> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final still = context.reduceMotion;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: 'Tirar foto',
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
          onTapUp: widget.enabled ? (_) => setState(() => _down = false) : null,
          onTapCancel: () => setState(() => _down = false),
          onTap: widget.enabled ? widget.onTap : null,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            alignment: Alignment.center,
            child: AnimatedScale(
              scale: _down && !still ? 0.84 : 1,
              duration: Motion.instant,
              curve: Motion.enter,
              child: AnimatedOpacity(
                opacity: widget.enabled ? 1 : 0.4,
                duration: still ? Duration.zero : Motion.fast,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.sun),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A última foto tirada, com quantas já são. Cada clique novo chega
/// crescendo.
class _ShotStack extends StatelessWidget {
  const _ShotStack({required this.shots});

  final List<MemoryLocalMedia> shots;

  @override
  Widget build(BuildContext context) {
    final still = context.reduceMotion;
    return AnimatedSwitcher(
      duration: still ? Duration.zero : Motion.slow,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween(
          begin: 1.4,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: Motion.spring)),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: shots.isEmpty
          ? const SizedBox.shrink()
          : Stack(
              key: ValueKey(shots.length),
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: Radii.brMd,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(Radii.md - 2)),
                      child: Image.memory(
                        shots.last.bytes,
                        fit: BoxFit.cover,
                        cacheWidth: 160,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.sun,
                      borderRadius: Radii.brPill,
                    ),
                    child: Text(
                      '${shots.length}',
                      style: AppTypography.numeric(
                        size: 12,
                        weight: FontWeight.w700,
                        color: AppColors.night,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry, this.onSystemCamera});

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onSystemCamera;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 36, color: Colors.white70),
            Gap.vLg,
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(color: Colors.white),
            ),
            Gap.vLg,
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
                if (onSystemCamera != null)
                  OutlinedButton(
                    onPressed: onSystemCamera,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Usar a câmera do sistema'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
