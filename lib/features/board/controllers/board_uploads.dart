import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/repositories/board_repository.dart';
import '../../../data/services/media/local_media.dart';
import '../../../shared/widgets/feedback/app_toast.dart';
import 'board_controllers.dart';

enum UploadStage { waiting, preparing, sending, done, failed, cancelled }

/// Uma foto ou um vídeo na fila para o mural.
class BoardUpload {
  const BoardUpload({
    required this.id,
    required this.tripId,
    required this.media,
    required this.authorName,
    this.caption,
    this.stage = UploadStage.waiting,
    this.progress,
    this.error,
  });

  final int id;
  final String tripId;
  final LocalMedia media;
  final String authorName;
  final String? caption;
  final UploadStage stage;

  /// De 0 a 1 enquanto o original sobe; nulo quando não dá para medir.
  final double? progress;
  final String? error;

  bool get isRunning => stage == UploadStage.preparing || stage == UploadStage.sending;
  bool get isPending => stage == UploadStage.waiting || isRunning;

  BoardUpload copyWith({UploadStage? stage, double? progress, String? error}) => BoardUpload(
        id: id,
        tripId: tripId,
        media: media,
        authorName: authorName,
        caption: caption,
        stage: stage ?? this.stage,
        progress: progress,
        error: error,
      );
}

/// A fila de envio do mural.
///
/// Fica na raiz do app, e não no escopo da viagem: quem troca de aba ou
/// volta para a lista de viagens no meio de um envio não pode perdê-lo. Os
/// itens carregam a viagem a que pertencem.
final boardUploadsProvider = NotifierProvider<BoardUploadsController, List<BoardUpload>>(
  BoardUploadsController.new,
);

class BoardUploadsController extends Notifier<List<BoardUpload>> {
  /// Dois ao mesmo tempo: aproveita a banda sem afogar o 4G de viagem.
  static const _parallel = 2;

  final _jobs = <int, PublishJob>{};
  var _nextId = 0;

  @override
  List<BoardUpload> build() => const [];

  /// Põe na fila e começa a enviar.
  void enqueue({
    required String tripId,
    required String authorName,
    required List<(LocalMedia, String?)> items,
  }) {
    state = [
      ...state,
      for (final (media, caption) in items)
        BoardUpload(
          id: _nextId++,
          tripId: tripId,
          media: media,
          authorName: authorName,
          caption: caption,
        ),
    ];
    _pump();
  }

  void retry(int id) {
    _update(id, (u) => u.copyWith(stage: UploadStage.waiting));
    _pump();
  }

  void cancel(int id) {
    final job = _jobs[id];
    if (job != null) {
      // `_run` recebe o cancelamento e marca o item.
      job.cancel();
      return;
    }
    _update(id, (u) => u.isPending ? u.copyWith(stage: UploadStage.cancelled) : u);
  }

  /// Tira da lista o que já terminou naquela viagem.
  void clearFinished(String tripId) {
    final keep = <BoardUpload>[];
    for (final u in state) {
      if (u.tripId == tripId && !u.isPending) {
        u.media.dispose();
      } else {
        keep.add(u);
      }
    }
    state = keep;
  }

  void _pump() {
    var free = _parallel - state.where((u) => u.isRunning).length;
    for (final upload in state) {
      if (free <= 0) break;
      if (upload.stage != UploadStage.waiting) continue;
      free--;
      // Marca já, antes do primeiro `await`, para o próximo `_pump` não
      // pegar o mesmo item de novo.
      _update(upload.id, (u) => u.copyWith(stage: UploadStage.preparing));
      unawaited(_run(upload));
    }
  }

  Future<void> _run(BoardUpload upload) async {
    final job = PublishJob();
    _jobs[upload.id] = job;

    try {
      final uid = ref.read(currentUidProvider);
      if (uid == null) throw StateError('sem sessão');

      await ref.read(boardRepositoryProvider).publish(
            tripId: upload.tripId,
            media: upload.media,
            authorId: uid,
            authorName: upload.authorName,
            caption: upload.caption,
            job: job,
            onProgress: (stage, progress) => _progress(upload.id, stage, progress),
          );
      _update(upload.id, (u) => u.copyWith(stage: UploadStage.done, progress: 1));
    } on PublishCancelled {
      _update(upload.id, (u) => u.copyWith(stage: UploadStage.cancelled));
    } catch (e) {
      _update(upload.id, (u) => u.copyWith(stage: UploadStage.failed, error: _describe(e)));
    } finally {
      _jobs.remove(upload.id);
      _pump();
      _announce(upload.tripId);
    }
  }

  /// O Storage avisa o progresso várias vezes por segundo. Abaixo de 1%
  /// de diferença a barra nem se mexe: não vale reconstruir a lista.
  void _progress(int id, PublishStage stage, double? progress) {
    final next = stage == PublishStage.preparing ? UploadStage.preparing : UploadStage.sending;
    _update(id, (u) {
      final same = u.stage == next &&
          (progress == null || (u.progress != null && (progress - u.progress!).abs() < 0.01));
      return same ? u : u.copyWith(stage: next, progress: progress);
    });
  }

  /// Quando a fila de uma viagem esvazia, um aviso só para o lote inteiro
  /// — e a fila some sozinha se nada falhou.
  void _announce(String tripId) {
    final mine = state.where((u) => u.tripId == tripId).toList();
    if (mine.isEmpty || mine.any((u) => u.isPending)) return;

    final done = mine.where((u) => u.stage == UploadStage.done).toList();
    final failed = mine.where((u) => u.stage == UploadStage.failed).length;

    if (done.isNotEmpty) {
      final videos = done.where((u) => u.media.isVideo).length;
      final photos = done.length - videos;
      AppToast.success('${doneLabel('postad', photos, videos)} no mural');
    }
    if (failed == 0) {
      Timer(const Duration(milliseconds: 1600), () {
        if (state.where((u) => u.tripId == tripId).every((u) => !u.isPending)) {
          clearFinished(tripId);
        }
      });
    }
  }

  void _update(int id, BoardUpload Function(BoardUpload) change) {
    state = [for (final u in state) u.id == id ? change(u) : u];
  }

  static String _describe(Object error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'unauthorized' || 'permission-denied' => 'Sem permissão para postar nesta viagem',
        'retry-limit-exceeded' => 'A conexão caiu no meio do envio',
        'quota-exceeded' => 'O espaço de arquivos do projeto acabou',
        _ => 'O envio falhou (${error.code})',
      };
    }
    return 'O envio falhou';
  }
}
