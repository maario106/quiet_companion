import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/features/onboarding/data/auth_repository.dart';

/// Registra las escrituras por campo del panel (ADR-0027). `saveUser` lanza a
/// propósito: el panel ya no debe reescribir el documento entero del mayor.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.shouldThrow = false});

  bool shouldThrow;
  final preferenceWrites = <(String uid, String field, double value)>[];
  final nameWrites = <(String uid, String name)>[];

  void _maybeThrow() {
    if (shouldThrow) throw Exception('Write failed');
  }

  @override
  Future<String> signInAnonymously() async => 'anon-uid';

  @override
  Future<String> signInWithEmail(String email, String password) async =>
      'email-uid';

  @override
  Future<String> registerWithEmail(String email, String password) async =>
      'register-uid';

  @override
  Future<void> signOut() async {}

  @override
  Future<void> saveUser(UserModel user) async {
    throw StateError('El panel no debe reescribir el documento entero');
  }

  @override
  Future<UserModel?> getUser(String uid) async => null;

  @override
  Stream<UserModel?> streamUser(String uid) => const Stream.empty();

  @override
  String? currentUid() => null;

  @override
  Stream<String?> authStateUid() => const Stream.empty();

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
      String uid, String field, double value) async {
    _maybeThrow();
    preferenceWrites.add((uid, field, value));
  }

  @override
  Future<String> linkCompanionToElder(String code) async => 'elder-1';
}
