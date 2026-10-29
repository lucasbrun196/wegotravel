import '../../core/utils/money.dart';
import 'bill.dart';
import 'bill_entry.dart';
import 'bill_share.dart';
import 'enums.dart';

/// Uma transferência do acerto: [fromId] deve [amountCents] para [toId].
class SettlementTransfer {
  const SettlementTransfer({
    required this.fromId,
    required this.toId,
    required this.amountCents,
  });

  final String fromId;
  final String toId;
  final int amountCents;
}

/// O acerto de uma conta aberta em que cada lançamento pode ter sido
/// bancado por uma pessoa diferente — a gasolina que cada um pagou numa
/// parada — e dividido só entre algumas — a compra do mercado que só dois
/// comeram.
///
/// Cada pessoa tem o que **pagou** (soma dos lançamentos que bancou) e a
/// sua **parte** (cada lançamento dividido entre quem o divide). Quem pagou
/// mais que a parte recebe; quem pagou menos transfere. As transferências
/// saem do casamento guloso entre o maior devedor e o maior credor, o que
/// dá no máximo uma a menos que o número de pessoas.
///
/// Função pura e em centavos inteiros: a soma das partes bate com o total,
/// e o que cada um transfere bate com o quanto ficou devendo.
class BillSettlement {
  const BillSettlement._({
    required this.totalCents,
    required this.paidCents,
    required this.owedCents,
    required this.transfers,
    required this.memberIds,
  });

  factory BillSettlement.of(Bill bill, List<BillEntry> entries) {
    final paid = <String, int>{};
    var total = 0;

    // Os lançamentos se agrupam por quem os divide, e cada grupo é somado
    // antes de dividir: a divisão de cada lançamento em separado jogaria o
    // centavo de resto sempre na mesma pessoa. Com todos divididos por
    // todos, sobra um grupo só — a conta inteira dividida uma vez.
    final groups = <String, (List<String>, int)>{};
    for (final entry in entries) {
      total += entry.amountCents;
      // Lançamento antigo, de antes de cada um ter pagador, fica com quem
      // bancou a conta. Sem nenhum dos dois, entra no total e na parte de
      // cada um, mas não gera transferência para ninguém.
      final payer = entry.paidByMemberId ?? bill.paidByMemberId;
      if (payer != null) paid[payer] = (paid[payer] ?? 0) + entry.amountCents;

      final among = entry.splitAmong(bill);
      final key = among.join('|');
      final (_, sum) = groups[key] ?? (among, 0);
      groups[key] = (among, sum + entry.amountCents);
    }

    final custom = bill.splitMode == SplitMode.custom && bill.customWeights.isNotEmpty;
    final owed = <String, int>{};
    for (final (among, sum) in groups.values) {
      if (among.isEmpty) continue;
      final parts = custom
          ? Money.divideByWeights(sum, among.map((m) => bill.customWeights[m] ?? 1).toList())
          : Money.divide(sum, among.length);
      for (var i = 0; i < among.length; i++) {
        owed[among[i]] = (owed[among[i]] ?? 0) + parts[i];
      }
    }

    final participants = bill.participantIds.isEmpty
        ? [?bill.paidByMemberId]
        : bill.participantIds;

    // Participantes primeiro, na ordem da conta; depois quem só aparece
    // num lançamento ou só pagou algo sem entrar na divisão.
    final memberIds = [
      ...participants,
      ...owed.keys.where((id) => !participants.contains(id)),
      ...paid.keys.where((id) => !participants.contains(id) && !owed.containsKey(id)),
    ];
    // Quem divide a conta mas ficou de fora de todos os lançamentos não
    // deve nada — e ainda aparece no acerto, com zero.
    for (final id in participants) {
      owed.putIfAbsent(id, () => 0);
    }

    return BillSettlement._(
      totalCents: total,
      paidCents: paid,
      owedCents: owed,
      transfers: _match(memberIds, paid, owed),
      memberIds: memberIds,
    );
  }

  final int totalCents;
  final Map<String, int> paidCents;
  final Map<String, int> owedCents;
  final List<SettlementTransfer> transfers;

  /// Todo mundo que aparece no acerto: quem divide e quem pagou.
  final List<String> memberIds;

  int paidBy(String memberId) => paidCents[memberId] ?? 0;
  int owedBy(String memberId) => owedCents[memberId] ?? 0;

  /// Positivo: tem a receber. Negativo: tem a pagar.
  int balanceOf(String memberId) => paidBy(memberId) - owedBy(memberId);

  List<SettlementTransfer> debtsOf(String memberId) =>
      transfers.where((t) => t.fromId == memberId).toList();

  List<SettlementTransfer> creditsOf(String memberId) =>
      transfers.where((t) => t.toId == memberId).toList();

  static List<SettlementTransfer> _match(
    List<String> memberIds,
    Map<String, int> paid,
    Map<String, int> owed,
  ) {
    final creditors = <MapEntry<String, int>>[];
    final debtors = <MapEntry<String, int>>[];
    for (final id in memberIds) {
      final balance = (paid[id] ?? 0) - (owed[id] ?? 0);
      if (balance > 0) creditors.add(MapEntry(id, balance));
      if (balance < 0) debtors.add(MapEntry(id, -balance));
    }

    // Maior valor primeiro; empate pela ordem da conta, para o mesmo
    // acerto sair sempre igual.
    int byAmount(MapEntry<String, int> a, MapEntry<String, int> b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : memberIds.indexOf(a.key).compareTo(memberIds.indexOf(b.key));
    }

    creditors.sort(byAmount);
    debtors.sort(byAmount);

    final transfers = <SettlementTransfer>[];
    var c = 0, d = 0;
    var credit = creditors.isEmpty ? 0 : creditors.first.value;
    var debt = debtors.isEmpty ? 0 : debtors.first.value;

    while (c < creditors.length && d < debtors.length) {
      final amount = credit < debt ? credit : debt;
      transfers.add(SettlementTransfer(
        fromId: debtors[d].key,
        toId: creditors[c].key,
        amountCents: amount,
      ));
      credit -= amount;
      debt -= amount;
      if (credit == 0 && ++c < creditors.length) credit = creditors[c].value;
      if (debt == 0 && ++d < debtors.length) debt = debtors[d].value;
    }

    return transfers;
  }

  /// As cotas que o fechamento grava.
  ///
  /// Uma por transferência (`1_{devedor}_{credor}`, com [BillShare.creditorId])
  /// e uma "própria" por pessoa (`1_{uid}`, [BillShare.isOwnerShare]) com a
  /// parte que ela cobriu do próprio bolso — que não gera transferência,
  /// mas mantém a soma das cotas igual ao total da conta.
  List<BillShare> toShares({required String tripId, required String billId}) {
    final shares = <BillShare>[];

    for (final id in memberIds) {
      final outgoing = debtsOf(id).fold<int>(0, (sum, t) => sum + t.amountCents);
      final own = owedBy(id) - outgoing;
      if (own > 0) {
        shares.add(BillShare(
          id: '1_$id',
          billId: billId,
          tripId: tripId,
          memberId: id,
          amountCents: own,
          isOwnerShare: true,
        ));
      }
    }

    for (final t in transfers) {
      shares.add(BillShare(
        id: '1_${t.fromId}_${t.toId}',
        billId: billId,
        tripId: tripId,
        memberId: t.fromId,
        creditorId: t.toId,
        amountCents: t.amountCents,
      ));
    }

    return shares;
  }
}
