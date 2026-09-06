import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quiet_companion/core/constants/firestore_paths.dart';
import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';

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

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> saveUser(UserModel user) async {
    await _firestore.collection(FirestorePaths.usersCollection).doc(user.id).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final snapshot = await _firestore.collection(FirestorePaths.usersCollection).doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return UserModel.fromMap(uid, snapshot.data()!);
  }

  Stream<UserModel?> streamUser(String uid) {
    return _firestore.collection(FirestorePaths.usersCollection).doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserModel.fromMap(uid, snapshot.data()!);
    });
  }

  String? currentUid() => _auth.currentUser?.uid;

  Stream<String?> authStateUid() {
    return _auth.authStateChanges().map((user) => user?.uid);
  }

  Future<void> ensureCompanionUserDoc(
    String uid, {
    String? name,
    String? phoneNumber,
  }) async {
    final docRef = _firestore.collection(FirestorePaths.usersCollection).doc(uid);
    final snapshot = await docRef.get();
    if (snapshot.exists && snapshot.data() != null) return;
    final user = UserModel(
      id: uid,
      name: name,
      role: UserRole.companion,
      autonomy: AutonomyStatus.none,
      phoneNumber: phoneNumber,
    );
    await docRef.set(user.toMap(), SetOptions(merge: true));
  }

  Future<void> updateName(String uid, String name) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .update({'name': name});
  }

  /// Escribe las preferencias de accesibilidad del mayor desde su propio
  /// dispositivo. Actualiza solo el campo `preferences`, a diferencia de
  /// [saveUser] (que reescribe el documento entero y usa el familiar desde su
  /// panel): el mayor no debe poder tocar de rebote su rol, su vinculación ni
  /// su contacto de emergencia al subir el tamaño de la letra.
  Future<void> updatePreferences(String uid, UserPreferences prefs) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .update({'preferences': prefs.toMap()});
  }

  /// Escribe el contacto de emergencia elegido por el mayor (source: manual).
  Future<void> updateEmergencyContact(
      String uid, EmergencyContact contact) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .update({'emergencyContact': contact.toMap()});
  }

  // TODO: Considerar sustituir esta función por una cloud function más segura.
  Future<void> linkCompanionToElder(String code, String companionId) async {
    // 1. Buscamos si existe un Mayor con ese código exacto. Las transacciones
    // del cliente no admiten queries, así que la búsqueda va fuera y el código
    // se revalida dentro leyendo el documento.
    final query = await _firestore
        .collection(FirestorePaths.usersCollection)
        .where('linkCode', isEqualTo: code)
        .where('role', isEqualTo: UserRole.elder.name)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('El código no es válido o ya ha caducado.');
    }

    final elderRef = query.docs.first.reference;
    final companionRef =
        _firestore.collection(FirestorePaths.usersCollection).doc(companionId);

    // 2. Transacción (antes era un WriteBatch): necesitamos LEER el doc del
    // mayor antes de escribir para respetar la precedencia del contacto de
    // emergencia — una vinculación nunca sobrescribe un contacto manual.
    await _firestore.runTransaction((transaction) async {
      final elderSnap = await transaction.get(elderRef);
      final companionSnap = await transaction.get(companionRef);

      if (!elderSnap.exists || elderSnap.data()?['linkCode'] != code) {
        throw Exception('El código no es válido o ya ha caducado.');
      }

      final elderUpdate = <String, dynamic>{
        'linkedCompanionId': companionId,
        'autonomy': AutonomyStatus.dependent.name,
        'linkCode': FieldValue.delete(), // El código es de un solo uso
      };

      // Desnormalización del contacto de emergencia (el mayor solo lee su
      // propio doc, sin lecturas cross-user). Solo si el familiar tiene
      // teléfono y el mayor no eligió ya un contacto manual.
      final existingContact =
          EmergencyContact.fromMapOrNull(elderSnap.data()?['emergencyContact']);
      final companionPhone = companionSnap.data()?['phoneNumber'] as String?;
      final companionName = companionSnap.data()?['name'] as String?;

      final elderChoseManually =
          existingContact?.source == EmergencyContactSource.manual;
      if (!elderChoseManually &&
          companionPhone != null &&
          companionPhone.isNotEmpty) {
        elderUpdate['emergencyContact'] = EmergencyContact(
          name: (companionName == null || companionName.isEmpty)
              ? 'Mi familiar'
              : companionName,
          phone: companionPhone,
          source: EmergencyContactSource.companion,
        ).toMap();
      }

      transaction.update(elderRef, elderUpdate);
      transaction.update(companionRef, {
        'linkedElderId': elderRef.id,
        'autonomy': AutonomyStatus.linked.name,
      });
    });
  }
}
