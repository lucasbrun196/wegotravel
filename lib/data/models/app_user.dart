import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/initials.dart';

/// Perfil público de uma conta, em `users/{uid}`.
///
/// Existe por um motivo prático: o SDK cliente do Firebase Auth não
/// permite procurar alguém por e-mail. Sem este espelho, o admin não
/// conseguiria convidar um amigo digitando o e-mail dele.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.createdAt,
    this.lastSeenAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;

  String get shortName => displayName.trim().split(RegExp(r'\s+')).first;

  /// O que o avatar mostra.
  String get initials => initialsOf(displayName.isEmpty ? nameFromEmail(email) : displayName);

  /// E-mails são comparados sempre em minúsculas, para "Joao@x.com" e
  /// "joao@x.com" acharem a mesma pessoa.
  static String normalizeEmail(String email) => email.trim().toLowerCase();

  /// Nome de exibição razoável quando a pessoa não informou nenhum.
  static String nameFromEmail(String email) {
    final local = email.split('@').first;
    final cleaned = local.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (cleaned.isEmpty) return email;
    return cleaned
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      email: d['email'] as String? ?? '',
      displayName: d['displayName'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      lastSeenAt: (d['lastSeenAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': normalizeEmail(email),
        'displayName': displayName,
        'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
        'lastSeenAt': FieldValue.serverTimestamp(),
      };

  AppUser copyWith({String? displayName}) => AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        createdAt: createdAt,
        lastSeenAt: lastSeenAt,
      );
}
