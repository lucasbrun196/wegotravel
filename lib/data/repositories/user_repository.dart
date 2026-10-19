import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../models/app_user.dart';
import '../services/firestore_refs.dart';
import '../services/sync_status_service.dart';

class UserRepository {
  UserRepository(this._refs);

  final FirestoreRefs _refs;

  /// Fila das escritas no perfil, na ordem em que foram pedidas.
  ///
  /// No cadastro, `syncFromAuth` dispara sozinho assim que a conta nasce —
  /// antes de o Auth ter o nome — e corre em paralelo com o
  /// `updateProfile` do nome escolhido. Sem a fila, a escrita do sync
  /// podia chegar por último e deixar o nome tirado do e-mail. Cada passo
  /// só espera a escrita anterior ser *emitida*, não confirmada pelo
  /// servidor: offline a confirmação não vem, e a fila travaria.
  Future<void> _queue = Future.value();

  Future<T> _inOrder<T>(Future<T> Function() step) {
    final result = _queue.then((_) => step());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Espelha a conta do Auth em `users/{uid}`.
  ///
  /// Chamado a cada login: mantém o e-mail atualizado e é o que torna
  /// possível convidar alguém digitando o e-mail.
  Future<AppUser> syncFromAuth(fb.User user) async {
    // A escrita volta dentro de um registro para o `async` não esperá-la
    // ainda dentro da fila.
    final (appUser, write) = await _inOrder(() async {
      final email = AppUser.normalizeEmail(user.email ?? '');
      final ref = _refs.user(user.uid);
      final existing = await ref.get();

      final displayName = (user.displayName?.trim().isNotEmpty ?? false)
          ? user.displayName!.trim()
          : (existing.data()?['displayName'] as String?) ?? AppUser.nameFromEmail(email);

      final appUser = AppUser(
        uid: user.uid,
        email: email,
        displayName: displayName,
        createdAt: (existing.data()?['createdAt'] as Timestamp?)?.toDate(),
      );

      return (appUser, ref.set(appUser.toMap(), SetOptions(merge: true)));
    });

    await write;
    return appUser;
  }

  Stream<AppUser?> watchUser(String uid) =>
      _refs.user(uid).snapshots().map((doc) => doc.exists ? AppUser.fromDoc(doc) : null);

  /// De onde vem o dado e se há escrita na fila, para o app saber se
  /// está offline.
  ///
  /// O documento do próprio usuário serve de sonda porque existe desde
  /// o login e não depende de viagem aberta. `includeMetadataChanges`
  /// é o que faz o Firestore avisar quando só o metadado muda — sem
  /// ele, o snapshot do cache seria o último até o dado mudar.
  Stream<SyncMetadata> watchSyncMetadata(String uid) =>
      _refs.user(uid).snapshots(includeMetadataChanges: true).map(
            (doc) => SyncMetadata(
              isFromCache: doc.metadata.isFromCache,
              hasPendingWrites: doc.metadata.hasPendingWrites,
            ),
          );

  /// Procura uma conta pelo e-mail.
  ///
  /// Devolve `null` quando ninguém com aquele e-mail criou conta ainda —
  /// é assim que o app avisa "essa pessoa ainda não tem cadastro".
  Future<AppUser?> findByEmail(String email) async {
    final normalized = AppUser.normalizeEmail(email);
    if (normalized.isEmpty) return null;

    final snap = await _refs.users
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();

    return snap.docs.isEmpty ? null : AppUser.fromDoc(snap.docs.first);
  }

  Future<void> updateProfile(String uid, {String? displayName}) async {
    final (write,) = await _inOrder(() async => (
          _refs.user(uid).set({
            'displayName': ?displayName,
          }, SetOptions(merge: true)),
        ));
    await write;
  }

  /// Apaga o espelho da conta, na exclusão do cadastro.
  Future<void> deleteUser(String uid) => _refs.user(uid).delete();
}
