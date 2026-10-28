import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/config/route_redirect.dart';
import 'package:quiet_companion/core/models/conversation_consent.dart';
import 'package:quiet_companion/core/models/user_model.dart';

/// Ya respondió a la pregunta del consentimiento (sea cual sea la respuesta):
/// el enrutador no vuelve a enseñársela.
const _answered = ConversationConsent(granted: false);

/// Envuelve la función real del enrutador ([routeRedirect]). Antes este test
/// reimplementaba las condiciones a mano y podía seguir en verde probando una
/// versión antigua de la lógica.
class RouterRedirectTestHelper {
  static String? computeRedirect({
    required bool elderCheckingAuth,
    required bool companionLinked,
    required bool companionAuthenticated,
    required UserModel? elderUser,
    required bool elderAuthenticated,
    required String currentLocation,
    bool consentPromptDeferred = false,
  }) {
    return routeRedirect(
      elderCheckingAuth: elderCheckingAuth,
      companionLinked: companionLinked,
      companionAuthenticated: companionAuthenticated,
      elderUser: elderUser,
      elderAuthenticated: elderAuthenticated,
      consentPromptDeferred: consentPromptDeferred,
      location: currentLocation,
    );
  }
}

void main() {
  group('Router redirect logic', () {
    group('elder authentication flow', () {
      test('unauthenticated user → /onboarding', () {
        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: false,
          companionAuthenticated: false,
          elderUser: null,
          elderAuthenticated: false,
          currentLocation: '/splash',
        );

        expect(result, equals('/onboarding'));
      });

      test('elder with autonomy == dependent + linkCode != null (not yet linked) → onboarding', () {
        final elderUser = UserModel(
          id: 'elder-4',
          role: UserRole.elder,
          autonomy: AutonomyStatus.dependent,
          linkCode: 'ABC2',
        );

        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: false,
          companionAuthenticated: false,
          elderUser: elderUser,
          elderAuthenticated: true,
          currentLocation: '/home',
        );

        expect(result, equals('/onboarding'));
      });

      test('elder with autonomy == dependent + linkCode == null (linked) → /home', () {
        final elderUser = UserModel(
          id: 'elder-5',
          conversationConsent: _answered,
          role: UserRole.elder,
          autonomy: AutonomyStatus.dependent,
          linkedCompanionId: 'comp-123',
        );

        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: false,
          companionAuthenticated: false,
          elderUser: elderUser,
          elderAuthenticated: true,
          currentLocation: '/onboarding',
        );

        expect(result, equals('/home'));
      });
    });

    group('companion authentication flow', () {
      test('companion authenticated but not linked → /companion/pairing', () {
        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: false,
          companionAuthenticated: true,
          elderUser: null,
          elderAuthenticated: false,
          currentLocation: '/dashboard',
        );

        expect(result, equals('/companion/pairing'));
      });
    });

    group('consentimiento (ADR-0030)', () {
      const independiente = UserModel(
        id: 'elder-c1',
        role: UserRole.elder,
        autonomy: AutonomyStatus.independent,
      );
      const recienVinculado = UserModel(
        id: 'elder-c2',
        role: UserRole.elder,
        autonomy: AutonomyStatus.dependent,
        linkedCompanionId: 'comp-1',
      );

      test('independiente sin responder: tras elegir modo → /consent', () {
        expect(
          RouterRedirectTestHelper.computeRedirect(
            elderCheckingAuth: false,
            companionLinked: false,
            companionAuthenticated: false,
            elderUser: independiente,
            elderAuthenticated: true,
            currentLocation: '/onboarding',
          ),
          equals('/consent'),
        );
      });

      test('recién vinculado sin responder → /consent, también desde /home', () {
        expect(
          RouterRedirectTestHelper.computeRedirect(
            elderCheckingAuth: false,
            companionLinked: false,
            companionAuthenticated: false,
            elderUser: recienVinculado,
            elderAuthenticated: true,
            currentLocation: '/home',
          ),
          equals('/consent'),
        );
      });
    });
  });
}
