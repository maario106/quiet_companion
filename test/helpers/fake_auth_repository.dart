import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show AuthCredential;
import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/core/repositories/auth_repository.dart';

/// Registra las escrituras por campo del panel (ADR-0027). `saveUser` lanza a
/// propósito: el panel ya no debe reescribir el documento entero del mayor.
///
/// Simula además la sesión: [signInAs] emite por [authStateUid], y entrar con
/// Google sigue el contrato del repositorio real, cuenta de familiar incluida.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.shouldThrow = false});

  bool shouldThrow;
  final preferenceWrites = <(String uid, String field, Object value)>[];
  final nameWrites = <(String uid, String name)>[];

  /// Documentos de `users`, por uid.
  final users = <String, UserModel>{};

  /// Cuenta que devuelve el selector de Google; null = el mayor lo cierra.
  String? googleUid;

  /// Lo que devuelve [linkWithGoogle].
  GoogleLinkResult linkResult = const GoogleLinked();

  /// Lo que enseña [accountChanges].
  AuthAccount? account;

  String? signedInUid;
  int anonymousSignIns = 0;
  int signOutCalls = 0;
  final _uids = StreamController<String?>.broadcast();

  void _maybeThrow() {
    if (shouldThrow) throw Exception('Write failed');
  }

  void signInAs(String? uid) {
    signedInUid = uid;
    _uids.add(uid);
  }

  @override
  Future<String> signInAnonymously() async {
    anonymousSignIns++;
    signInAs('anon-uid');
    return 'anon-uid';
  }

  @override
  Future<String> signInWithEmail(String email, String password) async =>
      'email-uid';

  @override
  Future<String> registerWithEmail(String email, String password) async =>
      'register-uid';

  @override
  Future<bool> signInWithGoogle() async {
    final uid = googleUid;
    if (uid == null) return false;
    signInAs(uid);
    if (users[uid]?.role == UserRole.companion) {
      await signOut();
      throw const CompanionAccountException();
    }
    return true;
  }

  @override
  Future<void> signInWithGoogleCredential(AuthCredential credential) async =>
      signInAs(googleUid);

  @override
  Future<GoogleLinkResult> linkWithGoogle() async => linkResult;

  @override
  Stream<AuthAccount?> accountChanges() => Stream.value(account);

  @override
  Future<void> signOut() async {
    signOutCalls++;
    signInAs(null);
  }

  @override
  Future<void> saveUser(UserModel user) async {
    throw StateError('El panel no debe reescribir el documento entero');
  }

  @override
  Future<UserModel?> getUser(String uid) async => users[uid];

  @override
  Stream<UserModel?> streamUser(String uid) => const Stream.empty();

  @override
  String? currentUid() => signedInUid;

  @override
  Stream<String?> authStateUid() => _uids.stream;

  @override
  Future<void> ensureCompanionUserDoc(
    String uid, {
    String? name,
    String? phoneNumber,
  }) async {}

  @override
  Future<void> updateName(String uid, String name) async {
    _maybeThrow();
    nameWrites.add((uid, name));
  }

  @override
  Future<void> updateEmergencyContact(
      String uid, EmergencyContact contact) async {}

  @override
  Future<void> updatePreferences(String uid, UserPreferences prefs) async {}

  @override
  Future<void> updatePreferenceField(
      String uid, String field, Object value) async {
    _maybeThrow();
    preferenceWrites.add((uid, field, value));
  }

  final settingWrites = <(String uid, String field, int value)>[];

  @override
  Future<void> updateConversationSettingField(
      String uid, String field, int value) async {
    _maybeThrow();
    settingWrites.add((uid, field, value));
  }

  @override
  Future<String> linkCompanionToElder(String code) async => 'elder-1';
}
