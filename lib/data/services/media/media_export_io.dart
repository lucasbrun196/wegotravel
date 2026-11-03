import 'dart:io';

import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import 'media_export_types.dart';

export 'media_export_types.dart';

/// No celular, "baixar" é pôr na galeria de fotos.
const savesToGallery = true;

/// A folha de compartilhar do sistema existe sempre no celular.
bool get canShareFiles => true;

/// Arquivos já baixados para a pasta temporária, prontos para a folha de
/// compartilhar.
class PreparedShare {
  PreparedShare._(this._files);

  final List<XFile> _files;

  Future<ShareOutcome> share() async {
    final result = await SharePlus.instance.share(ShareParams(files: _files));
    return result.status == ShareResultStatus.dismissed
        ? ShareOutcome.cancelled
        : ShareOutcome.shared;
  }
}

Future<PreparedShare?> prepareShare(List<ExportFile> files) async {
  final paths = await Future.wait(files.map(_download));
  return PreparedShare._([
    for (final (i, path) in paths.indexed) XFile(path, mimeType: files[i].mimeType),
  ]);
}

/// Salva na galeria. A permissão é pedida na primeira vez.
Future<void> downloadFiles(List<ExportFile> files) async {
  if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
    throw const FileSystemException('Sem permissão para salvar na galeria');
  }
  for (final file in files) {
    final path = await _download(file);
    if (file.isVideo) {
      await Gal.putVideo(path);
    } else {
      await Gal.putImage(path);
    }
  }
}

/// Grava o arquivo na pasta temporária aos pedaços: um vídeo grande não
/// passa inteiro pela memória.
Future<String> _download(ExportFile file) async {
  final dir = await Directory.systemTemp.createTemp('mural');
  final target = File('${dir.path}/${file.fileName}');

  final client = http.Client();
  try {
    final response = await client.send(http.Request('GET', Uri.parse(file.url)));
    if (response.statusCode != 200) {
      throw HttpException('O Storage respondeu ${response.statusCode}');
    }
    await response.stream.pipe(target.openWrite());
    return target.path;
  } finally {
    client.close();
  }
}
