import 'package:cloud_firestore/cloud_firestore.dart';

typedef JsonDoc = DocumentReference<Map<String, dynamic>>;
typedef JsonCollection = CollectionReference<Map<String, dynamic>>;

/// Caminhos do Firestore em um lugar só.
///
/// Tudo vive sob `trips/{tripId}`, o que mantém as regras de segurança
/// simples e permite isolar (ou apagar) uma viagem inteira.
class FirestoreRefs {
  FirestoreRefs(this.db);

  final FirebaseFirestore db;

  /// Espelho das contas do Firebase Auth. Ver [UserRepository].
  JsonCollection get users => db.collection('users');

  JsonDoc user(String uid) => users.doc(uid);

  JsonCollection get trips => db.collection('trips');

  /// As viagens em que a pessoa participa.
  Query<Map<String, dynamic>> tripsOf(String uid) =>
      trips.where('memberIds', arrayContains: uid);

  JsonDoc trip(String tripId) => trips.doc(tripId);

  JsonCollection members(String tripId) => trip(tripId).collection('members');

  JsonCollection itinerary(String tripId) => trip(tripId).collection('itinerary');

  JsonCollection bills(String tripId) => trip(tripId).collection('bills');

  JsonDoc bill(String tripId, String billId) => bills(tripId).doc(billId);

  JsonCollection entries(String tripId, String billId) =>
      bill(tripId, billId).collection('entries');

  JsonCollection shares(String tripId, String billId) =>
      bill(tripId, billId).collection('shares');

  /// O mural: um documento por foto ou vídeo. Ver `BoardPost`.
  JsonCollection posts(String tripId) => trip(tripId).collection('posts');

  JsonDoc post(String tripId, String postId) => posts(tripId).doc(postId);

  /// Todas as cotas de uma viagem, em uma consulta só — é o que
  /// alimenta os totais e "minhas pendências" sem varrer conta por conta.
  /// O filtro por `tripId` é obrigatório: sem ele a consulta atravessaria
  /// as viagens de outras pessoas, e as regras a rejeitariam.
  Query<Map<String, dynamic>> sharesOfTrip(String tripId) =>
      db.collectionGroup('shares').where('tripId', isEqualTo: tripId);
}
