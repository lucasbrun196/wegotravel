import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// O que é a parada no roteiro.
enum ItineraryCategory {
  sightseeing(label: 'Ponto turístico', icon: Icons.photo_camera_rounded, color: AppColors.turquoise),
  breakfast(label: 'Café', icon: Icons.free_breakfast_rounded, color: AppColors.sunset),
  lunch(label: 'Almoço', icon: Icons.lunch_dining_rounded, color: AppColors.coral),
  dinner(label: 'Jantar', icon: Icons.dinner_dining_rounded, color: AppColors.plum),
  food(label: 'Restaurante', icon: Icons.restaurant_rounded, color: AppColors.coral),
  beach(label: 'Praia', icon: Icons.beach_access_rounded, color: AppColors.sunset),
  trail(label: 'Trilha', icon: Icons.hiking_rounded, color: AppColors.palm),
  tour(label: 'Passeio', icon: Icons.kayaking_rounded, color: AppColors.sky),
  event(label: 'Evento', icon: Icons.celebration_rounded, color: AppColors.plum),
  lodging(label: 'Hospedagem', icon: Icons.hotel_rounded, color: AppColors.deepSea),
  shopping(label: 'Compras', icon: Icons.shopping_bag_rounded, color: AppColors.palm),
  travel(label: 'Deslocamento', icon: Icons.swap_calls_rounded, color: AppColors.inkMuted),
  other(label: 'Outro', icon: Icons.place_rounded, color: AppColors.inkMuted);

  const ItineraryCategory({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  static ItineraryCategory fromId(String? id) =>
      values.firstWhere((c) => c.name == id, orElse: () => ItineraryCategory.other);
}

/// Como a turma chega até lá.
enum TransportMode {
  walking(label: 'A pé', icon: Icons.directions_walk_rounded),
  car(label: 'Carro', icon: Icons.directions_car_rounded),
  rideApp(label: 'App de carona', icon: Icons.local_taxi_rounded),
  bus(label: 'Ônibus', icon: Icons.directions_bus_rounded),
  train(label: 'Trem', icon: Icons.train_rounded),
  subway(label: 'Metrô', icon: Icons.subway_rounded),
  plane(label: 'Avião', icon: Icons.flight_rounded),
  boat(label: 'Barco', icon: Icons.directions_boat_rounded),
  other(label: 'Outro', icon: Icons.alt_route_rounded);

  const TransportMode({required this.label, required this.icon});

  final String label;
  final IconData icon;

  static TransportMode? fromId(String? id) {
    if (id == null) return null;
    for (final mode in values) {
      if (mode.name == id) return mode;
    }
    return null;
  }
}

/// Situação da atividade durante a viagem.
enum ItineraryStatus {
  planned(label: 'Planejado', color: AppColors.inkFaint),
  done(label: 'Feito', color: AppColors.success),
  cancelled(label: 'Cancelado', color: AppColors.danger);

  const ItineraryStatus({required this.label, required this.color});

  final String label;
  final Color color;

  static ItineraryStatus fromId(String? id) =>
      values.firstWhere((s) => s.name == id, orElse: () => ItineraryStatus.planned);
}
