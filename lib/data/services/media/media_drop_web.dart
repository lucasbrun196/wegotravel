import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'local_media.dart';
import 'media_picker_web.dart';

/// Escuta arquivos arrastados do computador para a janela.
///
/// [onHover] avisa quando um arrasto com arquivos entra e sai da janela;
/// [onDrop] recebe o que foi solto. Só reage a arrastos com arquivos —
/// texto ou link arrastado de dentro da página segue o caminho normal.
/// Devolve a função que para de escutar.
void Function() listenForDroppedMedia({
  required void Function(bool hovering) onHover,
  required void Function(List<LocalMedia> files) onDrop,
}) {
  // `dragenter` e `dragleave` disparam a cada elemento cruzado no caminho;
  // a contagem diz quando o arrasto saiu da janela de verdade.
  var depth = 0;

  bool carriesFiles(web.DragEvent event) =>
      event.dataTransfer?.types.toDart.any((t) => t.toDart == 'Files') ?? false;

  final enter = (web.DragEvent event) {
    if (!carriesFiles(event)) return;
    event.preventDefault();
    if (depth++ == 0) onHover(true);
  }.toJS;

  // Sem o `preventDefault` aqui o navegador não deixa soltar, e abriria o
  // arquivo no lugar do app.
  final over = (web.DragEvent event) {
    if (!carriesFiles(event)) return;
    event.preventDefault();
    event.dataTransfer?.dropEffect = 'copy';
  }.toJS;

  final leave = (web.DragEvent event) {
    if (!carriesFiles(event)) return;
    if (depth > 0 && --depth == 0) onHover(false);
  }.toJS;

  final drop = (web.DragEvent event) {
    if (!carriesFiles(event)) return;
    event.preventDefault();
    depth = 0;
    onHover(false);
    onDrop(filesOf(event.dataTransfer?.files));
  }.toJS;

  final window = web.window;
  window.addEventListener('dragenter', enter);
  window.addEventListener('dragover', over);
  window.addEventListener('dragleave', leave);
  window.addEventListener('drop', drop);

  return () {
    window.removeEventListener('dragenter', enter);
    window.removeEventListener('dragover', over);
    window.removeEventListener('dragleave', leave);
    window.removeEventListener('drop', drop);
  };
}
