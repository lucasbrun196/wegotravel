import 'package:flutter_test/flutter_test.dart';
import 'package:we_go_travel/data/models/board_post.dart';
import 'package:we_go_travel/features/board/controllers/board_controllers.dart';

BoardPost post(
  String id, {
  required DateTime takenAt,
  String authorId = 'ana',
  MediaKind kind = MediaKind.photo,
  int? width,
  int? height,
  DateTime? createdAt,
  String? thumbPath,
}) =>
    BoardPost(
      id: id,
      authorId: authorId,
      kind: kind,
      storagePath: 'trips/t/board/$id/original.jpg',
      thumbPath: thumbPath,
      contentType: kind == MediaKind.video ? 'video/mp4' : 'image/jpeg',
      takenAt: takenAt,
      width: width,
      height: height,
      createdAt: createdAt,
    );

void main() {
  group('Agrupamento por dia', () {
    final posts = [
      post('c', takenAt: DateTime(2026, 1, 11, 18)),
      post('b', takenAt: DateTime(2026, 1, 11, 9)),
      post('a', takenAt: DateTime(2026, 1, 10, 20)),
    ];

    test('mais recentes primeiro, dias e fotos', () {
      final days = groupBoardDays(posts);
      expect(days.map((d) => d.dayKey), ['2026-01-11', '2026-01-10']);
      expect(days.first.posts.map((p) => p.id), ['c', 'b']);
    });

    test('do começo da viagem, tudo se inverte', () {
      final days = groupBoardDays(posts, newestFirst: false);
      expect(days.map((d) => d.dayKey), ['2026-01-10', '2026-01-11']);
      expect(days.last.posts.map((p) => p.id), ['b', 'c']);
    });

    test('o dia da viagem só existe dentro das datas dela', () {
      final days = groupBoardDays(
        [...posts, post('x', takenAt: DateTime(2026, 1, 5))],
        tripStart: DateTime(2026, 1, 10),
        tripEnd: DateTime(2026, 1, 15),
      );
      expect({for (final d in days) d.dayKey: d.tripDay}, {
        '2026-01-11': 2,
        '2026-01-10': 1,
        '2026-01-05': null,
      });
    });

    test('cada dia leva os lugares do roteiro daquele dia', () {
      final days = groupBoardDays(posts, placesByDay: {
        '2026-01-10': ['Praia da Joaquina'],
      });
      expect(days.last.places, ['Praia da Joaquina']);
      expect(days.first.places, isEmpty);
    });
  });

  group('Ordem do mural', () {
    test('no mesmo segundo, o enviado por último vem primeiro', () {
      final same = DateTime(2026, 1, 10, 12);
      final list = [
        post('primeiro', takenAt: same, createdAt: DateTime(2026, 1, 10, 13)),
        post('segundo', takenAt: same, createdAt: DateTime(2026, 1, 10, 14)),
      ]..sort(BoardPost.newestFirst);
      expect(list.map((p) => p.id), ['segundo', 'primeiro']);
    });

    test('o que ainda não chegou ao servidor fica no topo', () {
      final same = DateTime(2026, 1, 10, 12);
      final list = [
        post('gravado', takenAt: same, createdAt: DateTime(2026, 1, 10, 13)),
        post('enviando', takenAt: same),
      ]..sort(BoardPost.newestFirst);
      expect(list.first.id, 'enviando');
    });
  });

  group('Quadro da grade', () {
    test('a proporção vem das dimensões, com limite para panorama', () {
      expect(post('p', takenAt: DateTime(2026), width: 4000, height: 3000).tileAspectRatio,
          closeTo(4 / 3, 0.001));
      expect(post('p', takenAt: DateTime(2026), width: 8000, height: 1000).tileAspectRatio, 1.9);
      expect(post('p', takenAt: DateTime(2026), width: 1000, height: 4000).tileAspectRatio, 0.56);
    });

    test('sem dimensões, foto é retrato e vídeo é paisagem', () {
      expect(post('p', takenAt: DateTime(2026)).aspectRatio, 4 / 5);
      expect(post('v', takenAt: DateTime(2026), kind: MediaKind.video).aspectRatio, 16 / 9);
    });

    test('vídeo sem capa não tem o que mostrar na grade', () {
      expect(post('v', takenAt: DateTime(2026), kind: MediaKind.video).gridPath, isNull);
      expect(post('p', takenAt: DateTime(2026)).gridPath, 'trips/t/board/p/original.jpg');
    });
  });

  group('Quem mexe no post', () {
    final foto = post('p', takenAt: DateTime(2026), authorId: 'ana');

    test('quem postou exclui e edita a legenda', () {
      expect(foto.canDelete('ana', isAdmin: false), isTrue);
      expect(foto.canEdit('ana'), isTrue);
    });

    test('o admin exclui, mas não reescreve a legenda dos outros', () {
      expect(foto.canDelete('bia', isAdmin: true), isTrue);
      expect(foto.canEdit('bia'), isFalse);
    });

    test('o resto da turma só vê', () {
      expect(foto.canDelete('bia', isAdmin: false), isFalse);
      expect(foto.canDelete(null, isAdmin: true), isFalse);
    });

    test('excluir leva todos os arquivos do post', () {
      final completo = post('p', takenAt: DateTime(2026), thumbPath: 'trips/t/board/p/thumbs/thumb.jpg');
      expect(completo.storagePaths, [
        'trips/t/board/p/original.jpg',
        'trips/t/board/p/thumbs/thumb.jpg',
      ]);
    });
  });

  group('Textos do mural', () {
    test('contagem de fotos e vídeos', () {
      expect(mediaCountLabel(1, 0), '1 foto');
      expect(mediaCountLabel(12, 3), '12 fotos e 3 vídeos');
      expect(mediaCountLabel(0, 1), '1 vídeo');
    });

    test('com um item só, o aviso não leva número', () {
      expect(doneLabel('postad', 0, 1), 'Vídeo postado');
      expect(doneLabel('excluíd', 1, 0), 'Foto excluída');
      expect(doneLabel('postad', 6, 1), '6 fotos e 1 vídeo postados');
    });

    test('o particípio concorda com o que foi feito', () {
      expect(agreeing('postad', 1, 0), 'postada');
      expect(agreeing('postad', 3, 0), 'postadas');
      expect(agreeing('salv', 0, 1), 'salvo');
      expect(agreeing('excluíd', 2, 1), 'excluídos');
    });
  });
}
