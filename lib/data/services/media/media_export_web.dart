import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'media_export_types.dart';

export 'media_export_types.dart';

/// Na Web, "salvar" é baixar: no Android o arquivo cai em Downloads, que a
/// galeria já mostra. No iPhone a galeria fica no compartilhamento
/// ("Salvar imagem").
const savesToGallery = false;

/// O navegador abre a folha de compartilhar do sistema? (Web Share com
/// arquivos: Chrome no Android e no Windows, Edge e Safari. O Firefox não.)
bool get canShareFiles =>
    web.window.navigator.has('share') && web.window.navigator.has('canShare');

/// Arquivos já baixados, prontos para a folha de compartilhar.
class PreparedShare {
  PreparedShare._(this._data);

  final web.ShareData _data;

  Future<ShareOutcome> share() async {
    try {
      await web.window.navigator.share(_data).toDart;
      return ShareOutcome.shared;
    } catch (e) {
      final name = _errorName(e);
      if (name == 'AbortError') return ShareOutcome.cancelled;
      if (name == 'NotAllowedError') return ShareOutcome.needsTap;
      rethrow;
    }
  }
}

/// Baixa os arquivos para a memória do navegador — não do Dart — e confere
/// se o sistema aceita compartilhá-los. `null` quando não aceita: aí o
/// caminho é baixar.
Future<PreparedShare?> prepareShare(List<ExportFile> files) async {
  if (!canShareFiles) return null;
  final fetched = await Future.wait(files.map(_fetch));
  final data = web.ShareData(files: fetched.toJS);
  if (!web.window.navigator.canShare(data)) return null;
  return PreparedShare._(data);
}

/// Baixa cada arquivo com o nome original.
///
/// O atributo `download` de um link não vale para outro domínio (o do
/// Storage): o navegador abriria a foto numa aba. Por isso o arquivo vem
/// primeiro para um `blob:` local, e o link aponta para ele.
Future<void> downloadFiles(List<ExportFile> files) async {
  for (final (i, file) in files.indexed) {
    final blob = await _fetch(file);
    final url = web.URL.createObjectURL(blob);
    final link = web.HTMLAnchorElement()
      ..href = url
      ..download = file.fileName;
    link.style.display = 'none';
    web.document.body?.append(link);
    link.click();
    link.remove();

    // O navegador ainda lê o blob depois do clique; revogar na hora
    // cancelaria o download.
    Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));

    // Vários cliques no mesmo instante, e o Chrome engole alguns.
    if (i < files.length - 1) await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}

Future<web.File> _fetch(ExportFile file) async {
  final response = await web.window.fetch(file.url.toJS).toDart;
  if (!response.ok) throw StateError('O Storage respondeu ${response.status}');
  final blob = await response.blob().toDart;
  return web.File(<JSAny>[blob].toJS, file.fileName, web.FilePropertyBag(type: file.mimeType));
}

String? _errorName(Object error) {
  try {
    return (error as web.DOMException).name;
  } catch (_) {
    return null;
  }
}
