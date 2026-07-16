import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/features/dashboard/domain/dashboard_controller.dart';
import 'package:quiet_companion/features/dashboard/domain/dashboard_state.dart';
import 'package:quiet_companion/features/onboarding/data/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.shouldThrowOnSave = false,
  });

  bool shouldThrowOnSave;
  final savedUsers = <UserModel>[];
  final elderUsers = <String, UserModel>{};

  @override
  Future<String> signInAnonymously() async => 'anon-uid';

  @override
  Future<String> signInWithEmail(String email, String password) async => 'email-uid';

  @override
  Future<String> registerWithEmail(String email, String password) async => 'register-uid';

  @override
  Future<void> signOut() async {}

  @override
  Future<void> saveUser(UserModel user) async {
    if (shouldThrowOnSave) {
      throw Exception('Save failed');
    }
    savedUsers.add(user);
  }

  @override
  Future<UserModel?> getUser(String uid) async {
    return elderUsers[uid];
  }

  @override
  Stream<UserModel?> streamUser(String uid) {
    throw UnimplementedError();
  }

  @override
  String? currentUid() => null;

  @override
  Stream<String?> authStateUid() {
    throw UnimplementedError();
  }

  @override
  Future<void> ensureCompanionUserDoc(
    String uid, {
    String? name,
    String? phoneNumber,
  }) async {}

  @override
  Future<void> updateName(String uid, String name) async {}

  @override
  Future<void> updateEmergencyContact(
      String uid, EmergencyContact contact) async {}

  @override
  Future<void> linkCompanionToElder(String code, String companionId) async {}
}

void main() {
  group('DashboardController', () {
    group('updateElderPreferences', () {
      test('happy path: optimistic update then persist, no error', () async {
        final elder = UserModel(
          id: 'elder-123',
          role: UserRole.elder,
          autonomy: AutonomyStatus.linked,
          preferences: const UserPreferences(
            volume: 1.0,
            speechRate: 0.4,
            textSizeMultiplier: 1.2,
          ),
        );
        final fakeRepo = FakeAuthRepository();
        fakeRepo.elderUsers['elder-123'] = elder;

        final controller = DashboardController(fakeRepo, null);
        controller.state = DashboardState(
          status: DashboardStatus.loaded,
          linkedElder: elder,
        );

        final newPrefs = const UserPreferences(
          volume: 0.5,
          speechRate: 0.7,
          textSizeMultiplier: 1.5,
        );

        await controller.updateElderPreferences(newPrefs);

        expect(controller.state.linkedElder?.preferences.volume, equals(0.5));
        expect(controller.state.linkedElder?.preferences.speechRate, equals(0.7));
        expect(controller.state.linkedElder?.preferences.textSizeMultiplier, equals(1.5));
        expect(fakeRepo.savedUsers.length, equals(1));
        expect(fakeRepo.savedUsers[0].preferences.volume, equals(0.5));
      });

      test('rollback: if saveUser throws, state reverts and errorMessage is set', () async {
        final elder = UserModel(
          id: 'elder-456',
          role: UserRole.elder,
          autonomy: AutonomyStatus.linked,
          preferences: const UserPreferences(
            volume: 1.0,
            speechRate: 0.4,
            textSizeMultiplier: 1.2,
          ),
        );
        final fakeRepo = FakeAuthRepository(shouldThrowOnSave: true);

        final controller = DashboardController(fakeRepo, null);
        controller.state = DashboardState(
          status: DashboardStatus.loaded,
          linkedElder: elder,
        );

        final initialVolume = controller.state.linkedElder!.preferences.volume;
        expect(initialVolume, equals(1.0));

        final newPrefs = const UserPreferences(
          volume: 0.3,
          speechRate: 0.6,
          textSizeMultiplier: 1.4,
        );

        await controller.updateElderPreferences(newPrefs);

        expect(controller.state.linkedElder?.preferences.volume, equals(1.0));
        expect(controller.state.linkedElder?.preferences.speechRate, equals(0.4));
        expect(controller.state.linkedElder?.preferences.textSizeMultiplier, equals(1.2));
        expect(controller.state.errorMessage, contains('Error'));
      });

      test('no-op: if linkedElder is null, updateElderPreferences does nothing', () async {
        final fakeRepo = FakeAuthRepository();
        final controller = DashboardController(fakeRepo, null);

        final newPrefs = const UserPreferences(volume: 0.5);
        await controller.updateElderPreferences(newPrefs);

        expect(controller.state.linkedElder, isNull);
        expect(fakeRepo.savedUsers, isEmpty);
      });

      test('optimistic update: preferences update immediately before save completes', () async {
        final elder = UserModel(
          id: 'elder-789',
          role: UserRole.elder,
          autonomy: AutonomyStatus.linked,
          preferences: const UserPreferences(volume: 1.0),
        );
        final fakeRepo = FakeAuthRepository();
        fakeRepo.elderUsers['elder-789'] = elder;

        final controller = DashboardController(fakeRepo, null);
        controller.state = DashboardState(
          status: DashboardStatus.loaded,
          linkedElder: elder,
        );

        final newPrefs = const UserPreferences(volume: 0.2);
        final updateFuture = controller.updateElderPreferences(newPrefs);

        expect(controller.state.linkedElder?.preferences.volume, equals(0.2));

        await updateFuture;

        expect(controller.state.linkedElder?.preferences.volume, equals(0.2));
      });
    });

    group('refreshElderData', () {
      test('updates state with loaded elder data on success', () async {
        final elder = UserModel(
          id: 'elder-refresh',
          name: 'María',
          role: UserRole.elder,
          autonomy: AutonomyStatus.independent,
        );
        final fakeRepo = FakeAuthRepository();
        fakeRepo.elderUsers['elder-refresh'] = elder;

        final controller = DashboardController(fakeRepo, null);
        await controller.refreshElderData();

        expect(controller.state.status, equals(DashboardStatus.loaded));
        expect(controller.state.linkedElder?.name, equals('María'));
      });

      test('sets error state if getUser returns null', () async {
        final fakeRepo = FakeAuthRepository();
        final controller = DashboardController(fakeRepo, null);

        await controller.refreshElderData();

        expect(controller.state.status, equals(DashboardStatus.error));
        expect(controller.state.errorMessage, isNotEmpty);
      });
    });

    group('state transitions', () {
      test('updateElderName clears name when saving succeeds', () async {
        final elder = UserModel(
          id: 'elder-name',
          name: 'Old Name',
          role: UserRole.elder,
          autonomy: AutonomyStatus.independent,
        );
        final fakeRepo = FakeAuthRepository();

        final controller = DashboardController(fakeRepo, null);
        controller.state = DashboardState(
          status: DashboardStatus.loaded,
          linkedElder: elder,
        );

        await controller.updateElderName('New Name');

        expect(controller.state.linkedElder?.name, equals('New Name'));
        expect(controller.state.errorMessage, isEmpty);
      });

      test('updateElderName ignores empty/whitespace names', () async {
        final elder = UserModel(
          id: 'elder-name-empty',
          name: 'Existing',
          role: UserRole.elder,
          autonomy: AutonomyStatus.independent,
        );
        final fakeRepo = FakeAuthRepository();

        final controller = DashboardController(fakeRepo, null);
        controller.state = DashboardState(
          status: DashboardStatus.loaded,
          linkedElder: elder,
        );

        await controller.updateElderName('   ');

        expect(controller.state.linkedElder?.name, equals('Existing'));
      });
    });
  });
}
