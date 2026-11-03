import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/painting.dart';

import 'local_media.dart';

/// Arquivo escolhido no celular: um caminho no disco. O upload lê do disco
/// aos pedaços (`putFile`), sem carregar o vídeo inteiro na memória.
class FileLocalMedia extends LocalMedia {
  FileLocalMedia(
    this.path, {
    required this.name,
    required this.sizeBytes,
    this.lastModified,
  }) : mimeType = mediaTypeFor(name);

  final String path;

  @override
  final String name;

  @override
  final String mimeType;

  @override
  final int sizeBytes;

  @override
  final DateTime? lastModified;

  @override
  late final ImageProvider? preview = isImage ? FileImage(File(path)) : null;

  @override
  Future<Uint8List> readAsBytes() => File(path).readAsBytes();

  @override
  Future<Uint8List> readHead(int length) async {
    final file = await File(path).open();
    try {
      return await file.read(length);
    } finally {
      await file.close();
    }
  }

  @override
  UploadTask putTo(Reference ref, SettableMetadata metadata) =>
      ref.putFile(File(path), metadata);
}

/// Fotos e vídeos da galeria. Com [multiple], dá para marcar vários.
Future<List<LocalMedia>> pickMedia({bool multiple = true}) async {
  final files = multiple
      ? await FilePicker.pickFiles(type: FileType.media)
      : [?await FilePicker.pickFile(type: FileType.media)];

  return [
    for (final f in files)
      if (f.path case final path?)
        FileLocalMedia(
          path,
          name: f.name,
          sizeBytes: await f.length(),
          lastModified: _modifiedAt(path),
        ),
  ];
}

/// No celular a câmera do app já é a do aparelho: não há outra para cair.
Future<List<LocalMedia>> captureWithSystemCamera() async => const [];

DateTime? _modifiedAt(String path) {
  try {
    return File(path).lastModifiedSync();
  } on FileSystemException {
    return null;
  }
}
