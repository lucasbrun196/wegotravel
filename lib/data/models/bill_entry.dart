import 'package:cloud_firestore/cloud_firestore.dart';

import 'attachment.dart';
import 'bill.dart';

/// Um lançamento dentro de uma conta aberta.
///
/// É o "cada vez que eu abastecer": Posto A R$ 250, Posto B R$ 180...
/// O total da conta é a soma dos lançamentos, e só no fechamento ele
/// vira cotas para os participantes.
class BillEntry {
  const BillEntry({
    required this.id,
    required this.billId,
    required this.description,
    required this.amountCents,
    required this.date,
    this.paidByMemberId,
    this.participantIds = const [],
    this.receipts = const [],
    this.notes,
    this.createdAt,
  });

  final String id;
  final String billId;
  final String description;
  final int amountCents;
  final DateTime date;

  /// Quem desembolsou. Normalmente é sempre a mesma pessoa (o dono do
  /// carro, no caso da gasolina), mas nada impede que varie.
  final String? paidByMemberId;

  /// Quem divide este lançamento — a compra do mercado que só dois
  /// comeram. **Vazia quer dizer todos os participantes da conta**: é o
  /// caso comum, é como os lançamentos antigos chegam, e acompanha a conta
  /// se alguém entrar nela depois.
  final List<String> participantIds;

  bool get isSplitByAll => participantIds.isEmpty;

  /// Entre quem o valor é dividido de fato, na ordem dos participantes da
  /// conta — é essa ordem que decide quem leva o centavo de resto.
  List<String> splitAmong(Bill bill) {
    final all = bill.participantIds.isEmpty ? [?bill.paidByMemberId] : bill.participantIds;
    if (isSplitByAll) return all;
    return [
      ...all.where(participantIds.contains),
      // Quem saiu da conta depois de entrar no lançamento continua nele.
      ...participantIds.where((id) => !all.contains(id)),
    ];
  }

  final List<Attachment> receipts;
  final String? notes;
  final DateTime? createdAt;

  factory BillEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return BillEntry(
      id: doc.id,
      billId: d['billId'] as String? ?? '',
      description: d['description'] as String? ?? '',
      amountCents: (d['amountCents'] as num?)?.toInt() ?? 0,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidByMemberId: d['paidByMemberId'] as String?,
      participantIds: (d['participantIds'] as List<dynamic>? ?? []).whereType<String>().toList(),
      receipts: (d['receipts'] as List<dynamic>? ?? [])
          .map((e) => Attachment.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      notes: d['notes'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'billId': billId,
        'description': description,
        'amountCents': amountCents,
        'date': Timestamp.fromDate(date),
        'paidByMemberId': paidByMemberId,
        'participantIds': participantIds,
        'receipts': receipts.map((r) => r.toMap()).toList(),
        'notes': notes,
        'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      };

  BillEntry copyWith({
    String? description,
    int? amountCents,
    DateTime? date,
    String? paidByMemberId,
    List<String>? participantIds,
    List<Attachment>? receipts,
    String? notes,
  }) =>
      BillEntry(
        id: id,
        billId: billId,
        description: description ?? this.description,
        amountCents: amountCents ?? this.amountCents,
        date: date ?? this.date,
        paidByMemberId: paidByMemberId ?? this.paidByMemberId,
        participantIds: participantIds ?? this.participantIds,
        receipts: receipts ?? this.receipts,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}
