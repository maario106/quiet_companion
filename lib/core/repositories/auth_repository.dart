import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:quiet_companion/core/config/functions_config.dart';
import 'package:quiet_companion/core/constants/firestore_paths.dart';
import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';

/// La sesión de Firebase, tal y como la enseña "Mi cuenta": anónima o con una
/// cuenta de Google. No está en el documento del mayor porque no es un dato
/// suyo, sino de cómo ha entrado.
class AuthAccount {
  const AuthAccount({required this.isAnonymous, this.email});

  final bool isAnonymous;
  final String? email;
}

/// Cómo termina guardar con Google la cuenta anónima del mayor.
sealed class GoogleLinkResult {
  const GoogleLinkResult();
}

/// La cuenta anónima pasa a ser de Google con el mismo uid: lo hablado, la
/// memoria y el vínculo con el familiar siguen ahí.
final class GoogleLinked extends GoogleLinkResult {
  const GoogleLinked();
}

/// El mayor cerró el selector de cuentas sin elegir ninguna.
final class GoogleLinkCancelled extends GoogleLinkResult {
  const GoogleLinkCancelled();
}

/// Esa cuenta de Google ya tiene su propia cuenta en la aplicación (la del
/// móvil anterior, por ejemplo) y no se puede vincular. Se puede entrar con
/// ella usando [credential], y lo de esta sesión anónima se queda sin cuenta.
final class GoogleAccountInUse extends GoogleLinkResult {
  const GoogleAccountInUse(this.credential);

  final AuthCredential credential;
}

/// Se intentó entrar como mayor con la cuenta de Google de un familiar. La
/// sesión ya está cerrada cuando llega.
class CompanionAccountException implements Exception {
  const CompanionAccountException();
}

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

  /// `google_sign_in` exige inicializarse una vez antes de cualquier otra
  /// llamada. En Android toma el id de cliente web de `google-services.json`,
  /// que aparece al activar el proveedor de Google en la consola de Firebase.
  static Future<void>? _googleReady;

  Future<GoogleSignIn> _google() async {
    await (_googleReady ??= GoogleSignIn.instance.initialize());
    return GoogleSignIn.instance;
  }

  /// Credencial de Firebase de la cuenta de Google que elija el mayor, o null
  /// si cierra el selector sin elegir: eso no es un error.
  Future<AuthCredential?> _googleCredential() async {
    try {
      final account = await (await _google()).authenticate();
      return GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// "Entrar con Google", en la bienvenida. Si esa cuenta ya entró en
  /// otro móvil, el mayor recupera su documento tal cual. Devuelve false si
  /// cierra el selector.
  Future<bool> signInWithGoogle() async {
    final credential = await _googleCredential();
    if (credential == null) return false;
    await signInWithGoogleCredential(credential);
    return true;
  }

  /// Entra como mayor con una credencial de Google ya obtenida: la del
  /// selector, o la de [GoogleAccountInUse] cuando el mayor decide usar esa
  /// cuenta.
  ///
  /// Con "una cuenta por email", la cuenta de Google de un familiar que se
  /// registró con ese mismo email es la suya, y entrar con ella como mayor le
  /// reescribiría el rol al elegir modo. En ese caso se cierra la sesión y
  /// lanza [CompanionAccountException].
  Future<void> signInWithGoogleCredential(AuthCredential credential) async {
    final signedIn = await _auth.signInWithCredential(credential);
    final uid = signedIn.user?.uid;
    if (uid == null) return;
    if ((await getUser(uid))?.role != UserRole.companion) return;
    await signOut();
    throw const CompanionAccountException();
  }

  /// Guarda con Google la cuenta anónima en curso sin cambiar de uid, desde
  /// "Mi cuenta". Ni el documento del mayor ni las reglas notan nada: el uid
  /// es el mismo y solo cambia cómo se entra.
  Future<GoogleLinkResult> linkWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No hay sesión que guardar.');
    final credential = await _googleCredential();
    if (credential == null) return const GoogleLinkCancelled();
    try {
      await user.linkWithCredential(credential);
      return const GoogleLinked();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'credential-already-in-use') {
        return GoogleAccountInUse(error.credential ?? credential);
      }
      rethrow;
    }
  }

  /// La sesión en vivo. `userChanges` y no `authStateChanges`: vincular con
  /// Google no cambia de usuario, solo de proveedor, y la pantalla tiene que
  /// enterarse.
  Stream<AuthAccount?> accountChanges() {
    return _auth.userChanges().map((user) {
      if (user == null) return null;
      final email = user.email ??
          user.providerData.map((p) => p.email).whereType<String>().firstOrNull;
      return AuthAccount(isAnonymous: user.isAnonymous, email: email);
    });
  }

  Future<void> signOut() async {
    // Sin esto, el selector de Google podría volver a entrar solo con la misma
    // cuenta. Que falle (familiar con email, o Google sin configurar) no debe
    // impedir cerrar la sesión de Firebase.
    try {
      await (await _google()).signOut();
    } catch (_) {
      // Se cierra igual.
    }
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
  /// es una de las claves de [UserPreferences] (`volumeKey`, …). [value] es
  /// un `double` en las escalas y un `String` en la voz (`voiceKey`).
  Future<void> updatePreferenceField(
      String uid, String field, Object value) async {
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
