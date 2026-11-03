import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/utils/exif_date.dart';
import '../models/board_post.dart';
import '../services/firestore_refs.dart';
import '../services/media/local_media.dart';
import '../services/media/media_probe.dart';
import '../services/storage_service.dart';

/// Em que pé está um envio.
enum PublishStage { preparing, sending }

/// Um envio em andamento, que pode ser cancelado no meio.
class PublishJob {
  bool _cancelled = false;
  UploadTask? _task;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    _task?.cancel();
  }

  void _check() {
    if (_cancelled) throw const PublishCancelled();
  }
}

class PublishCancelled implements Exception {
  const PublishCancelled();
}

class BoardRepository {
  BoardRepository(this._refs, this._storage);

  final FirestoreRefs _refs;
  final StorageService _storage;

  /// O mural inteiro, do mais recente para o mais antigo. A ordem é feita
  /// aqui, e não na consulta: o desempate pela data de envio pediria um
  /// índice composto só para isso.
  Stream<List<BoardPost>> watchPosts(String tripId) => _refs
      .posts(tripId)
      .snapshots()
      .map((snap) => snap.docs.map(BoardPost.fromDoc).toList()..sort(BoardPost.newestFirst));

  /// Posta uma foto ou um vídeo.
  ///
  /// A ordem importa. Primeiro sobem os arquivos — miniatura, tela cheia e
  /// o original — e só então nasce o documento: assim ninguém vê no mural
  /// um post pela metade. Se algo falha no caminho, o que já subiu é
  /// apagado.
  Future<void> publish({
    required String tripId,
    required LocalMedia media,
    required String authorId,
    required String authorName,
    String? caption,
    PublishJob? job,
    void Function(PublishStage stage, double? progress)? onProgress,
  }) async {
    final postId = _refs.posts(tripId).doc().id;
    final folder = StoragePaths.board(tripId, postId);
    final thumbs = StoragePaths.boardThumbs(tripId, postId);
    final uploaded = <String>[];

    SettableMetadata metadata(String contentType) => StorageService.boardMetadata(
          contentType: contentType,
          uploadedBy: authorId,
          originalName: media.name,
        );

    Future<String?> putJpeg(String path, Uint8List? bytes) async {
      if (bytes == null) return null;
      job?._check();
      final task = _storage.ref(path).putData(bytes, metadata('image/jpeg'));
      job?._task = task;
      await task;
      uploaded.add(path);
      return path;
    }

    try {
      onProgress?.call(PublishStage.preparing, null);
      final probe = await probeMedia(media);
      final takenAt = await _takenAt(media);

      final thumbPath = await putJpeg('$thumbs/thumb.jpg', probe.thumb);
      final displayPath = await putJpeg('$thumbs/display.jpg', probe.display);

      job?._check();
      final originalPath = '$folder/original${extensionFor(media.name, media.mimeType)}';
      final task = media.putTo(_storage.ref(originalPath), metadata(media.mimeType));
      job?._task = task;
      onProgress?.call(PublishStage.sending, 0);
      final progress = task.snapshotEvents.listen(
        (s) {
          if (s.totalBytes > 0) {
            onProgress?.call(PublishStage.sending, s.bytesTransferred / s.totalBytes);
          }
        },
        onError: (Object _) {},
      );
      try {
        await task;
      } finally {
        await progress.cancel();
      }
      uploaded.add(originalPath);
      job?._check();

      final trimmed = caption?.trim();
      await _refs.post(tripId, postId).set(
            BoardPost(
              id: postId,
              authorId: authorId,
              authorName: authorName,
              kind: media.isVideo ? MediaKind.video : MediaKind.photo,
              storagePath: originalPath,
              thumbPath: thumbPath,
              displayPath: displayPath,
              contentType: media.mimeType,
              fileName: media.name,
              sizeBytes: media.sizeBytes,
              width: probe.width,
              height: probe.height,
              durationMs: probe.duration?.inMilliseconds,
              colorValue: probe.colorValue,
              caption: trimmed == null || trimmed.isEmpty ? null : trimmed,
              takenAt: takenAt,
            ).toMap(),
          );
    } catch (e) {
      for (final path in uploaded) {
        unawaited(_storage.delete(path).catchError((Object _) {}));
      }
      if (job?.isCancelled ?? false) throw const PublishCancelled();
      rethrow;
    }
  }

  /// O dia da foto: o EXIF quando há, senão a data do arquivo, senão agora
  /// (a foto da câmera do app, que acabou de ser tirada).
  Future<DateTime> _takenAt(LocalMedia media) async {
    if (media.isImage) {
      final exif = exifTakenAt(await media.readHead(exifHeadBytes));
      if (exif != null) return exif;
    }
    return media.lastModified ?? DateTime.now();
  }

  /// Troca a legenda. Vazia apaga.
  Future<void> updateCaption(String tripId, String postId, String caption) {
    final trimmed = caption.trim();
    return _refs.post(tripId, postId).update({
      'caption': trimmed.isEmpty ? null : trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Exclui o post e os arquivos dele.
  ///
  /// Arquivos primeiro, como nas contas: se o Storage recusar, o post
  /// continua inteiro no mural, em vez de virar um quadro quebrado.
  Future<void> deletePost(String tripId, BoardPost post) async {
    for (final path in post.storagePaths) {
      await _storage.delete(path);
    }
    await _refs.post(tripId, post.id).delete();
  }

  /// Apaga os arquivos de todos os posts, para a exclusão da viagem.
  ///
  /// Precisa rodar **antes** de o documento da viagem sumir: é nele que as
  /// regras do Storage conferem quem participa. Falha num arquivo não
  /// segura a exclusão do resto.
  Future<void> deleteAllFiles(String tripId) async {
    final snap = await _refs.posts(tripId).get();
    for (final doc in snap.docs) {
      for (final path in BoardPost.fromDoc(doc).storagePaths) {
        try {
          await _storage.delete(path);
        } catch (_) {
          // Segue para o próximo: um arquivo órfão é melhor que uma viagem
          // que não se deixa excluir.
        }
      }
    }
  }
}
