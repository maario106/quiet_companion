import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/features/onboarding/domain/companion_auth_controller.dart';
import 'package:quiet_companion/features/onboarding/domain/elder_auth_controller.dart';
import 'package:quiet_companion/features/onboarding/domain/elder_auth_state.dart';
import 'package:quiet_companion/features/onboarding/domain/companion_auth_state.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(elderAuthControllerProvider);
    final isPending = authState.user?.autonomy == AutonomyStatus.dependent;
    final linkCode = authState.user?.linkCode;

    if (authState.status == AuthStatus.checking) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¡Bienvenid@!',
                style: TextStyle(
                  fontSize: AppTheme.fontHuge,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isPending
                    ? 'Dile este código a tu familiar:'
                    : '¿Cómo prefieres usar la aplicación?',
                style: const TextStyle(
                  fontSize: AppTheme.fontLarge,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              if (!isPending) ...[
                _ModeButton(
                  label: 'Usar por mi cuenta',
                  onTap: () => ref
                      .read(elderAuthControllerProvider.notifier)
                      .selectIndependentMode(),
                ),
                const SizedBox(height: 24),
                _ModeButton(
                  label: 'Vincular con mi familiar',
                  onTap: () => ref
                      .read(elderAuthControllerProvider.notifier)
                      .selectLinkedMode(),
                ),
                const SizedBox(height: 40),
                // Botón discreto para el familiar (No usa _ModeButton)
                TextButton(
                  onPressed: () => context.push('/companion/choice'),
                  child: const Text(
                    'Soy el acompañante',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTheme.fontMedium, // Tamaño legible pero no gigante
                      color: AppTheme.textSecondary,
                      decoration: TextDecoration.underline, // Indica claramente que es pulsable
                    ),
                  ),
                ),
              ],
              if (isPending) ...[
                Text(
                  linkCode ?? '',
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Tu familiar deberá introducir este código en su aplicación.',
                  style: TextStyle(
                    fontSize: AppTheme.fontMedium,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _ModeButton(
                  label: 'Continuar',
                  onTap: () {
                    ref.read(elderAuthControllerProvider.notifier).checkPairingStatus();
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => ref
                      .read(elderAuthControllerProvider.notifier)
                      .cancelLinkedMode(),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      fontSize: AppTheme.fontButton,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
              if (authState.status == AuthStatus.error) ...[
                const SizedBox(height: 24),
                Text(
                  authState.errorMessage,
                  style: const TextStyle(
                    fontSize: AppTheme.fontButton,
                    color: AppTheme.emergencyColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          padding: EdgeInsets.symmetric(vertical: 20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.fontButton,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}