import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:quiet_companion/core/config/functions_config.dart';
import 'package:quiet_companion/core/constants/firestore_paths.dart';
import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';

/// Sesión de Firebase como la enseña "Mi cuenta": anónima o con Google.
class AuthAccount {
  const AuthAccount({required this.isAnonymous, this.email});

  final bool isAnonymous;
  final String? email;
}

/// Cómo termina guardar con Google la cuenta anónima del mayor.
sealed class GoogleLinkResult {
  const GoogleLinkResult();
}

/// La cuenta anónima pasa a ser de Google con el mismo uid.
final class GoogleLinked extends GoogleLinkResult {
  const GoogleLinked();
}

/// El mayor cerró el selector de cuentas sin elegir ninguna.
final class GoogleLinkCancelled extends GoogleLinkResult {
  const GoogleLinkCancelled();
}

/// Esa cuenta de Google ya tiene su propia cuenta en la app; se puede entrar
/// con [credential].
final class GoogleAccountInUse extends GoogleLinkResult {
  const GoogleAccountInUse(this.credential);

  final AuthCredential credential;
}

/// Se intentó entrar como mayor con la cuenta de Google de un familiar.
class CompanionAccountException implements Exception {
  const CompanionAccountException();
}

/// Por qué no se ha podido vincular, ya redactado para el familiar.
class PairingException implements Exception {
  const PairingException(this.message);

  /// Solo los códigos de validateAndLink traen un mensaje para el familiar; los
  /// del plugin (sin red, tiempo agotado) vienen en inglés.
  factory PairingException.fromFunctions(FirebaseFunctionsException error) {
    const fromServer = {
      'invalid-argument',
      'not-found',
      'permission-denied',
      'unauthenticated',
    };
    final message = error.message;
    return PairingException(fromServer.contains(error.code) && message != null
        ? message
        : 'No se ha podido vincular. '
            'Comprueba la conexión e inténtalo otra vez.');
  }

  final String message;
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

  /// google_sign_in exige inicializarse una vez antes de cualquier llamada.
  static Future<void>? _googleReady;

  Future<GoogleSignIn> _google() async {
    await (_googleReady ??= GoogleSignIn.instance.initialize());
    return GoogleSignIn.instance;
  }

  /// Credencial de la cuenta de Google elegida, o null si se cierra el selector.
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

  /// "Entrar con Google". Devuelve false si se cierra el selector.
  Future<bool> signInWithGoogle() async {
    final credential = await _googleCredential();
    if (credential == null) return false;
    await signInWithGoogleCredential(credential);
    return true;
  }

  /// Entra como mayor con una credencial de Google. Si la cuenta es de un
  /// familiar, cierra la sesión y lanza [CompanionAccountException].
  Future<void> signInWithGoogleCredential(AuthCredential credential) async {
    final signedIn = await _auth.signInWithCredential(credential);
    final uid = signedIn.user?.uid;
    if (uid == null) return;
    if ((await getUser(uid))?.role != UserRole.companion) return;
    await signOut();
    throw const CompanionAccountException();
  }

  /// Guarda con Google la cuenta anónima sin cambiar de uid.
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

  /// La sesión en vivo; userChanges también avisa al vincular con Google.
  Stream<AuthAccount?> accountChanges() {
    return _auth.userChanges().map((user) {
      if (user == null) return null;
      final email = user.email ??
          user.providerData.map((p) => p.email).whereType<String>().firstOrNull;
      return AuthAccount(isAnonymous: user.isAnonymous, email: email);
    });
  }

  Future<void> signOut() async {
    // Para que el selector no vuelva a entrar solo con la misma cuenta.
    try {
      await (await _google()).signOut();
    } catch (_) {
      // Se cierra igual.
    }
    await _auth.signOut();
  }

  /// Vuelve a la bienvenida. La sesión anónima se borra; la de Google solo se cierra.
  Future<void> leaveBeforeChoosingMode() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (!user.isAnonymous) return signOut();
    try {
      await user.delete();
    } catch (_) {
      await _auth.signOut();
    }
  }

  /// Escribe el documento entero; solo para crearlo. Para editar, update por campo.
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

  /// Actualiza solo el campo preferences del mayor.
  Future<void> updatePreferences(String uid, UserPreferences prefs) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .update({'preferences': prefs.toMap()});
  }

  /// Escribe una sola preferencia con ruta de punto, sin pisar las demás.
  Future<void> updatePreferenceField(
      String uid, String field, Object value) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .update({'preferences.$field': value});
  }

  /// Un plazo de la conversación, escrito por el familiar desde el panel.
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

  /// Vincula al familiar autenticado con el mayor dueño de [code], vía validateAndLink.
  Future<String> linkCompanionToElder(String code) async {
    try {
      final result = await _functions
          .httpsCallable(kValidateAndLinkCallable)
          .call<dynamic>(<String, dynamic>{'code': code});

      // El canal de plataforma entrega mapas sin tipar.
      final data = result.data;
      final elderId = data is Map ? data['elderId'] : null;
      if (elderId is! String || elderId.isEmpty) {
        throw const PairingException('No se ha podido vincular.');
      }
      return elderId;
    } on FirebaseFunctionsException catch (error) {
      throw PairingException.fromFunctions(error);
    }
  }
}
