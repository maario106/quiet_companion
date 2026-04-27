import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/features/conversation/presentation/home_screen.dart';
import 'package:quiet_companion/features/dashboard/presentation/dashboard_screen.dart';
import 'package:quiet_companion/features/onboarding/domain/elder_auth_controller.dart';
import 'package:quiet_companion/features/onboarding/domain/companion_auth_controller.dart';
import 'package:quiet_companion/features/onboarding/domain/elder_auth_state.dart';
import 'package:quiet_companion/features/onboarding/domain/companion_auth_state.dart';
import 'package:quiet_companion/features/onboarding/presentation/companion_auth_choice_screen.dart';
import 'package:quiet_companion/features/onboarding/presentation/companion_login_screen.dart';
import 'package:quiet_companion/features/onboarding/presentation/companion_register_screen.dart';
import 'package:quiet_companion/features/onboarding/presentation/enter_pairing_code_screen.dart';
import 'package:quiet_companion/features/onboarding/presentation/onboarding_screen.dart';
import 'package:quiet_companion/features/onboarding/presentation/splash_screen.dart';



class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(elderAuthControllerProvider, (_, next) {
      _elderState = next;
      notifyListeners();
    });

    _ref.listen<CompanionAuthState>(companionAuthControllerProvider, (_, next) {
      _companionState = next;
      notifyListeners();
    });

    _elderState = _ref.read(elderAuthControllerProvider);
    _companionState = _ref.read(companionAuthControllerProvider);
  }

  final Ref _ref;
  late AuthState _elderState;
  late CompanionAuthState _companionState;

  static const _companionPaths = {
    '/companion/choice',
    '/companion/register',
    '/companion/login',
  };

  String? redirect(BuildContext context, GoRouterState routerState) {
    final elderStatus = _elderState.status;
    final companionStatus = _companionState.status;
    final location = routerState.matchedLocation;

    // Si la app está arrancando (login anónimo del mayor), esperamos.
    if (elderStatus == AuthStatus.checking) return null;

    // --- LÓGICA DEL FAMILIAR ---
    // Si el familiar ya está logueado y vinculado, forzamos el dashboard
    if (companionStatus == CompanionAuthStatus.linked) {
      return location == '/dashboard' ? null : '/dashboard';
    }
    // Si el familiar hizo login pero aún NO ha metido el código, lo forzamos a la pantalla del código
    if (companionStatus == CompanionAuthStatus.authenticated) {
      return location == '/companion/pairing' ? null : '/companion/pairing';
    }

    // --- LÓGICA DEL MAYOR ---
    // Si el usuario navega a mano a las pantallas de login del familiar, le dejamos pasar
    if (_companionPaths.contains(location)) return null;

    final elderAutonomy = _elderState.user?.autonomy;
    final elderLinkCode = _elderState.user?.linkCode;

    bool isFullyOnboarded = false;

    if (elderAutonomy == AutonomyStatus.independent) {
      isFullyOnboarded = true;
    } else if (elderAutonomy == AutonomyStatus.dependent && elderLinkCode == null) {
      isFullyOnboarded = true;
    }

    // Si el mayor ha elegido "Independiente" o "Vincular", va a la HomeScreen
    if (elderStatus == AuthStatus.authenticated && isFullyOnboarded) {
      return (location == '/splash' || location == '/onboarding') ? '/home' : null;
    }

    // Por defecto (arranque limpio), mostramos el Onboarding
    if (location == '/onboarding') return null;
    return '/onboarding';
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/companion/choice',
        builder: (context, state) => const CompanionAuthChoiceScreen(),
      ),
      GoRoute(
        path: '/companion/register',
        builder: (context, state) => const CompanionRegisterScreen(),
      ),
      GoRoute(
        path: '/companion/login',
        builder: (context, state) => const CompanionLoginScreen(),
      ),
      GoRoute(
        path: '/companion/pairing',
        builder: (context, state) => const EnterPairingCodeScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
});
