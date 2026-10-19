import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:we_go_travel/data/services/sync_status_service.dart';

SyncMetadata meta({bool cache = false, bool pending = false}) =>
    SyncMetadata(isFromCache: cache, hasPendingWrites: pending);

void main() {
  group('A regra, sem o tempo', () {
    test('dado do servidor é estar em dia', () {
      expect(SyncStatusService.statusOf(meta()), SyncStatus.online);
    });

    test('dado do cache é estar offline', () {
      expect(SyncStatusService.statusOf(meta(cache: true)), SyncStatus.offline);
    });

    test('escrita na fila vence o resto', () {
      // Escrever offline deixa as duas marcas no snapshot. O que importa
      // dizer é que a alteração ainda não subiu.
      expect(
        SyncStatusService.statusOf(meta(cache: true, pending: true)),
        SyncStatus.pending,
      );
      expect(SyncStatusService.statusOf(meta(pending: true)), SyncStatus.pending);
    });
  });

  group('Carência do aviso de offline', () {
    // Curta para o teste não esperar: a carência é parâmetro justamente
    // para poder ser encurtada aqui.
    const grace = Duration(milliseconds: 40);
    const service = SyncStatusService(grace: grace);

    test('cache seguido do servidor não vira aviso', () async {
      final source = StreamController<SyncMetadata>();
      final seen = <SyncStatus>[];
      final sub = service.watch(source.stream).listen(seen.add);

      // A abertura com rede é sempre assim: o cache primeiro, a resposta
      // do servidor logo atrás.
      source.add(meta(cache: true));
      source.add(meta());
      await Future<void>.delayed(grace * 3);

      expect(seen, [SyncStatus.online]);
      await sub.cancel();
      await source.close();
    });

    test('cache que persiste vira aviso', () async {
      final source = StreamController<SyncMetadata>();
      final seen = <SyncStatus>[];
      final sub = service.watch(source.stream).listen(seen.add);

      source.add(meta(cache: true));
      await Future<void>.delayed(grace * 3);

      expect(seen, [SyncStatus.offline]);
      await sub.cancel();
      await source.close();
    });

    test('a volta da rede desarma o aviso', () async {
      final source = StreamController<SyncMetadata>();
      final seen = <SyncStatus>[];
      final sub = service.watch(source.stream).listen(seen.add);

      source.add(meta(cache: true));
      await Future<void>.delayed(grace * 3);
      source.add(meta());
      await Future<void>.delayed(grace);

      expect(seen, [SyncStatus.offline, SyncStatus.online]);
      await sub.cancel();
      await source.close();
    });

    test('escrita pendente aparece na hora, sem carência', () async {
      final source = StreamController<SyncMetadata>();
      final seen = <SyncStatus>[];
      final sub = service.watch(source.stream).listen(seen.add);

      source.add(meta(cache: true, pending: true));
      await Future<void>.delayed(Duration.zero);

      expect(seen, [SyncStatus.pending]);
      await sub.cancel();
      await source.close();
    });

    test('estado repetido não emite de novo', () async {
      final source = StreamController<SyncMetadata>();
      final seen = <SyncStatus>[];
      final sub = service.watch(source.stream).listen(seen.add);

      source.add(meta());
      source.add(meta());
      source.add(meta());
      await Future<void>.delayed(grace);

      expect(seen, [SyncStatus.online]);
      await sub.cancel();
      await source.close();
    });

    test('cancelar a escuta desarma o timer pendente', () async {
      final source = StreamController<SyncMetadata>();
      final seen = <SyncStatus>[];
      final sub = service.watch(source.stream).listen(seen.add);

      source.add(meta(cache: true));
      await sub.cancel();
      await Future<void>.delayed(grace * 3);

      expect(seen, isEmpty);
      await source.close();
    });
  });
}
