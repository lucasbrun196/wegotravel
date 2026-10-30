import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_tokens.dart';

/// Faz o filho entrar subindo 12px e aparecendo, uma vez só, quando é
/// montado — desacelerando até parar, sem quique. [index] escalona a
/// entrada dos blocos de uma página: cada um começa [Motion.stagger] depois
/// do anterior, até um teto — numa lista longa os últimos não podem ficar
/// esperando.
///
/// Com "reduzir movimento" ligado no sistema, o filho aparece direto.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 560));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.7, curve: Curves.easeOut));
  late final Animation<double> _move = CurvedAnimation(parent: _controller, curve: Motion.enter);
  Timer? _delay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted || _delay != null) return;

    if (context.reduceMotion) {
      _controller.value = 1;
      return;
    }
    final steps = widget.index.clamp(0, 8);
    _delay = Timer(Motion.stagger * steps, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - _move.value)),
          child: child,
        ),
      ),
    );
  }
}
