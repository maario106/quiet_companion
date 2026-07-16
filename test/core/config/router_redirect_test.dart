import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/models/user_model.dart';

class MockGoRouterState extends Fake implements GoRouterState {
  MockGoRouterState(this.matchedLocation);

  @override
  final String matchedLocation;
}

// Extracts and tests the pure redirect logic from RouterNotifier.
class RouterRedirectTestHelper {
  /// Helper function to encapsulate the redirect logic without needing
  /// RouterNotifier or complex Riverpod setup. This mirrors the conditions
  /// in RouterNotifier.redirect() for unit testing.
  static String? computeRedirect({
    required bool elderCheckingAuth,
    required bool companionLinked,
    required bool companionAuthenticated,
    required UserModel? elderUser,
    required bool elderAuthenticated,
    required String currentLocation,
  }) {
    // If the app is starting (elder anonymous login), wait.
    if (elderCheckingAuth) return null;

    // --- COMPANION LOGIC ---
    // If companion is linked, force dashboard
    if (companionLinked) {
      return currentLocation == '/dashboard' ? null : '/dashboard';
    }
    // If companion authenticated but not linked, force pairing
    if (companionAuthenticated) {
      return currentLocation == '/companion/pairing' ? null : '/companion/pairing';
    }

    // --- ELDER LOGIC ---
    // If user manually navigates to companion paths, let them through
    const companionPaths = {
      '/companion/choice',
      '/companion/register',
      '/companion/login',
    };
    if (companionPaths.contains(currentLocation)) return null;

    // Prefer live Firestore data, fall back to controller state during stream gap
    final elderSource = (elderUser?.role == UserRole.elder) ? elderUser : null;
    final elderAutonomy = elderSource?.autonomy;
    final elderLinkCode = elderSource?.linkCode;

    bool isFullyOnboarded = false;

    if (elderAutonomy == AutonomyStatus.independent) {
      isFullyOnboarded = true;
    } else if (elderAutonomy == AutonomyStatus.dependent && elderLinkCode == null) {
      isFullyOnboarded = true;
    }

    // If elder is authenticated and fully onboarded, route to home
    if (elderAuthenticated && isFullyOnboarded) {
      return (currentLocation == '/splash' || currentLocation == '/onboarding') ? '/home' : null;
    }

    // Default: show onboarding
    if (currentLocation == '/onboarding') return null;
    return '/onboarding';
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
  });
}
