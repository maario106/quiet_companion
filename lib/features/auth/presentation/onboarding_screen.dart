import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/features/auth/domain/auth_controller.dart';
import 'package:quiet_companion/features/auth/domain/auth_state.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isPending = authState.user?.autonomy == AutonomyStatus.dependent;
    final linkCode = authState.user?.linkCode;

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
                  ? 'Dile este código a tu familiar: '
                  : '¿Cómo prefieres usar la aplicación?',
                style: const TextStyle(
                  fontSize: AppTheme.fontLarge,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 60),

              // VISTA 1: MODO SELECCIÓN
              if (!isPending) ...[
                
              ]
            ],
          )
        )
      )
    );
  }
}