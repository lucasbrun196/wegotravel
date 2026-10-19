import 'package:flutter_test/flutter_test.dart';
import 'package:we_go_travel/core/utils/money.dart';
import 'package:we_go_travel/data/models/bill.dart';
import 'package:we_go_travel/data/models/enums.dart';

/// NumberFormat separa o símbolo do valor com espaço não separável
/// (U+00A0). Normalizamos para o teste ficar legível.
String brl(int cents) => Money.format(cents).replaceAll('\u00A0', ' ');

void main() {
  group('Money.divide não perde centavos', () {
    test('divisão exata', () {
      expect(Money.divide(100000, 4), [25000, 25000, 25000, 25000]);
    });

    test('resto é distribuído, e a soma bate com o total', () {
      final parts = Money.divide(100, 3);
      expect(parts, [34, 33, 33]);
      expect(parts.fold<int>(0, (a, b) => a + b), 100);
    });

    test('valor quebrado entre 4 fecha exatamente', () {
      final parts = Money.divide(65001, 4);
      expect(parts.fold<int>(0, (a, b) => a + b), 65001);
    });
  });

  group('Money.parse aceita o formato brasileiro', () {
    test('com milhar e decimal', () => expect(Money.parse('9.000,00'), 900000));
    test('só decimal', () => expect(Money.parse('1656,00'), 165600));
    test('sem decimal', () => expect(Money.parse('250'), 25000));
    test('com símbolo', () => expect(Money.parse(r'R$ 414,00'), 41400));
    test('texto inválido', () => expect(Money.parse('abc'), isNull));
  });

  group('Airbnb: R\$ 9.000 em 6x entre 4 pessoas', () {
    // O valor da parcela nunca é digitado: sai de total ÷ parcelas.
    final airbnb = Bill(
      id: 'airbnb',
      title: 'Aluguel do Airbnb',
      categories: const [BillCategory.lodging],
      type: BillType.fixed,
      totalAmountCents: 900000,
      installmentCount: 6,
      firstDueDate: DateTime(2026, 1, 10),
      paidByMemberId: 'manuela',
      participantIds: ['manuela', 'lucas', 'ana', 'pedro'],
    );

    test('a parcela é derivada do total, não informada', () {
      expect(airbnb.chargedTotalCents, 900000);
      expect(airbnb.effectiveInstallmentCents, 150000);
    });

    test('cada pessoa paga R\$ 375,00 por mês', () {
      expect(airbnb.perPersonPerInstallmentCents, 37500);
      expect(brl(37500), r'R$ 375,00');
    });

    test('gera 24 cotas: 6 parcelas × 4 pessoas', () {
      final shares = airbnb.generateShares(tripId: 'viagem-teste');
      expect(shares.length, 24);
      expect(shares.every((s) => s.amountCents == 37500), isTrue);
    });

    test('toda cota carrega o id da viagem', () {
      final shares = airbnb.generateShares(tripId: 'viagem-teste');
      expect(shares.every((s) => s.tripId == 'viagem-teste'), isTrue);
    });

    test('a soma das cotas bate exatamente com o total cobrado', () {
      final total = airbnb
          .generateShares(tripId: 'viagem-teste')
          .fold<int>(0, (a, s) => a + s.amountCents);
      expect(total, 900000);
    });

    test('a cota de quem bancou é marcada como própria', () {
      final shares = airbnb.generateShares(tripId: 'viagem-teste');
      final manuela = shares.where((s) => s.memberId == 'manuela');
      expect(manuela.length, 6);
      expect(manuela.every((s) => s.isOwnerShare), isTrue);
      expect(shares.where((s) => s.isOwnerShare).length, 6);
    });

    test('parcelamento que não divide exato não perde centavo', () {
      final bill = Bill(
        id: 'quebrado',
        title: 'Passeio',
        categories: const [BillCategory.tours],
        type: BillType.fixed,
        totalAmountCents: 100001,
        installmentCount: 3,
        participantIds: ['a', 'b'],
      );
      final shares = bill.generateShares(tripId: 't');
      expect(shares.fold<int>(0, (a, s) => a + s.amountCents), 100001);
    });

    test('parcelamento que não divide exato não perde centavo', () {
      final bill = Bill(
        id: 'quebrado',
        title: 'Passeio',
        categories: const [BillCategory.tours],
        type: BillType.fixed,
        totalAmountCents: 100001,
        installmentCount: 3,
        participantIds: ['a', 'b'],
      );
      final shares = bill.generateShares(tripId: 't');
      expect(shares.fold<int>(0, (a, s) => a + s.amountCents), 100001);
    });

    test('vencimentos caem todo dia 10, mês a mês', () {
      expect(airbnb.dueDateFor(1), DateTime(2026, 1, 10));
      expect(airbnb.dueDateFor(3), DateTime(2026, 3, 10));
      expect(airbnb.dueDateFor(6), DateTime(2026, 6, 10));
    });

    test('vencimento no dia 31 cai no último dia de meses curtos', () {
      final bill = Bill(
        id: 'x',
        title: 'x',
        categories: const [BillCategory.other],
        type: BillType.fixed,
        totalAmountCents: 30000,
        installmentCount: 3,
        firstDueDate: DateTime(2026, 1, 31),
        participantIds: ['a'],
      );
      expect(bill.dueDateFor(2), DateTime(2026, 2, 28));
      expect(bill.dueDateFor(3), DateTime(2026, 3, 31));
    });
  });

  group('Gasolina: conta aberta, dividida no final entre 4', () {
    // Não se sabe o total no início. A cada abastecimento entra um
    // lançamento, e o fechamento transforma a soma em cotas.
    Bill gas(int totalCents) => Bill(
          id: 'gasolina',
          title: 'Gasolina',
          categories: const [BillCategory.fuel],
          type: BillType.accumulating,
          paidByMemberId: 'lucas',
          participantIds: ['lucas', 'manuela', 'ana', 'pedro'],
          entriesTotalCents: totalCents,
          entriesCount: 3,
        );

    test('o total vem da soma dos lançamentos', () {
      // Posto A 250 + Posto B 180 + Posto C 220
      expect(gas(65000).chargedTotalCents, 65000);
    });

    test('divide igualmente entre os 4, uma cota cada', () {
      final shares = gas(65000).generateShares(tripId: 'viagem-teste');
      expect(shares.length, 4);
      expect(shares.every((s) => s.amountCents == 16250), isTrue);
      expect(brl(16250), r'R$ 162,50');
    });

    test('valor que não divide certo não perde centavo', () {
      final shares = gas(65001).generateShares(tripId: 'viagem-teste');
      expect(shares.fold<int>(0, (a, s) => a + s.amountCents), 65001);
      expect(shares.map((s) => s.amountCents).toList(), [16251, 16250, 16250, 16250]);
    });

    test('quem dirigiu não transfere para si mesmo', () {
      final shares = gas(65000).generateShares(tripId: 'viagem-teste');
      final devedores = shares.where((s) => !s.isOwnerShare);
      expect(devedores.length, 3);
      expect(devedores.fold<int>(0, (a, s) => a + s.amountCents), 48750);
    });
  });

  group('Total nunca ganha nem perde centavo no arredondamento', () {
    // Caso relatado: 9.950,00 em 6x. A parcela dá 1.658,3333 e arredonda
    // para 1.658,34 — multiplicar isso de volta por 6 daria 9.950,04.
    // O total tem que continuar sendo o que foi digitado.
    Bill conta(int totalCents, int parcelas, int pessoas) => Bill(
          id: 'x',
          title: 'x',
          categories: const [BillCategory.lodging],
          type: BillType.fixed,
          totalAmountCents: totalCents,
          installmentCount: parcelas,
          participantIds: List.generate(pessoas, (i) => 'p$i'),
        );

    test('9.950,00 em 6x continua valendo 9.950,00', () {
      final bill = conta(995000, 6, 4);
      expect(bill.chargedTotalCents, 995000);
      expect(
        bill.generateShares(tripId: 't').fold<int>(0, (a, s) => a + s.amountCents),
        995000,
      );
    });

    test('a soma das cotas fecha para qualquer combinação', () {
      for (final total in [995000, 100001, 33, 1, 7777777]) {
        for (var parcelas = 1; parcelas <= 12; parcelas++) {
          for (var pessoas = 1; pessoas <= 7; pessoas++) {
            final bill = conta(total, parcelas, pessoas);
            final soma = bill
                .generateShares(tripId: 't')
                .fold<int>(0, (a, s) => a + s.amountCents);
            expect(
              soma,
              total,
              reason: 'total=$total parcelas=$parcelas pessoas=$pessoas',
            );
          }
        }
      }
    });
  });

  group('Divisão personalizada', () {
    test('respeita pesos diferentes e preserva o total', () {
      final bill = Bill(
        id: 'quarto',
        title: 'Quarto de casal',
        categories: const [BillCategory.lodging],
        type: BillType.fixed,
        totalAmountCents: 100000,
        participantIds: ['casal', 'solteiro'],
        splitMode: SplitMode.custom,
        customWeights: {'casal': 2, 'solteiro': 1},
      );
      final shares = bill.generateShares(tripId: 'viagem-teste');
      expect(shares.map((s) => s.amountCents).toList(), [66667, 33333]);
      expect(shares.fold<int>(0, (a, s) => a + s.amountCents), 100000);
    });
  });
}
