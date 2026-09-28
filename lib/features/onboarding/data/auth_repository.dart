import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quiet_companion/core/config/functions_config.dart';
import 'package:quiet_companion/core/constants/firestore_paths.dart';
import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';

class AuthRepository {
  const AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _auth = auth,
        _firestore = firestore,
        _functions = functions;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

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

  /// Escribe el documento **entero**. Solo para crearlo (onboarding del
  /// mayor): reescribir a partir de una copia deshace lo que otro haya
  /// cambiado desde que se leyó (ADR-0027). Para editar, un `update` por campo.
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

  /// Escribe **una** magnitud de preferencias del mayor con ruta de punto
  /// (`preferences.volume`). La usa el panel del familiar: si el mayor cambió
  /// otra magnitud entretanto, esta escritura no la pisa (ADR-0027). [field]
  /// es una de las claves de [UserPreferences] (`volumeKey`, …).
  Future<void> updatePreferenceField(
      String uid, String field, double value) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .update({'preferences.$field': value});
  }

  /// Un plazo de la conversación del mayor vinculado, escrito por su familiar
  /// desde el panel (ADR-0034). [field] es una clave de `ConversationSettings`;
  /// el servidor acota el valor por su cuenta.
  Future<void> updateConversationSettingField(
      String uid, String field, int value) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .update({'conversationSettings.$field': value});
  }

  /// Escribe el contacto de emergencia elegido por el mayor (source: manual).
  Future<void> updateEmergencyContact(
      String uid, EmergencyContact contact) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .update({'emergencyContact': contact.toMap()});
  }

  /// Vincula al familiar autenticado con el mayor dueño de [code].
  ///
  /// La búsqueda y la transacción viven en la Cloud Function
  /// `validateAndLink`, no aquí: encontrar al mayor obliga a consultar
  /// `/users` por `linkCode`, y las reglas de Firestore no pueden acotar una
  /// consulta de colección (no ven las cláusulas `where`). Mientras esto se
  /// hacía en el cliente, `/users` tenía que ser consultable por cualquier
  /// autenticado (RNF-9, ADR-0008).
  ///
  /// El identificador del familiar ya no es un parámetro: el servidor lo toma
  /// de la sesión, así que nadie puede vincular a un tercero.
  Future<String> linkCompanionToElder(String code) async {
    try {
      final result = await _functions
          .httpsCallable(kValidateAndLinkCallable)
          .call<dynamic>(<String, dynamic>{'code': code});

      // El canal de plataforma entrega mapas sin tipar; se lee
      // defensivamente en vez de castear, que falla en Android.
      final data = result.data;
      final elderId = data is Map ? data['elderId'] : null;
      if (elderId is! String || elderId.isEmpty) {
        throw Exception('No se ha podido vincular.');
      }
      return elderId;
    } on FirebaseFunctionsException catch (error) {
      // El mensaje de la Function ya viene en es-ES y redactado para el
      // familiar; se reenvía tal cual para que la UI no cambie de texto
      // respecto de la versión que hacía esto en el cliente.
      throw Exception(error.message ?? 'No se ha podido vincular.');
    }
  }
}
