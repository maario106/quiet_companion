import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/config/preference_scales.dart';
import 'package:quiet_companion/core/config/route_redirect.dart';
import 'package:quiet_companion/core/config/settings_rows.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/consent_prompt_deferred_provider.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/features/conversation/presentation/home_screen.dart';
import 'package:quiet_companion/features/dashboard/presentation/conversation_detail_screen.dart';
import 'package:quiet_companion/features/dashboard/presentation/dashboard_screen.dart';
import 'package:quiet_companion/features/emergency/presentation/emergency_contact_setup_screen.dart';
import 'package:quiet_companion/features/emergency/presentation/emergency_screen.dart';
import 'package:quiet_companion/features/my_week/presentation/my_week_screen.dart';
import 'package:quiet_companion/features/settings/presentation/account_screen.dart';
import 'package:quiet_companion/features/settings/presentation/preference_stepper_screen.dart';
import 'package:quiet_companion/features/settings/presentation/settings_screen.dart';
import 'package:quiet_companion/features/settings/presentation/voice_choice_screen.dart';
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
import 'package:quiet_companion/features/privacy/presentation/choice_screen.dart';
import 'package:quiet_companion/features/privacy/presentation/consent_screen.dart';
import 'package:quiet_companion/features/privacy/presentation/conversation_privacy_screen.dart';

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

    _ref.listen<bool>(consentPromptDeferredProvider, (_, next) {
      _consentDeferred = next;
      notifyListeners();
    });

    _elderState = _ref.read(elderAuthControllerProvider);
    _companionState = _ref.read(companionAuthControllerProvider);
    _elderUser = _ref.read(currentUserProvider).valueOrNull;
    _consentDeferred = _ref.read(consentPromptDeferredProvider);
  }

  final Ref _ref;
  late AuthState _elderState;
  late CompanionAuthState _companionState;
  UserModel? _elderUser;
  bool _consentDeferred = false;

  /// Reúne las entradas de [routeRedirect].
  String? redirect(BuildContext context, GoRouterState routerState) {
    // Dato en vivo o, mientras no llega, el del controlador; solo si es de un mayor.
    final elderSource =
        (_elderUser?.role == UserRole.elder) ? _elderUser : _elderState.user;

    return routeRedirect(
      elderCheckingAuth: _elderState.status == AuthStatus.checking,
      companionLinked: _companionState.status == CompanionAuthStatus.linked,
      companionAuthenticated:
          _companionState.status == CompanionAuthStatus.authenticated,
      elderUser: elderSource,
      elderAuthenticated: _elderState.status == AuthStatus.authenticated,
      consentPromptDeferred: _consentDeferred,
      location: routerState.matchedLocation,
    );
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
      // El detalle cuelga de /consent para que el redirect lo deje pasar.
      GoRoute(
        path: '/consent',
        builder: (context, state) => const ConsentScreen(),
        routes: [
          GoRoute(
            path: 'details',
            builder: (context, state) =>
                const ConversationPrivacyScreen(manage: false),
          ),
        ],
      ),
      GoRoute(
        path: '/my-week',
        builder: (context, state) => const MyWeekScreen(),
      ),
      GoRoute(
        path: '/emergency',
        // Página completa, sin barrera de diálogo.
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: EmergencyScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          // Grupos del menú; un slug desconocido muestra error.
          GoRoute(
            path: 'group/:id',
            builder: (context, state) {
              final group = settingsGroupBySlug(state.pathParameters['id']);
              return group == null
                  ? const UnknownPreferenceScreen()
                  : SettingsScreen(group: group);
            },
          ),
          GoRoute(
            path: 'voice',
            builder: (context, state) => const VoiceChoiceScreen(),
          ),
          GoRoute(
            path: 'emergency-contact',
            builder: (context, state) => const EmergencyContactSetupScreen(),
          ),
          GoRoute(
            path: 'conversations',
            builder: (context, state) =>
                const ConversationPrivacyScreen(manage: true),
          ),
          GoRoute(
            path: 'companion-sharing',
            builder: (context, state) => const PrivacyChoiceScreen(
                choice: PrivacyChoice.companionSharing),
          ),
          GoRoute(
            path: 'conversation-wait',
            builder: (context, state) =>
                const PrivacyChoiceScreen(choice: PrivacyChoice.inactivity),
          ),
          GoRoute(
            path: 'conversation-retention',
            builder: (context, state) =>
                const PrivacyChoiceScreen(choice: PrivacyChoice.retention),
          ),
          GoRoute(
            path: 'account',
            builder: (context, state) => const AccountScreen(),
          ),
          // Una ruta para todas las escalas de accesibilidad.
          GoRoute(
            path: 'preference/:id',
            builder: (context, state) {
              final scale =
                  preferenceScaleBySlug(state.pathParameters['id']);
              return scale == null
                  ? const UnknownPreferenceScreen()
                  : PreferenceStepperScreen(scale: scale);
            },
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
        routes: [
          GoRoute(
            path: 'conversation/:id',
            builder: (context, state) => Theme(
              data: AppTheme.companionTheme,
              child: ConversationDetailScreen(
                conversationId: state.pathParameters['id'] ?? '',
              ),
            ),
          ),
        ],
      ),
    ],
  );
});
