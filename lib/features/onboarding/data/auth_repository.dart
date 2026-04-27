import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/user_model.dart';

class AuthRepository {
  const AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<String> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    return credential.user!.uid;
  }

  Future<String> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!.uid;
  }

  Future<String> registerWithEmail(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!.uid;
  }

  Future<void> saveUser(UserModel user) async {
    await _firestore.collection('users').doc(user.id).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return UserModel.fromMap(uid, snapshot.data()!);
  }

  Stream<UserModel?> streamUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserModel.fromMap(uid, snapshot.data()!);
    });
  }

  Future<void> ensureCompanionUserDoc(String uid) async {
    final docRef = _firestore.collection('users').doc(uid);
    final snapshot = await docRef.get();
    if (snapshot.exists && snapshot.data() != null) return;
    final user = UserModel(
      id: uid,
      role: UserRole.companion,
      autonomy: AutonomyStatus.none,
    );
    await docRef.set(user.toMap(), SetOptions(merge: true));
  }

  // TODO: Considerar sustituir esta función por una cloud function más segura.
  Future<void> linkCompanionToElder(String code, String companionId) async {
    // 1. Buscamos si existe un Mayor con ese código exacto
    final query = await _firestore
        .collection('users')
        .where('linkCode', isEqualTo: code)
        .where('role', isEqualTo: UserRole.elder.name) // Asegúrate de cómo guardas los enums
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('El código no es válido o ya ha caducado.');
    }

    // 2. ¡Lo hemos encontrado! Extraemos sus datos
    final elderDoc = query.docs.first;
    final elderId = elderDoc.id;

    // 3. Preparamos una operación Atómica (Batch). O se hace todo, o no se hace nada.
    final batch = _firestore.batch();
    final companionRef = _firestore.collection('users').doc(companionId);

    // Actualizamos al Mayor
    batch.update(elderDoc.reference, {
      'linkedCompanionId': companionId,
      'autonomy': AutonomyStatus.dependent.name,
      'linkCode': FieldValue.delete(), // Borramos el código para que no se use dos veces
    });

    // Actualizamos al Familiar
    batch.update(companionRef, {
      'linkedElderId': elderId,
      'autonomy': AutonomyStatus.linked.name,
    });

    // 4. Ejecutamos los cambios en la nube
    await batch.commit();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );
});
