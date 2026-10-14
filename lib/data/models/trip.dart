import 'package:cloud_firestore/cloud_firestore.dart';

/// A viagem: o documento raiz sob o qual tudo mais vive.
class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.adminId,
    this.memberIds = const [],
    this.destination = '',
    this.destinationLat,
    this.destinationLng,
    this.description,
    this.startDate,
    this.endDate,
    this.coverImageUrl,
    this.coverStoragePath,
    this.currency = 'BRL',
    this.budgetCents,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;

  /// Quem criou a viagem. Só o admin gerencia a lista de participantes.
  final String adminId;

  /// Espelho dos ids dos membros no próprio documento da viagem.
  /// É o que permite "minhas viagens" com uma consulta só
  /// (`array-contains`) e o que as regras de segurança conferem.
  final List<String> memberIds;
  final String destination;

  /// Ponto do destino escolhido no mapa. Como no roteiro, a coordenada só
  /// existe no banco — a tela mostra `destination`. É onde o mapa abre
  /// quando a primeira atividade ainda não tem ponto.
  final double? destinationLat;
  final double? destinationLng;

  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? coverImageUrl;
  final String? coverStoragePath;
  final String currency;

  /// Orçamento previsto da viagem, opcional.
  final int? budgetCents;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasDates => startDate != null && endDate != null;

  bool get hasDestinationCoords => destinationLat != null && destinationLng != null;

  bool isAdmin(String? uid) => uid != null && uid == adminId;

  bool hasMember(String? uid) => uid != null && memberIds.contains(uid);

  int get totalDays =>
      hasDates ? endDate!.difference(startDate!).inDays + 1 : 0;

  /// Negativo antes de começar, 1..totalDays durante, maior depois.
  int get currentDay {
    if (!hasDates) return 0;
    final today = DateTime.now();
    final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
    return DateTime(today.year, today.month, today.day).difference(start).inDays + 1;
  }

  bool get isUpcoming => hasDates && currentDay < 1;
  bool get isOngoing => hasDates && currentDay >= 1 && currentDay <= totalDays;
  bool get isFinished => hasDates && currentDay > totalDays;

  int get daysUntilStart {
    if (!hasDates) return 0;
    return (1 - currentDay).clamp(0, 99999);
  }

  factory Trip.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Trip(
      id: doc.id,
      name: d['name'] as String? ?? 'Nossa viagem',
      adminId: d['adminId'] as String? ?? '',
      memberIds: (d['memberIds'] as List<dynamic>? ?? []).cast<String>(),
      destination: d['destination'] as String? ?? '',
      destinationLat: (d['destinationLat'] as num?)?.toDouble(),
      destinationLng: (d['destinationLng'] as num?)?.toDouble(),
      description: d['description'] as String?,
      startDate: (d['startDate'] as Timestamp?)?.toDate(),
      endDate: (d['endDate'] as Timestamp?)?.toDate(),
      coverImageUrl: d['coverImageUrl'] as String?,
      coverStoragePath: d['coverStoragePath'] as String?,
      currency: d['currency'] as String? ?? 'BRL',
      budgetCents: (d['budgetCents'] as num?)?.toInt(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'adminId': adminId,
        'memberIds': memberIds,
        'destination': destination,
        'destinationLat': destinationLat,
        'destinationLng': destinationLng,
        'description': description,
        'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
        'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
        'coverImageUrl': coverImageUrl,
        'coverStoragePath': coverStoragePath,
        'currency': currency,
        'budgetCents': budgetCents,
        'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Trip copyWith({
    String? name,
    List<String>? memberIds,
    String? destination,
    double? destinationLat,
    double? destinationLng,
    /// Tira o destino do mapa. Sem isto não há como zerar a coordenada:
    /// `null` nos dois campos acima quer dizer "manter a atual".
    bool clearDestinationCoords = false,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? coverImageUrl,
    String? coverStoragePath,
    int? budgetCents,
  }) =>
      Trip(
        id: id,
        name: name ?? this.name,
        adminId: adminId,
        memberIds: memberIds ?? this.memberIds,
        destination: destination ?? this.destination,
        destinationLat: clearDestinationCoords ? null : destinationLat ?? this.destinationLat,
        destinationLng: clearDestinationCoords ? null : destinationLng ?? this.destinationLng,
        description: description ?? this.description,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        coverStoragePath: coverStoragePath ?? this.coverStoragePath,
        currency: currency,
        budgetCents: budgetCents ?? this.budgetCents,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
