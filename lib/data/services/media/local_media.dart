import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/painting.dart';

/// Uma foto ou um vídeo que está no aparelho e ainda não foi postado.
///
/// Cada plataforma entrega o arquivo de um jeito: na Web é um `File` do
/// navegador, no celular um caminho, e a câmera devolve os bytes. O resto
/// do app só vê esta interface — e, principalmente, nunca precisa ler um
/// vídeo inteiro para a memória só para enviá-lo: [putTo] manda direto da
/// origem.
abstract class LocalMedia {
  String get name;
  String get mimeType;
  int get sizeBytes;

  /// Data de modificação do arquivo, quando a plataforma informa. É o
  /// palpite de "quando foi tirada" para arquivo sem EXIF.
  DateTime? get lastModified;

  bool get isVideo => mimeType.startsWith('video/');
  bool get isImage => mimeType.startsWith('image/');

  /// Para mostrar a miniatura antes de postar.
  ImageProvider? get preview;

  Future<Uint8List> readAsBytes();

  /// Só o começo do arquivo — o bastante para o EXIF.
  Future<Uint8List> readHead(int length);

  /// Envia o arquivo para [ref].
  UploadTask putTo(Reference ref, SettableMetadata metadata);

  /// Libera o que a plataforma reservou para o arquivo (o endereço `blob:`
  /// da prévia, na Web).
  void dispose() {}
}

/// Arquivo que já está em memória: a foto que acabou de sair da câmera.
class MemoryLocalMedia extends LocalMedia {
  MemoryLocalMedia({
    required this.bytes,
    required this.name,
    required this.mimeType,
    this.lastModified,
  });

  final Uint8List bytes;

  @override
  final String name;

  @override
  final String mimeType;

  @override
  final DateTime? lastModified;

  @override
  int get sizeBytes => bytes.length;

  @override
  late final ImageProvider? preview = isImage ? MemoryImage(bytes) : null;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Future<Uint8List> readHead(int length) async =>
      length >= bytes.length ? bytes : Uint8List.sublistView(bytes, 0, length);

  @override
  UploadTask putTo(Reference ref, SettableMetadata metadata) => ref.putData(bytes, metadata);
}

/// Maior arquivo aceito no mural, o mesmo limite das regras do Storage.
const maxMediaBytes = 150 * 1024 * 1024;

/// O tipo do arquivo pela extensão, para quando a plataforma não diz. Só
/// foto e vídeo; o resto volta vazio e fica de fora do mural.
String mediaTypeFor(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'avif' => 'image/avif',
    'mp4' || 'm4v' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    '3gp' => 'video/3gpp',
    'mkv' => 'video/x-matroska',
    _ => '',
  };
}

/// A extensão para o arquivo no Storage.
String extensionFor(String fileName, String mimeType) {
  final dot = fileName.lastIndexOf('.');
  if (dot > 0 && dot < fileName.length - 1) return fileName.substring(dot).toLowerCase();
  return switch (mimeType) {
    'image/jpeg' => '.jpg',
    'image/png' => '.png',
    'image/webp' => '.webp',
    'image/heic' => '.heic',
    'video/mp4' => '.mp4',
    'video/quicktime' => '.mov',
    'video/webm' => '.webm',
    _ => '',
  };
}
