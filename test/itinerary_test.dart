import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:we_go_travel/data/models/itinerary_enums.dart';
import 'package:we_go_travel/data/models/itinerary_item.dart';
import 'package:we_go_travel/data/services/geocoding_service.dart';

ItineraryItem item(
  String title, {
  required DateTime date,
  int? hora,
  int order = 0,
  double? lat,
  double? lng,
  String? placeName,
  ItineraryStatus status = ItineraryStatus.planned,
  List<String> billIds = const [],
}) =>
    ItineraryItem(
      id: title,
      title: title,
      date: date,
      order: order,
      lat: lat,
      lng: lng,
      placeName: placeName,
      status: status,
      billIds: billIds,
      startAt: hora == null
          ? null
          : DateTime(date.year, date.month, date.day, hora),
    );

void main() {
  final dia1 = DateTime(2026, 1, 10);
  final dia2 = DateTime(2026, 1, 11);

  group('Ordenação dentro do dia', () {
    test('quem tem horário vem antes, na ordem do relógio', () {
      final itens = [
        item('almoço', date: dia1, hora: 12),
        item('café', date: dia1, hora: 8),
        item('jantar', date: dia1, hora: 20),
      ]..sort((a, b) => a.compareForDay(b));

      expect(itens.map((i) => i.title), ['café', 'almoço', 'jantar']);
    });

    test('sem horário vai para o fim, preservando a ordem de cadastro', () {
      final itens = [
        item('praia', date: dia1, order: 2),
        item('trilha', date: dia1, order: 1),
        item('jantar', date: dia1, hora: 20),
      ]..sort((a, b) => a.compareForDay(b));

      expect(itens.map((i) => i.title), ['jantar', 'trilha', 'praia']);
    });
  });

  group('Agrupamento por dia', () {
    test('a chave do dia ignora o horário', () {
      final manha = item('a', date: dia1, hora: 7);
      final noite = item('b', date: dia1, hora: 23);
      expect(manha.dayKey, noite.dayKey);
      expect(manha.dayKey, '2026-01-10');
    });

    test('dias diferentes geram chaves diferentes', () {
      expect(item('a', date: dia1).dayKey == item('b', date: dia2).dayKey, isFalse);
    });
  });

  group('Vínculo com contas', () {
    test('sem conta não conta como vinculada', () {
      expect(item('a', date: dia1).isLinkedToBill, isFalse);
      expect(item('b', date: dia1, billIds: const []).isLinkedToBill, isFalse);
    });

    test('com conta, sim', () {
      expect(item('c', date: dia1, billIds: const ['conta-1']).isLinkedToBill, isTrue);
    });

    test('várias contas na mesma atividade', () {
      final varias = item('e', date: dia1, billIds: const ['conta-1', 'conta-2']);
      expect(varias.billIds, ['conta-1', 'conta-2']);
      expect(varias.isLinkedToBill, isTrue);
      expect(varias.toMap()['billIds'], ['conta-1', 'conta-2']);
    });

    test('desfazer o vínculo limpa todas', () {
      final ligada = item('d', date: dia1, billIds: const ['conta-1', 'conta-2']);
      final solta = ligada.copyWith(clearBill: true);
      expect(solta.isLinkedToBill, isFalse);
      expect(solta.billIds, isEmpty);
    });
  });

  group('Local no mapa', () {
    test('sem coordenada, o item não está fixado no mapa', () {
      expect(item('a', date: dia1).hasCoords, isFalse);
      expect(item('b', date: dia1, lat: -27.6).hasCoords, isFalse);
    });

    test('com as duas coordenadas, sim', () {
      expect(item('c', date: dia1, lat: -27.6, lng: -48.4).hasCoords, isTrue);
    });

    test('tirar do mapa não apaga o nome do lugar', () {
      final fixado = item(
        'd',
        date: dia1,
        lat: -27.6,
        lng: -48.4,
        placeName: 'Praia da Joaquina',
      );
      final solto = fixado.copyWith(clearCoords: true);

      expect(solto.hasCoords, isFalse);
      expect(solto.placeName, 'Praia da Joaquina');
    });

    test('a coordenada vai para o banco', () {
      final mapa = item('e', date: dia1, lat: -27.6, lng: -48.4).toMap();
      expect(mapa['lat'], -27.6);
      expect(mapa['lng'], -48.4);
    });
  });

  group('Nome do lugar vindo da geocodificação', () {
    test('lugar com nome próprio usa o nome', () {
      final json = {
        'name': 'Praia da Joaquina',
        'display_name': 'Praia da Joaquina, Lagoa, Florianópolis, Santa Catarina',
        'address': {
          'suburb': 'Lagoa',
          'city': 'Florianópolis',
          'state': 'Santa Catarina',
        },
      };

      expect(GeocodingService.placeLabel(json), 'Praia da Joaquina');
      expect(GeocodingService.shortAddress(json), 'Lagoa, Florianópolis, Santa Catarina');
    });

    test('ponto no meio da rua cai na rua', () {
      final json = {
        'name': '',
        'display_name': 'Rua Bocaiúva, Centro, Florianópolis',
        'address': {'road': 'Rua Bocaiúva', 'city': 'Florianópolis'},
      };

      expect(GeocodingService.placeLabel(json), 'Rua Bocaiúva');
    });

    test('o complemento não repete o que já está no nome', () {
      final json = {
        'name': 'Lagoa',
        'address': {'suburb': 'Lagoa', 'city': 'Florianópolis'},
      };

      expect(GeocodingService.shortAddress(json), 'Florianópolis');
    });

    test('resposta sem nada reconhecível não inventa nome', () {
      expect(GeocodingService.placeLabel({}), isNull);
      expect(GeocodingService.shortAddress({}), isNull);
    });
  });

  group('Horário opcional', () {
    test('item sem horário não tem hora', () {
      expect(item('a', date: dia1).hasTime, isFalse);
    });

    test('tirar o horário de um item que tinha', () {
      final comHora = item('b', date: dia1, hora: 9);
      expect(comHora.hasTime, isTrue);
      expect(comHora.copyWith(clearTime: true).hasTime, isFalse);
    });
  });

  group('Várias categorias e transportes', () {
    final passeio = ItineraryItem(
      id: 'p',
      title: 'Ilha do Campeche',
      date: dia1,
      categories: const [ItineraryCategory.tour, ItineraryCategory.lunch],
      transports: const [TransportMode.car, TransportMode.boat],
    );

    test('a primeira categoria marcada é a principal', () {
      expect(passeio.category, ItineraryCategory.tour);
      expect(passeio.categoriesLabel, 'Passeio, Almoço');
      expect(passeio.transportsLabel, 'Carro, Barco');
    });

    test('grava as listas e apaga os campos de valor único', () {
      final map = passeio.toMap();
      expect(map['categories'], ['tour', 'lunch']);
      expect(map['transports'], ['car', 'boat']);
      expect(map['category'], isA<FieldValue>());
      expect(map['transport'], isA<FieldValue>());
    });

    test('sem transporte não mostra nada', () {
      final semTransporte = passeio.copyWith(clearTransport: true);
      expect(semTransporte.transports, isEmpty);
      expect(semTransporte.transportsLabel, isNull);
    });
  });
}
