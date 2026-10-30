import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Como a conta se comporta ao longo da viagem.
enum BillType {
  /// Valor total conhecido desde o início (aluguel, ingresso, reserva).
  /// Pode ser parcelada.
  fixed(
    label: 'Conta fechada',
    description: 'O valor total já é conhecido. Pode ser parcelada.',
    icon: Icons.receipt_long_rounded,
  ),

  /// Valor cresce durante a viagem e só fecha no final
  /// (gasolina, mercado, pedágios). Divide-se no acerto.
  accumulating(
    label: 'Conta aberta',
    description: 'Vai somando lançamentos e fecha no final da viagem.',
    icon: Icons.add_chart_rounded,
  );

  const BillType({required this.label, required this.description, required this.icon});

  final String label;
  final String description;
  final IconData icon;
}

enum BillStatus {
  open(label: 'Em aberto', color: AppColors.sunset),
  settled(label: 'Quitada', color: AppColors.success);

  const BillStatus({required this.label, required this.color});

  final String label;
  final Color color;
}

/// Categoria da conta — usada para agrupar, colorir e dar ícone.
enum BillCategory {
  lodging(label: 'Hospedagem', icon: Icons.hotel_rounded, color: AppColors.plum),
  fuel(label: 'Gasolina', icon: Icons.local_gas_station_rounded, color: AppColors.sunset),
  food(label: 'Alimentação', icon: Icons.restaurant_rounded, color: AppColors.coral),
  breakfast(label: 'Café', icon: Icons.free_breakfast_rounded, color: AppColors.sunset),
  lunch(label: 'Almoço', icon: Icons.lunch_dining_rounded, color: AppColors.coral),
  groceries(label: 'Mercado', icon: Icons.local_grocery_store_rounded, color: AppColors.palm),
  tours(label: 'Passeios', icon: Icons.kayaking_rounded, color: AppColors.turquoise),
  tolls(label: 'Pedágios', icon: Icons.toll_rounded, color: AppColors.sky),
  shopping(label: 'Compras', icon: Icons.shopping_bag_rounded, color: AppColors.palm),
  transport(label: 'Transporte', icon: Icons.directions_car_rounded, color: AppColors.deepSea),
  tickets(label: 'Ingressos', icon: Icons.confirmation_number_rounded, color: AppColors.coral),
  other(label: 'Outros', icon: Icons.category_rounded, color: AppColors.inkMuted);

  const BillCategory({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  static BillCategory fromId(String? id) =>
      values.firstWhere((c) => c.name == id, orElse: () => BillCategory.other);
}

/// Como o valor é repartido entre os participantes.
enum SplitMode {
  equal(label: 'Igualmente'),
  custom(label: 'Valores personalizados');

  const SplitMode({required this.label});

  final String label;
}
