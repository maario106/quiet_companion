import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/providers/tts_service_provider.dart';
import 'package:quiet_companion/core/services/emergency_call_service.dart';
import 'package:quiet_companion/core/services/speech_service.dart';
import 'package:quiet_companion/features/emergency/presentation/emergency_screen.dart';

import '../../helpers/fake_tts_service.dart';

class FakeEmergencyCallService implements EmergencyCallService {
  final List<String> dialed = [];
  bool result = true;

  @override
  Future<bool> dial(String phone) async {
    dialed.add(phone);
    return result;
  }
}

class FakeSpeechService implements SpeechService {
  int finishListeningCalls = 0;
  int cancelListeningCalls = 0;

  @override
  Future<bool> initiate() async => true;

  @override
  void beginListening({
    required void Function(String transcript) onPartial,
    required void Function(String transcript) onFinal,
    required Duration silenceTimeout,
  }) {}

  @override
  bool finishListening() {
    finishListeningCalls++;
    return false;
  }

  @override
  void cancelListening() {
    cancelListeningCalls++;
  }

  @override
  String get transcript => '';

  @override
  bool get isListening => false;
}

const _elderWithCompanionContact = UserModel(
  id: 'elder-1',
  role: UserRole.elder,
  autonomy: AutonomyStatus.dependent,
  emergencyContact: EmergencyContact(
    name: 'María',
    phone: '+34600123456',
    source: EmergencyContactSource.companion,
  ),
);

const _elderWithoutContact = UserModel(
  id: 'elder-3',
  role: UserRole.elder,
  autonomy: AutonomyStatus.independent,
);

Widget _buildSubject({
  required UserModel user,
  required FakeEmergencyCallService callService,
  FakeTtsService? tts,
  FakeSpeechService? speech,
  Widget? home,
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(user)),
      emergencyCallServiceProvider.overrideWithValue(callService),
      ttsServiceProvider.overrideWithValue(tts ?? FakeTtsService()),
      speechServiceProvider.overrideWithValue(speech ?? FakeSpeechService()),
    ],
    child: MaterialApp(home: home ?? const EmergencyScreen()),
  );
}

void main() {
  group('EmergencyScreen', () {
    testWidgets('contacto source companion: 3 botones, nombre visible, '
        'tap marca su teléfono', (tester) async {
      final callService = FakeEmergencyCallService();
      await tester.pumpWidget(_buildSubject(
        user: _elderWithCompanionContact,
        callService: callService,
      ));
      await tester.pumpAndSettle();

      // bySubtype: ElevatedButton.icon construye una subclase privada.
      expect(find.bySubtype<ElevatedButton>(), findsNWidgets(2));
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.text('Llamar a María'), findsOneWidget);
      expect(find.text('Llamar al 112'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      await tester.tap(find.text('Llamar a María'));
      await tester.pump();

      expect(callService.dialed, equals(['+34600123456']));
    });

    testWidgets('tap en 112 marca 112 aunque haya contacto', (tester) async {
      final callService = FakeEmergencyCallService();
      await tester.pumpWidget(_buildSubject(
        user: _elderWithCompanionContact,
        callService: callService,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Llamar al 112'));
      await tester.pump();

      expect(callService.dialed, equals(['112']));
    });

    testWidgets('dial devuelve false: texto de error persistente, sin SnackBar',
        (tester) async {
      final callService = FakeEmergencyCallService()..result = false;
      await tester.pumpWidget(_buildSubject(
        user: _elderWithoutContact,
        callService: callService,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Llamar al 112'));
      await tester.pumpAndSettle();

      expect(
          find.text('Este dispositivo no puede hacer llamadas'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
