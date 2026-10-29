import 'package:flutter_test/flutter_test.dart';
import 'package:we_go_travel/data/models/bill.dart';
import 'package:we_go_travel/data/models/bill_entry.dart';
import 'package:we_go_travel/data/models/bill_settlement.dart';
import 'package:we_go_travel/data/models/enums.dart';

void main() {
  // Gasolina entre 4, e cada abastecimento bancado por quem estava com o
  // cartão naquela parada.
  final gas = Bill(
    id: 'gasolina',
    title: 'Gasolina',
    categories: const [BillCategory.fuel],
    type: BillType.accumulating,
    paidByMemberId: 'lucas',
    participantIds: ['lucas', 'manuela', 'ana', 'pedro'],
  );

  var n = 0;
  BillEntry fill(int cents, String? payer) => BillEntry(
        id: 'e${n++}',
        billId: 'gasolina',
        description: '',
        amountCents: cents,
        date: DateTime(2026, 1, 10),
        paidByMemberId: payer,
      );

  int sum(Iterable<int> values) => values.fold<int>(0, (a, b) => a + b);

  group('Acerto da conta aberta com vários pagadores', () {
    // Lucas 300 + Manuela 100 = 400 → 100 para cada.
    final settlement = BillSettlement.of(gas, [
      fill(20000, 'lucas'),
      fill(10000, 'lucas'),
      fill(10000, 'manuela'),
    ]);

    test('soma o quanto cada um pagou', () {
      expect(settlement.totalCents, 40000);
      expect(settlement.paidBy('lucas'), 30000);
      expect(settlement.paidBy('manuela'), 10000);
      expect(settlement.paidBy('ana'), 0);
    });

    test('quem pagou a mais recebe, quem não pagou transfere', () {
      expect(settlement.balanceOf('lucas'), 20000);
      expect(settlement.balanceOf('manuela'), 0);
      expect(settlement.debtsOf('ana').single.toId, 'lucas');
      expect(settlement.debtsOf('pedro').single.amountCents, 10000);
      expect(settlement.debtsOf('manuela'), isEmpty);
      expect(sum(settlement.creditsOf('lucas').map((t) => t.amountCents)), 20000);
    });

    test('a soma das cotas bate com o total', () {
      final shares = settlement.toShares(tripId: 't', billId: 'gasolina');
      expect(sum(shares.map((s) => s.amountCents)), 40000);
      // Quem transfere não tem cota própria: não cobriu nada sozinho.
      expect(shares.where((s) => s.id == '1_ana'), isEmpty);
      expect(shares.any((s) => s.id == '1_ana_lucas' && s.creditorId == 'lucas'), isTrue);
    });

    test('pessoa deve para mais de uma', () {
      // Lucas 600, Manuela 600, Ana 0, Pedro 0 → 300 cada. Ana e Pedro
      // devem 300 cada; Lucas e Manuela recebem 300 cada.
      final s = BillSettlement.of(gas, [fill(60000, 'lucas'), fill(60000, 'manuela')]);
      for (final id in ['ana', 'pedro']) {
        expect(sum(s.debtsOf(id).map((t) => t.amountCents)), 30000);
      }
      expect(sum(s.creditsOf('lucas').map((t) => t.amountCents)), 30000);
      expect(sum(s.creditsOf('manuela').map((t) => t.amountCents)), 30000);

      // Ana pagou um pouco: passa a dever menos, para os dois.
      final t = BillSettlement.of(gas, [
        fill(50000, 'lucas'),
        fill(50000, 'manuela'),
        fill(20000, 'ana'),
      ]);
      expect(t.debtsOf('ana').single.amountCents, 10000);
      expect(sum(t.debtsOf('pedro').map((x) => x.amountCents)), 30000);
      expect(t.debtsOf('pedro').length, 2);
    });

    test('centavo de resto não some', () {
      final s = BillSettlement.of(gas, [fill(10001, 'pedro')]);
      expect(s.owedBy('lucas'), 2501);
      expect(sum(s.creditsOf('pedro').map((t) => t.amountCents)), 10001 - 2500);
      final shares = s.toShares(tripId: 't', billId: 'gasolina');
      expect(sum(shares.map((x) => x.amountCents)), 10001);
    });

    test('quem pagou sem dividir a conta recebe tudo de volta', () {
      final s = BillSettlement.of(gas, [fill(40000, 'tio')]);
      expect(s.memberIds.last, 'tio');
      expect(s.owedBy('tio'), 0);
      expect(sum(s.creditsOf('tio').map((t) => t.amountCents)), 40000);
    });

    test('lançamento antigo, sem pagador, fica com quem bancou a conta', () {
      final s = BillSettlement.of(gas, [fill(40000, null)]);
      expect(s.paidBy('lucas'), 40000);
      expect(s.debtsOf('ana').single.toId, 'lucas');
    });
  });

  group('Lançamento dividido só entre algumas pessoas', () {
    // Mercado entre 4, mas nem toda compra é de todo mundo.
    BillEntry buy(int cents, String payer, [List<String> among = const []]) => BillEntry(
          id: 'e${n++}',
          billId: 'gasolina',
          description: '',
          amountCents: cents,
          date: DateTime(2026, 1, 10),
          paidByMemberId: payer,
          participantIds: among,
        );

    test('a compra de dois só entra na parte dos dois', () {
      // R$ 190 de Lucas e Ana: 95 cada; Manuela e Pedro não devem nada.
      final s = BillSettlement.of(gas, [buy(19000, 'lucas', ['lucas', 'ana'])]);
      expect(s.owedBy('lucas'), 9500);
      expect(s.owedBy('ana'), 9500);
      expect(s.owedBy('manuela'), 0);
      expect(s.owedBy('pedro'), 0);
      expect(s.debtsOf('ana').single.amountCents, 9500);
      expect(s.debtsOf('manuela'), isEmpty);
      // Continuam no acerto, com zero, na ordem da conta.
      expect(s.memberIds, ['lucas', 'manuela', 'ana', 'pedro']);
    });

    test('só eu: não gera dívida para ninguém', () {
      final s = BillSettlement.of(gas, [buy(19000, 'lucas', ['lucas'])]);
      expect(s.owedBy('lucas'), 19000);
      expect(s.transfers, isEmpty);
      final shares = s.toShares(tripId: 't', billId: 'gasolina');
      expect(sum(shares.map((x) => x.amountCents)), 19000);
    });

    test('mistura de lançamentos de todos e de alguns', () {
      // 400 de todos (100 cada) + 190 de Lucas e Ana (95 cada).
      final s = BillSettlement.of(gas, [
        buy(40000, 'manuela'),
        buy(19000, 'lucas', ['ana', 'lucas']),
      ]);
      expect(s.owedBy('lucas'), 19500);
      expect(s.owedBy('ana'), 19500);
      expect(s.owedBy('manuela'), 10000);
      expect(s.owedBy('pedro'), 10000);
      expect(sum(s.owedCents.values), 59000);
      final shares = s.toShares(tripId: 't', billId: 'gasolina');
      expect(sum(shares.map((x) => x.amountCents)), 59000);
    });

    test('mesmo grupo soma antes de dividir: o resto não cai sempre no mesmo', () {
      // Três lançamentos de 1 centavo entre Lucas e Ana: 3 centavos, 2 + 1.
      final s = BillSettlement.of(gas, [
        for (var i = 0; i < 3; i++) buy(1, 'pedro', ['lucas', 'ana']),
      ]);
      expect(s.owedBy('lucas') + s.owedBy('ana'), 3);
      expect((s.owedBy('lucas') - s.owedBy('ana')).abs(), 1);
    });

    test('marcar todo mundo é o mesmo que todos', () {
      final all = BillSettlement.of(gas, [buy(10001, 'pedro')]);
      final listed = BillSettlement.of(gas, [
        buy(10001, 'pedro', ['pedro', 'ana', 'manuela', 'lucas']),
      ]);
      for (final id in gas.participantIds) {
        expect(listed.owedBy(id), all.owedBy(id));
      }
    });

    test('quem saiu da conta continua no lançamento em que entrou', () {
      final s = BillSettlement.of(gas, [buy(10000, 'lucas', ['lucas', 'tio'])]);
      expect(s.owedBy('tio'), 5000);
      expect(s.memberIds, contains('tio'));
      expect(s.debtsOf('tio').single.toId, 'lucas');
    });
  });
}
