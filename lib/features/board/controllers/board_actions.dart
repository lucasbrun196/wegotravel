import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/board_post.dart';
import '../../../data/services/media/local_media.dart';
import '../../../data/services/media/media_export.dart';
import '../../../shared/widgets/feedback/app_toast.dart';
import 'board_controllers.dart';

/// Ações sobre posts que aparecem na grade (em lote) e na tela cheia (um
/// por vez). Recebem o `ref` de quem chama e não abrem formulário: os
/// diálogos daqui não leem provider nenhum.

/// O nome do arquivo exportado: o original do aparelho de quem postou.
String exportNameOf(BoardPost post) {
  final name = post.fileName.trim();
  if (name.isNotEmpty) return name;
  return 'wegotravel-${Fmt.dayKey(post.takenAt)}-${post.id.substring(0, 6)}'
      '${extensionFor('', post.contentType)}';
}

Future<List<ExportFile>> _exportFiles(WidgetRef ref, List<BoardPost> posts) => Future.wait([
      for (final post in posts)
        ref.read(mediaUrlProvider(post.storagePath).future).then(
              (url) => ExportFile(url: url, fileName: exportNameOf(post), mimeType: post.contentType),
            ),
    ]);

/// Folha de compartilhar do sistema: WhatsApp, Instagram, e-mail, e no
/// iPhone também "Salvar imagem". Navegador que não compartilha arquivo
/// recebe o download no lugar.
Future<void> sharePosts(BuildContext context, WidgetRef ref, List<BoardPost> posts) async {
  if (posts.isEmpty) return;
  try {
    final files = await _exportFiles(ref, posts);
    final prepared = await prepareShare(files);

    if (prepared == null) {
      await downloadFiles(files);
      AppToast.warning(posts.length == 1
          ? 'Este navegador não compartilha arquivos. A foto foi baixada.'
          : 'Este navegador não compartilha arquivos. Eles foram baixados.');
      return;
    }

    final outcome = await prepared.share();
    if (outcome == ShareOutcome.needsTap && context.mounted) {
      // Baixar levou tempo demais e o navegador já não considera o toque
      // de antes. Um botão pede o toque de novo.
      final again = await _confirm(
        context,
        title: 'Pronto para compartilhar',
        message: posts.length == 1
            ? 'O arquivo já está no aparelho.'
            : 'Os ${posts.length} arquivos já estão no aparelho.',
        action: 'Compartilhar',
      );
      if (again) await prepared.share();
    }
  } catch (_) {
    AppToast.error('Não deu para compartilhar');
  }
}

/// Baixa o original. No celular, vai para a galeria.
Future<void> downloadPosts(BuildContext context, WidgetRef ref, List<BoardPost> posts) async {
  if (posts.isEmpty) return;
  final videos = posts.where((p) => p.isVideo).length;
  final photos = posts.length - videos;
  try {
    await downloadFiles(await _exportFiles(ref, posts));
    AppToast.success(savesToGallery
        ? '${doneLabel('salv', photos, videos)} na galeria'
        : doneLabel('baixad', photos, videos));
  } catch (_) {
    AppToast.error(savesToGallery ? 'Não deu para salvar na galeria' : 'Não deu para baixar');
  }
}

/// Pergunta e exclui. Só os posts que a pessoa pode excluir entram; os
/// outros são contados na pergunta, para ninguém achar que sumiram.
///
/// Devolve se excluiu algo. [onDeleting] recebe os ids que vão sair, logo
/// depois da confirmação: a grade os mostra em esqueleto enquanto somem.
Future<bool> deletePosts(
  BuildContext context,
  WidgetRef ref,
  List<BoardPost> posts, {
  void Function(Set<String> ids)? onDeleting,
}) async {
  final uid = ref.read(currentUidProvider);
  final isAdmin = ref.read(isTripAdminProvider);
  final mine = posts.where((p) => p.canDelete(uid, isAdmin: isAdmin)).toList();
  final others = posts.length - mine.length;

  if (mine.isEmpty) {
    AppToast.warning(posts.length == 1
        ? 'Só quem postou, ou o admin da viagem, exclui'
        : 'Nenhum destes é seu. Só quem postou, ou o admin, exclui');
    return false;
  }

  final videos = mine.where((p) => p.isVideo).length;
  final photos = mine.length - videos;
  final single = mine.length == 1;

  final ok = await _confirm(
    context,
    title: single
        ? (videos == 1 ? 'Excluir este vídeo?' : 'Excluir esta foto?')
        : 'Excluir ${mediaCountLabel(photos, videos)}?',
    message: [
      single
          ? (videos == 1 ? 'O vídeo sai do mural de todo mundo.' : 'A foto sai do mural de todo mundo.')
          : 'Saem do mural de todo mundo.',
      if (others > 0)
        others == 1
            ? '1 dos escolhidos é de outra pessoa e continua lá.'
            : '$others dos escolhidos são de outras pessoas e continuam lá.',
      'Não dá para desfazer.',
    ].join(' '),
    action: 'Excluir',
    destructive: true,
  );
  if (!ok) return false;
  onDeleting?.call({for (final p in mine) p.id});

  final tripId = ref.read(currentTripIdProvider);
  final repo = ref.read(boardRepositoryProvider);
  var failed = 0;
  for (final post in mine) {
    try {
      await repo.deletePost(tripId, post);
    } catch (_) {
      failed++;
    }
  }

  if (failed == mine.length) {
    AppToast.error('Não deu para excluir');
    return false;
  }
  if (failed > 0) {
    AppToast.warning('$failed não saíram do mural. Tente de novo.');
  } else {
    AppToast.success(doneLabel('excluíd', photos, videos));
  }
  return true;
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: context.colors.error) : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}
