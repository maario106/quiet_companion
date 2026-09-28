import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/features/dashboard/domain/dashboard_controller.dart';
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

void main() {
  group('DashboardController', () {
    group('updateElderPreference', () {
      test('escribe solo el campo tocado, sobre el mayor vinculado', () async {
        final repo = FakeAuthRepository();
        final controller = DashboardController(repo, 'elder-1');

        await controller.updateElderPreference(UserPreferences.volumeKey, 0.5);

        expect(repo.preferenceWrites, [('elder-1', 'volume', 0.5)]);
        expect(controller.state.errorMessage, isNull);
      });

      test('si la escritura falla, deja un mensaje de error', () async {
        final repo = FakeAuthRepository(shouldThrow: true);
        final controller = DashboardController(repo, 'elder-1');

        await controller.updateElderPreference(
            UserPreferences.speechRateKey, 0.6);

        expect(controller.state.errorMessage, isNotNull);
      });

      test('sin mayor vinculado no escribe nada', () async {
        final repo = FakeAuthRepository();
        final controller = DashboardController(repo, null);

        await controller.updateElderPreference(UserPreferences.volumeKey, 0.5);

        expect(repo.preferenceWrites, isEmpty);
      });
    });

    group('updateElderName', () {
      test('escribe el nombre recortado', () async {
        final repo = FakeAuthRepository();
        final controller = DashboardController(repo, 'elder-1');

        await controller.updateElderName('  María  ');

        expect(repo.nameWrites, [('elder-1', 'María')]);
      });

      test('ignora nombres vacíos', () async {
        final repo = FakeAuthRepository();
        final controller = DashboardController(repo, 'elder-1');

        await controller.updateElderName('   ');

        expect(repo.nameWrites, isEmpty);
      });

      test('si la escritura falla, deja un mensaje de error', () async {
        final repo = FakeAuthRepository(shouldThrow: true);
        final controller = DashboardController(repo, 'elder-1');

        await controller.updateElderName('María');

        expect(controller.state.errorMessage, isNotNull);
      });
    });

    test('clearError limpia el mensaje', () async {
      final repo = FakeAuthRepository(shouldThrow: true);
      final controller = DashboardController(repo, 'elder-1');
      await controller.updateElderName('María');

      controller.clearError();

      expect(controller.state.errorMessage, isNull);
    });
  });
}
