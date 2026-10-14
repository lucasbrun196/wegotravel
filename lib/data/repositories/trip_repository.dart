import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/member.dart';
import '../models/trip.dart';
import '../services/firestore_refs.dart';

/// Motivo pelo qual não foi possível adicionar alguém à viagem.
enum AddMemberResult { added, notRegistered, alreadyMember }

class TripRepository {
  TripRepository(this._refs);

  final FirestoreRefs _refs;

  // ---------------------------------------------------------------
  // Viagens
  // ---------------------------------------------------------------

  /// As viagens da pessoa, da mais recente para a mais antiga.
  Stream<List<Trip>> watchMyTrips(String uid) => _refs
      .tripsOf(uid)
      .snapshots()
      .map((snap) => snap.docs.map(Trip.fromDoc).toList()
        ..sort((a, b) {
          // Viagens com data primeiro, ordenadas pela partida.
          final ad = a.startDate, bd = b.startDate;
          if (ad != null && bd != null) return bd.compareTo(ad);
          if (ad != null) return -1;
          if (bd != null) return 1;
          return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
        }));

  /// As viagens da pessoa em uma leitura só.
  ///
  /// A tela de conta precisa da lista fora do escopo de uma viagem e sem
  /// depender de o stream já estar quente.
  Future<List<Trip>> myTripsOnce(String uid) async {
    final snap = await _refs.tripsOf(uid).get();
    return snap.docs.map(Trip.fromDoc).toList();
  }

  Stream<Trip?> watchTrip(String tripId) => _refs
      .trip(tripId)
      .snapshots()
      .map((doc) => doc.exists ? Trip.fromDoc(doc) : null);

  Future<Trip?> getTrip(String tripId) async {
    final doc = await _refs.trip(tripId).get();
    return doc.exists ? Trip.fromDoc(doc) : null;
  }

  /// Cria a viagem já com quem criou como admin e primeiro participante.
  ///
  /// Documento e membro nascem no mesmo lote: nunca existe uma viagem
  /// sem dono, nem que fique invisível para quem acabou de criá-la.
  Future<String> createTrip({
    required AppUser creator,
    required String name,
    String destination = '',
    DateTime? startDate,
    DateTime? endDate,
    int? budgetCents,
  }) async {
    final ref = _refs.trips.doc();

    final trip = Trip(
      id: ref.id,
      name: name.trim(),
      adminId: creator.uid,
      memberIds: [creator.uid],
      destination: destination.trim(),
      startDate: startDate,
      endDate: endDate,
      budgetCents: budgetCents,
    );

    final batch = _refs.db.batch();
    batch.set(ref, trip.toMap());
    batch.set(
      _refs.members(ref.id).doc(creator.uid),
      Member.fromUser(creator, order: 0, isAdmin: true).toMap(),
    );
    await batch.commit();

    return ref.id;
  }

  Future<void> updateTrip(Trip trip) =>
      _refs.trip(trip.id).set(trip.toMap(), SetOptions(merge: true));

  /// Apaga a viagem e tudo que vive sob ela. Só o admin consegue.
  Future<void> deleteTrip(String tripId) async {
    for (final collection in ['members', 'itinerary', 'posts']) {
      final snap = await _refs.trip(tripId).collection(collection).get();
      final batch = _refs.db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    final bills = await _refs.bills(tripId).get();
    for (final bill in bills.docs) {
      for (final sub in ['entries', 'shares']) {
        final snap = await bill.reference.collection(sub).get();
        final batch = _refs.db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      await bill.reference.delete();
    }

    await _refs.trip(tripId).delete();
  }

  // ---------------------------------------------------------------
  // Participantes
  // ---------------------------------------------------------------

  Stream<List<Member>> watchMembers(String tripId) => _refs
      .members(tripId)
      .snapshots()
      .map((snap) => snap.docs.map(Member.fromDoc).toList()
        ..sort((a, b) => a.order.compareTo(b.order)));

  /// Adiciona alguém à viagem pelo e-mail.
  ///
  /// A pessoa precisa já ter conta: sem Cloud Functions não há como
  /// convidar quem ainda não se cadastrou, e criar conta pelos outros
  /// significaria escolher a senha deles.
  Future<AddMemberResult> addMemberByEmail({
    required String tripId,
    required AppUser user,
    required int order,
  }) async {
    final tripRef = _refs.trip(tripId);
    final memberRef = _refs.members(tripId).doc(user.uid);

    if ((await memberRef.get()).exists) return AddMemberResult.alreadyMember;

    final batch = _refs.db.batch();
    batch.set(memberRef, Member.fromUser(user, order: order).toMap());
    batch.update(tripRef, {
      'memberIds': FieldValue.arrayUnion([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return AddMemberResult.added;
  }

  /// Remove alguém da viagem. O admin não pode ser removido — a viagem
  /// ficaria sem quem gerencia os participantes.
  Future<void> removeMember(String tripId, String memberId) async {
    final batch = _refs.db.batch();
    batch.delete(_refs.members(tripId).doc(memberId));
    batch.update(_refs.trip(tripId), {
      'memberIds': FieldValue.arrayRemove([memberId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> updateMember(String tripId, Member member) =>
      _refs.members(tripId).doc(member.id).set(member.toMap(), SetOptions(merge: true));

  /// Copia o nome do perfil para o membro em todas as viagens.
  ///
  /// O nome é denormalizado em cada `members/{uid}` — é o que
  /// deixa a lista de participantes ler sem buscar conta por conta. Sem
  /// esta cópia, mudar o perfil não apareceria em viagem nenhuma.
  /// `set` com merge, e não `update`: uma viagem sem o documento de
  /// membro não derruba o lote inteiro.
  Future<void> syncMemberProfile({
    required String uid,
    required String name,
  }) async {
    final snap = await _refs.tripsOf(uid).get();
    if (snap.docs.isEmpty) return;

    final batch = _refs.db.batch();
    for (final doc in snap.docs) {
      batch.set(
        _refs.members(doc.id).doc(uid),
        {'name': name},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }
}
