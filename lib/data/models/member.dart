import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/initials.dart';
import 'app_user.dart';

/// Participante de uma viagem. O id **é o uid** da conta, o que liga
/// o membro ao usuário autenticado sem tabela de-para.
class Member {
  const Member({
    required this.id,
    required this.name,
    required this.email,
    this.colorValue,
    this.isAdmin = false,
    this.pixKey,
    this.order = 0,
    this.joinedAt,
  });

  final String id;
  final String name;
  final String email;
  final int? colorValue;

  /// Quem criou a viagem. Só o admin gerencia quem entra e sai.
  final bool isAdmin;

  /// Chave PIX — aparece na hora de pagar uma cota para essa pessoa.
  final String? pixKey;

  final int order;
  final DateTime? joinedAt;

  static const palette = [
    AppColors.coral,
    AppColors.turquoise,
    AppColors.sunset,
    AppColors.grape,
    AppColors.sky,
    AppColors.palm,
  ];

  Color get color =>
      colorValue != null ? Color(colorValue!) : palette[order % palette.length];

  String get shortName => name.trim().split(RegExp(r'\s+')).first;

  /// O que o avatar mostra.
  String get initials => initialsOf(name);

  /// Cria o membro a partir de uma conta existente.
  factory Member.fromUser(AppUser user, {required int order, bool isAdmin = false}) => Member(
        id: user.uid,
        name: user.displayName.isEmpty ? AppUser.nameFromEmail(user.email) : user.displayName,
        email: user.email,
        isAdmin: isAdmin,
        order: order,
      );

  factory Member.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Member(
      id: doc.id,
      name: d['name'] as String? ?? 'Sem nome',
      email: d['email'] as String? ?? '',
      colorValue: (d['colorValue'] as num?)?.toInt(),
      isAdmin: d['isAdmin'] as bool? ?? false,
      pixKey: d['pixKey'] as String?,
      order: (d['order'] as num?)?.toInt() ?? 0,
      joinedAt: (d['joinedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': AppUser.normalizeEmail(email),
        'colorValue': colorValue,
        'isAdmin': isAdmin,
        'pixKey': pixKey,
        'order': order,
        'joinedAt': joinedAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(joinedAt!),
      };

  Member copyWith({
    String? name,
    int? colorValue,
    bool? isAdmin,
    String? pixKey,
    int? order,
  }) =>
      Member(
        id: id,
        name: name ?? this.name,
        email: email,
        colorValue: colorValue ?? this.colorValue,
        isAdmin: isAdmin ?? this.isAdmin,
        pixKey: pixKey ?? this.pixKey,
        order: order ?? this.order,
        joinedAt: joinedAt,
      );
}
