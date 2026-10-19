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
}
