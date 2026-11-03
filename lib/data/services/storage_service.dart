import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/attachment.dart';

/// Arquivo escolhido pelo usuário, já normalizado.
///
/// Na Web o `file_picker` devolve bytes; no celular, um caminho. Como
/// sempre enviamos com `putData`, o resto do app não precisa saber a
/// diferença — é isso que mantém o código de upload compartilhado.
class PickedFileData {
  const PickedFileData({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;

  int get sizeBytes => bytes.length;
}

class StorageService {
  StorageService(this._storage);

  final FirebaseStorage _storage;
  static const _uuid = Uuid();

  /// Envia um arquivo e devolve os metadados para gravar no Firestore.
  ///
  /// O nome no Storage é sempre um UUID: evita colisão entre pessoas que
  /// enviam "IMG_0001.jpg" ao mesmo tempo e livra de acento e espaço no
  /// caminho. O nome original fica no metadado.
  Future<Attachment> upload({
    required String folder,
    required PickedFileData file,
    String? uploadedBy,
    void Function(double progress)? onProgress,
  }) async {
    final extension = _extensionOf(file.fileName, file.contentType);
    final path = '$folder/${_uuid.v4()}$extension';
    final ref = _storage.ref(path);

    final task = ref.putData(
      file.bytes,
      SettableMetadata(
        contentType: file.contentType,
        customMetadata: {
          'originalName': file.fileName,
          'uploadedBy': ?uploadedBy,
        },
      ),
    );

    if (onProgress != null) {
      task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) onProgress(s.bytesTransferred / s.totalBytes);
      });
    }

    await task;
    final url = await ref.getDownloadURL();

    return Attachment(
      id: _uuid.v4(),
      fileName: file.fileName,
      url: url,
      storagePath: path,
      contentType: file.contentType,
      sizeBytes: file.sizeBytes,
      uploadedAt: DateTime.now(),
      uploadedBy: uploadedBy,
    );
  }

  Reference ref(String path) => _storage.ref(path);

  /// Link de download pedido agora, e não guardado.
  ///
  /// O Storage confere as regras antes de responder: no mural, se quem
  /// pede participa da viagem. Ver `mediaUrlProvider`.
  Future<String> downloadUrl(String path) => _storage.ref(path).getDownloadURL();

  /// Metadados de um arquivo do mural.
  ///
  /// O `uploadedBy` não é enfeite: as regras do Storage exigem que ele seja
  /// quem envia, e é por ele que sabem quem pode apagar o arquivo depois.
  static SettableMetadata boardMetadata({
    required String contentType,
    required String uploadedBy,
    String? originalName,
  }) =>
      SettableMetadata(
        contentType: contentType,
        // Cada post tem a sua pasta e o arquivo nunca muda: o navegador pode
        // guardar à vontade. `private` impede que um cache compartilhado
        // (proxy, CDN) guarde a foto de alguém.
        cacheControl: 'private, max-age=31536000, immutable',
        customMetadata: {
          'uploadedBy': uploadedBy,
          'originalName': ?originalName,
        },
      );

  /// Remove o arquivo do Storage. Um arquivo já ausente não é erro —
  /// o objetivo é que ele não exista mais.
  Future<void> delete(String storagePath) async {
    if (storagePath.isEmpty) return;
    try {
      await _storage.ref(storagePath).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  String _extensionOf(String fileName, String contentType) {
    final dot = fileName.lastIndexOf('.');
    if (dot > 0 && dot < fileName.length - 1) {
      return fileName.substring(dot).toLowerCase();
    }
    return switch (contentType) {
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'image/webp' => '.webp',
      'application/pdf' => '.pdf',
      'video/mp4' => '.mp4',
      _ => '',
    };
  }
}

/// Caminhos do Storage, espelhando a estrutura do Firestore.
abstract final class StoragePaths {
  static String cover(String tripId) => 'trips/$tripId/cover';
  static String member(String tripId, String memberId) => 'trips/$tripId/members/$memberId';
  static String receipts(String tripId, String billId) => 'trips/$tripId/receipts/$billId';
  static String board(String tripId, String postId) => 'trips/$tripId/board/$postId';

  /// As versões reduzidas de um post: miniatura e tela cheia.
  static String boardThumbs(String tripId, String postId) => '${board(tripId, postId)}/thumbs';
}
