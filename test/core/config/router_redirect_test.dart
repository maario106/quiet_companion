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

      test('elder with autonomy == none → onboarding', () {
        final elderUser = UserModel(
          id: 'elder-1',
          role: UserRole.elder,
          autonomy: AutonomyStatus.none,
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

      test('elder with autonomy == independent → /home', () {
        final elderUser = UserModel(
          id: 'elder-2',
          conversationConsent: _answered,
          role: UserRole.elder,
          autonomy: AutonomyStatus.independent,
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

      test('elder with autonomy == independent, already at /home → null (no redirect)', () {
        final elderUser = UserModel(
          id: 'elder-3',
          conversationConsent: _answered,
          role: UserRole.elder,
          autonomy: AutonomyStatus.independent,
        );

        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: false,
          companionAuthenticated: false,
          elderUser: elderUser,
          elderAuthenticated: true,
          currentLocation: '/home',
        );

        expect(result, isNull);
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

      test('elder with autonomy == dependent + linkCode == null, already at /home → null', () {
        final elderUser = UserModel(
          id: 'elder-6',
          conversationConsent: _answered,
          role: UserRole.elder,
          autonomy: AutonomyStatus.dependent,
          linkedCompanionId: 'comp-456',
        );

        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: false,
          companionAuthenticated: false,
          elderUser: elderUser,
          elderAuthenticated: true,
          currentLocation: '/home',
        );

        expect(result, isNull);
      });

      test('elder checking auth (still loading) → null (no redirect, wait for auth)', () {
        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: true,
          companionLinked: false,
          companionAuthenticated: false,
          elderUser: null,
          elderAuthenticated: false,
          currentLocation: '/splash',
        );

        expect(result, isNull);
      });
    });

    group('companion authentication flow', () {
      test('companion linked → /dashboard', () {
        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: true,
          companionAuthenticated: true,
          elderUser: null,
          elderAuthenticated: false,
          currentLocation: '/companion/pairing',
        );

        expect(result, equals('/dashboard'));
      });

      test('companion linked, already at /dashboard → null (no redirect)', () {
        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: true,
          companionAuthenticated: true,
          elderUser: null,
          elderAuthenticated: false,
          currentLocation: '/dashboard',
        );

        expect(result, isNull);
      });

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

      test('companion authenticated but not linked, already at pairing → null', () {
        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: false,
          companionAuthenticated: true,
          elderUser: null,
          elderAuthenticated: false,
          currentLocation: '/companion/pairing',
        );

        expect(result, isNull);
      });
    });

    group('companion paths allow-through', () {
      test('user can navigate to /companion/choice without redirect', () {
        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: false,
          companionAuthenticated: false,
          elderUser: null,
          elderAuthenticated: false,
          currentLocation: '/companion/choice',
        );

        expect(result, isNull);
      });

      test('user can navigate to /companion/register without redirect', () {
        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: false,
          companionAuthenticated: false,
          elderUser: null,
          elderAuthenticated: false,
          currentLocation: '/companion/register',
        );

        expect(result, isNull);
      });

      test('user can navigate to /companion/login without redirect', () {
        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: false,
          companionAuthenticated: false,
          elderUser: null,
          elderAuthenticated: false,
          currentLocation: '/companion/login',
        );

        expect(result, isNull);
      });
    });

    group('onboarding screen', () {
      test('user at /onboarding stays at /onboarding (default)', () {
        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: false,
          companionAuthenticated: false,
          elderUser: null,
          elderAuthenticated: false,
          currentLocation: '/onboarding',
        );

        expect(result, isNull);
      });
    });

    group('integration scenarios', () {
      test('elder independent mode: splash → /home', () {
        final elderUser = UserModel(
          id: 'elder-ind',
          conversationConsent: _answered,
          role: UserRole.elder,
          autonomy: AutonomyStatus.independent,
        );

        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: false,
          companionAuthenticated: false,
          elderUser: elderUser,
          elderAuthenticated: true,
          currentLocation: '/splash',
        );

        expect(result, equals('/home'));
      });

      test('elder dependent (linked): onboarding → /home', () {
        final elderUser = UserModel(
          id: 'elder-linked',
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

      test('companion unlinked: from /dashboard → /companion/pairing', () {
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

      test('companion linked: from /onboarding → /dashboard', () {
        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: true,
          companionAuthenticated: true,
          elderUser: null,
          elderAuthenticated: false,
          currentLocation: '/onboarding',
        );

        expect(result, equals('/dashboard'));
      });

      test('elder waiting for linkCode confirmation: dependent + linkCode present → onboarding', () {
        final elderUser = UserModel(
          id: 'elder-waiting',
          role: UserRole.elder,
          autonomy: AutonomyStatus.dependent,
          linkCode: 'XYZ9',
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
    });

    group('edge cases', () {
      test('non-elder UserModel (companion role) does not trigger elder routing', () {
        final companionUser = UserModel(
          id: 'comp-model',
          role: UserRole.companion,
          autonomy: AutonomyStatus.linked,
          linkedElderId: 'some-elder',
        );

        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: false,
          companionAuthenticated: false,
          elderUser: companionUser,
          elderAuthenticated: true,
          currentLocation: '/splash',
        );

        expect(result, equals('/onboarding'));
      });

      test('null elderUser with elderAuthenticated: true still routes to onboarding (conservative)', () {
        final result = RouterRedirectTestHelper.computeRedirect(
          elderCheckingAuth: false,
          companionLinked: false,
          companionAuthenticated: false,
          elderUser: null,
          elderAuthenticated: true,
          currentLocation: '/splash',
        );

        expect(result, equals('/onboarding'));
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

      test('en la pregunta o en su detalle, se queda', () {
        for (final location in ['/consent', '/consent/details']) {
          expect(
            RouterRedirectTestHelper.computeRedirect(
              elderCheckingAuth: false,
              companionLinked: false,
              companionAuthenticated: false,
              elderUser: independiente,
              elderAuthenticated: true,
              currentLocation: location,
            ),
            isNull,
          );
        }
      });

      test('ya respondió: de /consent a /home', () {
        expect(
          RouterRedirectTestHelper.computeRedirect(
            elderCheckingAuth: false,
            companionLinked: false,
            companionAuthenticated: false,
            elderUser: independiente.copyWith(conversationConsent: _answered),
            elderAuthenticated: true,
            currentLocation: '/consent',
          ),
          equals('/home'),
        );
      });

      test('respuesta sin guardar (aplazada en esta sesión): pasa a /home', () {
        expect(
          RouterRedirectTestHelper.computeRedirect(
            elderCheckingAuth: false,
            companionLinked: false,
            companionAuthenticated: false,
            elderUser: independiente,
            elderAuthenticated: true,
            currentLocation: '/consent',
            consentPromptDeferred: true,
          ),
          equals('/home'),
        );
      });

      test('esperando al familiar (con código): no se pregunta todavía', () {
        expect(
          RouterRedirectTestHelper.computeRedirect(
            elderCheckingAuth: false,
            companionLinked: false,
            companionAuthenticated: false,
            elderUser: const UserModel(
              id: 'elder-c3',
              role: UserRole.elder,
              autonomy: AutonomyStatus.dependent,
              linkCode: 'AB23',
            ),
            elderAuthenticated: true,
            currentLocation: '/consent',
          ),
          equals('/onboarding'),
        );
      });
    });

    group('subpantallas del panel (ADR-0033)', () {
      test('familiar vinculado en /dashboard/conversation/x → se queda', () {
        expect(
          RouterRedirectTestHelper.computeRedirect(
            elderCheckingAuth: false,
            companionLinked: true,
            companionAuthenticated: true,
            elderUser: null,
            elderAuthenticated: false,
            currentLocation: '/dashboard/conversation/abc',
          ),
          isNull,
        );
      });
    });
  });
}
