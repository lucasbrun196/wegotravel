import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/board_post.dart';
import '../../../data/models/itinerary_item.dart';

enum BoardKindFilter {
  all('Tudo'),
  photos('Fotos'),
  videos('Vídeos');

  const BoardKindFilter(this.label);
  final String label;

  bool accepts(BoardPost post) => switch (this) {
        all => true,
        photos => post.isPhoto,
        videos => post.isVideo,
      };
}

/// O que o mural está mostrando.
class BoardFilter {
  const BoardFilter({this.kind = BoardKindFilter.all, this.authorId, this.newestFirst = true});

  final BoardKindFilter kind;

  /// Só os posts desta pessoa; nulo é de todo mundo.
  final String? authorId;

  /// Os dias mais recentes primeiro. Durante a viagem é o que se quer ver;
  /// depois dela, rever do começo conta a história na ordem.
  final bool newestFirst;

  bool accepts(BoardPost post) =>
      kind.accepts(post) && (authorId == null || post.authorId == authorId);

  BoardFilter copyWith({BoardKindFilter? kind, String? authorId, bool clearAuthor = false, bool? newestFirst}) =>
      BoardFilter(
        kind: kind ?? this.kind,
        authorId: clearAuthor ? null : authorId ?? this.authorId,
        newestFirst: newestFirst ?? this.newestFirst,
      );
}

/// O filtro do mural. Vive no escopo da viagem: sobrevive à troca de aba,
/// e cada viagem tem o seu.
final boardFilterProvider = StateProvider<BoardFilter>(
  (ref) {
    ref.watch(currentTripIdProvider);
    return const BoardFilter();
  },
  dependencies: [currentTripIdProvider],
);

/// Um dia do mural.
class BoardDay {
  const BoardDay({required this.date, required this.posts, this.tripDay, this.places = const []});

  final DateTime date;
  final List<BoardPost> posts;

  /// "Dia 3" da viagem, quando a data cai dentro dela.
  final int? tripDay;

  /// Os lugares do roteiro naquele dia: dizem de onde as fotos devem ser.
  final List<String> places;

  String get dayKey => Fmt.dayKey(date);
  int get photoCount => posts.where((p) => p.isPhoto).length;
  int get videoCount => posts.where((p) => p.isVideo).length;
}

/// O mural já filtrado, dividido por dia. É também a ordem em que o
/// visualizador passa as fotos.
final boardDaysProvider = Provider<List<BoardDay>>(
  (ref) {
    final posts = ref.watch(boardPostsProvider).valueOrNull ?? const <BoardPost>[];
    final filter = ref.watch(boardFilterProvider);
    final trip = ref.watch(tripProvider).valueOrNull;
    final itinerary = ref.watch(itineraryProvider).valueOrNull ?? const <ItineraryItem>[];

    final placesByDay = <String, List<String>>{};
    for (final item in itinerary) {
      final place = item.placeName?.trim();
      if (place == null || place.isEmpty) continue;
      final list = placesByDay.putIfAbsent(item.dayKey, () => []);
      if (!list.contains(place)) list.add(place);
    }

    return groupBoardDays(
      posts.where(filter.accepts),
      newestFirst: filter.newestFirst,
      tripStart: trip?.startDate,
      tripEnd: trip?.endDate,
      placesByDay: placesByDay,
    );
  },
  dependencies: [boardPostsProvider, boardFilterProvider, tripProvider, itineraryProvider],
);

/// Separa os posts por dia. [posts] chega do mais recente para o mais
/// antigo; com [newestFirst] falso, tudo se inverte, dias e fotos.
List<BoardDay> groupBoardDays(
  Iterable<BoardPost> posts, {
  bool newestFirst = true,
  DateTime? tripStart,
  DateTime? tripEnd,
  Map<String, List<String>> placesByDay = const {},
}) {
  final ordered = newestFirst ? posts.toList() : posts.toList().reversed.toList();
  final byDay = <String, List<BoardPost>>{};
  for (final post in ordered) {
    byDay.putIfAbsent(post.dayKey, () => []).add(post);
  }

  final start = tripStart?.dateOnly;
  final end = tripEnd?.dateOnly;

  int? tripDayOf(DateTime date) {
    if (start == null || end == null || date.isBefore(start) || date.isAfter(end)) return null;
    // Em horas e arredondado: num dia de horário de verão a diferença tem
    // 23 ou 25 horas, e `inDays` erraria por um.
    return (date.difference(start).inHours / 24).round() + 1;
  }

  return [
    for (final list in byDay.values)
      BoardDay(
        date: list.first.takenAt.dateOnly,
        posts: list,
        tripDay: tripDayOf(list.first.takenAt.dateOnly),
        places: placesByDay[list.first.dayKey] ?? const [],
      ),
  ];
}

/// Quantos posts há de cada pessoa, para os chips de filtro.
final boardAuthorsProvider = Provider<Map<String, int>>(
  (ref) {
    final posts = ref.watch(boardPostsProvider).valueOrNull ?? const <BoardPost>[];
    final counts = <String, int>{};
    for (final post in posts) {
      counts.update(post.authorId, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  },
  dependencies: [boardPostsProvider],
);

/// "12 fotos e 3 vídeos", "1 foto", "2 vídeos".
String mediaCountLabel(int photos, int videos) {
  final parts = [
    if (photos > 0) '$photos ${photos == 1 ? 'foto' : 'fotos'}',
    if (videos > 0) '$videos ${videos == 1 ? 'vídeo' : 'vídeos'}',
  ];
  return parts.isEmpty ? 'nada' : parts.join(' e ');
}

/// "postada", "salvos", "excluídas": o particípio concorda com o que foi
/// feito. Com vídeo no meio, o plural vai para o masculino.
String agreeing(String stem, int photos, int videos) {
  final masculine = videos > 0;
  final plural = photos + videos > 1;
  return '$stem${masculine ? 'o' : 'a'}${plural ? 's' : ''}';
}

/// O aviso do que acabou de acontecer: "Foto postada", "Vídeo salvo",
/// "3 fotos e 1 vídeo excluídos". Com um só, sem o número na frente.
String doneLabel(String stem, int photos, int videos) {
  final what = photos + videos == 1
      ? (videos == 1 ? 'Vídeo' : 'Foto')
      : capitalized(mediaCountLabel(photos, videos));
  return '$what ${agreeing(stem, photos, videos)}';
}

String capitalized(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
