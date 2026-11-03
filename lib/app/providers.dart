import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart' show ThemeMode, Brightness;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_user.dart';
import '../data/models/bill.dart';
import '../data/models/board_post.dart';
import '../data/models/bill_entry.dart';
import '../data/models/bill_share.dart';
import '../data/models/itinerary_enums.dart';
import '../data/models/member.dart';
import '../data/models/trip.dart';
import '../data/models/itinerary_item.dart';
import '../data/models/weather.dart';
import '../data/repositories/bill_repository.dart';
import '../data/repositories/board_repository.dart';
import '../data/repositories/itinerary_repository.dart';
import '../data/repositories/trip_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/services/auth_service.dart';
import '../data/services/firestore_refs.dart';
import '../data/services/geocoding_service.dart';
import '../data/services/local_prefs_service.dart';
import '../data/services/storage_service.dart';
import '../data/services/sync_status_service.dart';
import '../data/services/weather_service.dart';

// ---------------------------------------------------------------
// Infraestrutura
// ---------------------------------------------------------------

final firestoreProvider = Provider((ref) => FirebaseFirestore.instance);
final storageProvider = Provider((ref) => FirebaseStorage.instance);
final firebaseAuthProvider = Provider((ref) => FirebaseAuth.instance);

final refsProvider = Provider((ref) => FirestoreRefs(ref.watch(firestoreProvider)));

final storageServiceProvider =
    Provider((ref) => StorageService(ref.watch(storageProvider)));

final authServiceProvider =
    Provider((ref) => AuthService(ref.watch(firebaseAuthProvider)));

/// Nome do lugar a partir da coordenada (e vice-versa). Não depende da
/// viagem, então não precisa declarar `dependencies`.
final geocodingServiceProvider = Provider((ref) => GeocodingService());

/// Previsão do tempo pela coordenada. Também não depende da viagem — o
/// cache dele vive na sessão inteira, de propósito.
final weatherServiceProvider = Provider((ref) => WeatherService());

/// Traduz o metadado dos snapshots em "online / pendente / offline".
final syncStatusServiceProvider = Provider((ref) => const SyncStatusService());

/// Injetado no `main` depois de carregar as preferências.
final prefsProvider = Provider<LocalPrefsService>(
  (ref) => throw UnimplementedError('prefsProvider deve ser sobrescrito no main'),
);

/// Claro, escuro ou o do sistema. Começa no que ficou salvo no aparelho
/// e grava cada troca — a escolha é de quem usa o aparelho, não da conta.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = ref.watch(prefsProvider).themeMode;
    return ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(prefsProvider).setThemeMode(mode.name);
  }

  /// O botão sol/lua: alterna entre claro e escuro a partir do que está
  /// **na tela**, inclusive quando o modo é o do sistema.
  void toggle(Brightness current) =>
      set(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
}

// ---------------------------------------------------------------
// Repositórios
// ---------------------------------------------------------------

final userRepositoryProvider =
    Provider((ref) => UserRepository(ref.watch(refsProvider)));

final tripRepositoryProvider = Provider(
  (ref) => TripRepository(ref.watch(refsProvider), ref.watch(storageServiceProvider)),
);

final billRepositoryProvider = Provider(
  (ref) => BillRepository(ref.watch(refsProvider), ref.watch(storageServiceProvider)),
);

final itineraryRepositoryProvider =
    Provider((ref) => ItineraryRepository(ref.watch(refsProvider)));

final boardRepositoryProvider = Provider(
  (ref) => BoardRepository(ref.watch(refsProvider), ref.watch(storageServiceProvider)),
);

// ---------------------------------------------------------------
// Sessão
// ---------------------------------------------------------------

/// A fonte da verdade sobre quem está logado.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.uid,
);

final isSignedInProvider = Provider<bool>((ref) => ref.watch(currentUidProvider) != null);

/// Perfil da pessoa logada, vindo de `users/{uid}`.
///
/// O espelho é garantido aqui, e não na tela de login: assim ele também
/// é criado (e o e-mail atualizado) quando a sessão volta salva do disco,
/// sem depender de a pessoa passar pelo formulário de novo.
final currentUserProvider = StreamProvider<AppUser?>((ref) async* {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  if (authUser == null) {
    yield null;
    return;
  }

  final repo = ref.watch(userRepositoryProvider);
  yield await repo.syncFromAuth(authUser);
  yield* repo.watchUser(authUser.uid);
});

/// Como está a sincronização com o servidor.
///
/// Fica sem valor enquanto ninguém está logado — não há documento para
/// sondar, e fora da sessão o aviso não teria o que dizer.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();

  return ref.watch(syncStatusServiceProvider).watch(
        ref.watch(userRepositoryProvider).watchSyncMetadata(uid),
      );
});

// ---------------------------------------------------------------
// Viagens
// ---------------------------------------------------------------

final myTripsProvider = StreamProvider<List<Trip>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(tripRepositoryProvider).watchMyTrips(uid);
});

/// Id da viagem aberta.
///
/// Sobrescrito por um `ProviderScope` dentro da casca da viagem, de
/// modo que toda tela ali dentro lê a viagem certa sem receber o id
/// por parâmetro. Todo provider que o consome precisa declará-lo em
/// `dependencies` — é assim que o Riverpod sabe recriá-los dentro do
/// escopo em vez de ler a instância da raiz.
final currentTripIdProvider = Provider<String>(
  (ref) => throw UnimplementedError('currentTripIdProvider precisa de um escopo de viagem'),
);

final tripProvider = StreamProvider<Trip?>(
  (ref) => ref.watch(tripRepositoryProvider).watchTrip(ref.watch(currentTripIdProvider)),
  dependencies: [currentTripIdProvider],
);

final membersProvider = StreamProvider<List<Member>>(
  (ref) => ref.watch(tripRepositoryProvider).watchMembers(ref.watch(currentTripIdProvider)),
  dependencies: [currentTripIdProvider],
);

/// Mapa id → membro, para as telas resolverem nomes sem varrer a lista.
final membersByIdProvider = Provider<Map<String, Member>>(
  (ref) {
    final members = ref.watch(membersProvider).valueOrNull ?? const <Member>[];
    return {for (final m in members) m.id: m};
  },
  dependencies: [membersProvider],
);

/// O membro correspondente a quem está logado, dentro desta viagem.
final currentMemberProvider = Provider<Member?>(
  (ref) {
    final uid = ref.watch(currentUidProvider);
    return uid == null ? null : ref.watch(membersByIdProvider)[uid];
  },
  dependencies: [membersByIdProvider],
);

final isTripAdminProvider = Provider<bool>(
  (ref) {
    final trip = ref.watch(tripProvider).valueOrNull;
    return trip?.isAdmin(ref.watch(currentUidProvider)) ?? false;
  },
  dependencies: [tripProvider],
);

// ---------------------------------------------------------------
// Contas
// ---------------------------------------------------------------

final billsProvider = StreamProvider<List<Bill>>(
  (ref) => ref.watch(billRepositoryProvider).watchBills(ref.watch(currentTripIdProvider)),
  dependencies: [currentTripIdProvider],
);

final billProvider = StreamProvider.family<Bill?, String>(
  (ref, billId) => ref
      .watch(billRepositoryProvider)
      .watchBill(ref.watch(currentTripIdProvider), billId),
  dependencies: [currentTripIdProvider],
);

final billEntriesProvider = StreamProvider.family<List<BillEntry>, String>(
  (ref, billId) => ref
      .watch(billRepositoryProvider)
      .watchEntries(ref.watch(currentTripIdProvider), billId),
  dependencies: [currentTripIdProvider],
);

// ---------------------------------------------------------------
// Roteiro
// ---------------------------------------------------------------

final itineraryProvider = StreamProvider<List<ItineraryItem>>(
  (ref) => ref
      .watch(itineraryRepositoryProvider)
      .watchItinerary(ref.watch(currentTripIdProvider)),
  dependencies: [currentTripIdProvider],
);

/// O roteiro agrupado por dia, na ordem cronológica.
final itineraryDaysProvider = Provider<List<ItineraryDay>>(
  (ref) {
    final items = ref.watch(itineraryProvider).valueOrNull ?? const <ItineraryItem>[];
    final byDay = <String, List<ItineraryItem>>{};
    for (final item in items) {
      byDay.putIfAbsent(item.dayKey, () => []).add(item);
    }

    final days = byDay.values
        .map((list) => ItineraryDay(date: list.first.date, items: list))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return days;
  },
  dependencies: [itineraryProvider],
);

/// A próxima atividade que ainda vai acontecer — o que o painel mostra.
final nextItineraryItemProvider = Provider<ItineraryItem?>(
  (ref) {
    final items = ref.watch(itineraryProvider).valueOrNull ?? const <ItineraryItem>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final item in items) {
      if (item.status == ItineraryStatus.done ||
          item.status == ItineraryStatus.cancelled) {
        continue;
      }
      final when = item.startAt ?? item.date;
      if (item.date.isBefore(today)) continue;
      if (item.startAt != null && when.isBefore(now)) continue;
      return item;
    }
    return null;
  },
  dependencies: [itineraryProvider],
);

final billSharesProvider = StreamProvider.family<List<BillShare>, String>(
  (ref, billId) => ref
      .watch(billRepositoryProvider)
      .watchShares(ref.watch(currentTripIdProvider), billId),
  dependencies: [currentTripIdProvider],
);

// ---------------------------------------------------------------
// Previsão do tempo
// ---------------------------------------------------------------

/// A previsão já vale a pena? Ver `Weather.isWindowOpen`.
///
/// Lê a viagem, então **precisa** declarar `dependencies` — sem isso o
/// Riverpod tenta ler o `tripProvider` da raiz, fora do escopo da viagem.
final weatherWindowOpenProvider = Provider<bool>(
  (ref) => Weather.isWindowOpen(ref.watch(tripProvider).valueOrNull, DateTime.now()),
  dependencies: [tripProvider],
);

/// Previsão de um ponto do mapa, por dia.
///
/// A `WeatherQuery` já chega com a coordenada arredondada, e é a
/// igualdade dela que faz o roteiro inteiro de um destino compartilhar
/// uma instância só. Não toca na viagem — logo, sem `dependencies`.
final dailyForecastProvider =
    FutureProvider.family<Map<String, DailyWeather>, WeatherQuery>(
  (ref, query) => ref.watch(weatherServiceProvider).dailyForecast(query),
);

// ---------------------------------------------------------------
// Mural
// ---------------------------------------------------------------

/// As fotos e os vídeos da viagem, do mais recente para o mais antigo.
final boardPostsProvider = StreamProvider<List<BoardPost>>(
  (ref) => ref.watch(boardRepositoryProvider).watchPosts(ref.watch(currentTripIdProvider)),
  dependencies: [currentTripIdProvider],
);

/// Link de download de um arquivo do Storage, pedido na hora.
///
/// É aqui que a regra "só quem participa da viagem vê o mural" vale para
/// os arquivos: o Storage só devolve o link depois de conferir a pessoa no
/// documento da viagem. O link não é guardado no post (ver `BoardPost`) e
/// vive só nesta sessão — um arquivo é pedido uma vez, e trocar de conta
/// descarta tudo.
///
/// Não lê a viagem (o caminho já a contém), então não declara
/// `dependencies`: o cache é um só para o app inteiro.
final mediaUrlProvider = FutureProvider.family<String, String>((ref, path) {
  ref.watch(currentUidProvider);
  return ref.watch(storageServiceProvider).downloadUrl(path);
});
