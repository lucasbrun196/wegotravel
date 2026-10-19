import 'package:flutter/material.dart';

/// Sistema, claro ou escuro. O botão sol/lua da barra só alterna entre os
/// dois últimos; voltar a seguir o sistema é por aqui.
class ThemeModePicker extends StatelessWidget {
  const ThemeModePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          label: Text('Sistema'),
          icon: Icon(Icons.brightness_auto_outlined, size: 16),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('Claro'),
          icon: Icon(Icons.light_mode_outlined, size: 16),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('Escuro'),
          icon: Icon(Icons.dark_mode_outlined, size: 16),
        ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
