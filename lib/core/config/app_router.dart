import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
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

    _ref.listen<AsyncValue<User?>>(firebaseAuthUserProvider, (_, next) {
      if (next.valueOrNull == null) {
        _ref.read(companionAuthControllerProvider.notifier).signOut();
      }
      notifyListeners();
    });

    _ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (_, next) {
      _elderUser = next.valueOrNull;
      notifyListeners();
    });

    _elderState = _ref.read(elderAuthControllerProvider);
    _companionState = _ref.read(companionAuthControllerProvider);
    _elderUser = _ref.read(currentUserProvider).valueOrNull;
  }

  final Ref _ref;
  late AuthState _elderState;
  late CompanionAuthState _companionState;
  UserModel? _elderUser;

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

    // Prefer live Firestore data (currentUserProvider) for routing decisions.
    // Fall back to controller state during the gap before the stream first emits.
    // Role guard ensures a companion's UserModel is never used for elder routing.
    final elderSource = (_elderUser?.role == UserRole.elder) ? _elderUser : _elderState.user;
    final elderAutonomy = elderSource?.autonomy;
    final elderLinkCode = elderSource?.linkCode;

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
        path: '/emergency',
        // Fullscreen dialog: ruta completa, sin barrera de diálogo que sea
        // superficie de error en mitad de una emergencia.
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: EmergencyScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          // Anidada bajo /settings aunque el widget viva en features/emergency:
          // la jerarquía de rutas refleja la navegación del usuario, no el
          // sistema de ficheros.
          GoRoute(
            path: 'emergency-contact',
            builder: (context, state) => const EmergencyContactSetupScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/companion/choice',
        builder: (context, state) => Theme(
          data: AppTheme.companionTheme,
          child: const CompanionAuthChoiceScreen(),
        ),
      ),
      GoRoute(
        path: '/companion/register',
        builder: (context, state) => Theme(
          data: AppTheme.companionTheme,
          child: const CompanionRegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/companion/login',
        builder: (context, state) => Theme(
          data: AppTheme.companionTheme,
          child: const CompanionLoginScreen(),
        ),
      ),
      GoRoute(
        path: '/companion/pairing',
        builder: (context, state) => Theme(
          data: AppTheme.companionTheme,
          child: const EnterPairingCodeScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => Theme(
          data: AppTheme.companionTheme,
          child: const DashboardScreen(),
        ),
      ),
    ],
  );
});
