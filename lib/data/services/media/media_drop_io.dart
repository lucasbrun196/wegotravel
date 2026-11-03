import 'local_media.dart';

/// Fora da Web não há arquivo arrastado de outra janela.
void Function() listenForDroppedMedia({
  required void Function(bool hovering) onHover,
  required void Function(List<LocalMedia> files) onDrop,
}) =>
    () {};
