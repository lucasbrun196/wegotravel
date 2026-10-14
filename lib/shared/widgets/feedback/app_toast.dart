import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

enum ToastKind { success, error, warning }

/// Avisos flutuantes no canto inferior direito: sucesso, erro e alerta.
///
/// Estático, e não preso a um `BuildContext`, porque quase todo aviso sai
/// logo depois de um `Navigator.pop` ou de um `context.go` — o contexto
/// de quem pediu já está desmontado nessa hora. Quem desenha é o
/// [ToastHost], montado uma vez acima do Navigator.
abstract final class AppToast {
  /// Quanto cada aviso fica na tela, se ninguém fechar antes.
  static const duration = Duration(seconds: 7);

  /// Acima disso o mais antigo sai, para a pilha não subir pela tela toda.
  static const _maxVisible = 4;

  static final _entries = ValueNotifier<List<_ToastEntry>>(const []);
  static int _nextId = 0;

  static void success(String message, {IconData? icon}) =>
      _show(ToastKind.success, message, icon ?? Icons.check_circle_rounded);

  static void error(String message) =>
      _show(ToastKind.error, message, Icons.error_rounded);

  static void warning(String message) =>
      _show(ToastKind.warning, message, Icons.warning_rounded);

  static void _show(ToastKind kind, String message, IconData icon) {
    final next = [..._entries.value, _ToastEntry(_nextId++, kind, message, icon)];
    _entries.value = next.length > _maxVisible
        ? next.sublist(next.length - _maxVisible)
        : next;
  }

  static void _remove(int id) =>
      _entries.value = _entries.value.where((e) => e.id != id).toList();
}

class _ToastEntry {
  const _ToastEntry(this.id, this.kind, this.message, this.icon);

  final int id;
  final ToastKind kind;
  final String message;
  final IconData icon;
}

/// Desenha a pilha de [AppToast] por cima do app inteiro.
///
/// Fica no `builder` do `MaterialApp`, fora do Navigator: assim o aviso
/// aparece por cima de diálogos e sheets, que são montados no overlay do
/// Navigator raiz. O mais novo fica embaixo, colado no canto.
class ToastHost extends StatelessWidget {
  const ToastHost({super.key, required this.child});

  final Widget child;

  /// Altura da barra de navegação inferior do celular, que o aviso não
  /// deve cobrir.
  static const _bottomBarHeight = 80.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = math.min(380.0, media.size.width - Gap.lg * 2);
    final bottom = Gap.lg +
        math.max(media.viewPadding.bottom, media.viewInsets.bottom) +
        (context.isMobile ? _bottomBarHeight : 0);

    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          right: Gap.lg,
          bottom: bottom,
          width: width,
          child: ValueListenableBuilder<List<_ToastEntry>>(
            valueListenable: AppToast._entries,
            builder: (context, entries, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in entries)
                  _ToastCard(key: ValueKey(entry.id), entry: entry),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({super.key, required this.entry});

  final _ToastEntry entry;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Motion.normal);
    _curve = CurvedAnimation(parent: _controller, curve: Motion.enter, reverseCurve: Motion.exit);
    _timer = Timer(AppToast.duration, _close);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isDismissed && !_closing) {
      // Sem animação quando o sistema pede menos movimento.
      if (context.reduceMotion) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Sai animando e só então deixa a pilha — os de cima descem junto,
  /// em vez de saltar.
  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (!context.reduceMotion) await _controller.reverse();
    AppToast._remove(widget.entry.id);
  }

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (widget.entry.kind) {
      ToastKind.success => (AppColors.toastSuccess, AppColors.toastOnSuccess),
      ToastKind.error => (AppColors.toastError, AppColors.toastOnError),
      ToastKind.warning => (AppColors.toastWarning, AppColors.toastOnWarning),
    };

    return SizeTransition(
      sizeFactor: _curve,
      axisAlignment: 1,
      child: FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.25, 0), end: Offset.zero).animate(_curve),
          child: Padding(
            padding: const EdgeInsets.only(top: Gap.sm),
            child: Semantics(
              liveRegion: true,
              child: Material(
                color: background,
                elevation: 6,
                shadowColor: Colors.black54,
                borderRadius: Radii.brMd,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.xs, Gap.sm),
                  child: Row(
                    children: [
                      Icon(widget.entry.icon, color: foreground, size: 22),
                      Gap.hMd,
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                          child: Text(
                            widget.entry.message,
                            style: context.text.bodyMedium?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      // Sem `tooltip`: o aviso vive fora do Navigator, onde
                      // não há Overlay para desenhar a dica.
                      Semantics(
                        label: 'Fechar aviso',
                        button: true,
                        excludeSemantics: true,
                        child: IconButton(
                          onPressed: _close,
                          icon: Icon(Icons.close_rounded, color: foreground, size: 20),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
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
