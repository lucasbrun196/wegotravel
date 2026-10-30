import 'package:flutter/material.dart';

import '../../../core/extensions/context_ext.dart';

/// O botão de criar do cabeçalho da página: quadrado azul-noite com "+" no
/// celular, com o rótulo escrito a partir do tablet.
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return IconButton.filled(
        tooltip: label,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: const Size(44, 44),
          backgroundColor: context.action,
          foregroundColor: context.onAction,
        ),
        icon: const Icon(Icons.add, size: 22),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: Text(label),
    );
  }
}
