import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/features/onboarding/domain/elder_auth_controller.dart';
import 'package:quiet_companion/features/onboarding/domain/elder_auth_state.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(elderAuthControllerProvider);
    // Sin sesión todavía: primero se elige cómo entrar, y después el modo.
    final choosingAccess = authState.user == null;
    final isPending = authState.user?.autonomy == AutonomyStatus.dependent;
    final choosingMode = !choosingAccess && !isPending;
    final linkCode = authState.user?.linkCode;

    if (authState.status == AuthStatus.checking) {
      return const Scaffold(
        backgroundColor: AppTheme.elderBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    void backToAccessChoice() =>
        ref.read(elderAuthControllerProvider.notifier).backToAccessChoice();

    final page = Scaffold(
      backgroundColor: AppTheme.elderBackground,
      appBar: choosingMode
          ? AppBar(leading: BackButton(onPressed: backToAccessChoice))
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: AppTheme.contentMaxWidth(context)),
            child: _CenteredScroll(
              padding: EdgeInsets.all(AppTheme.screenPadding(context)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '¡Bienvenid@!',
                    style: TextStyle(
                      fontSize: AppTheme.fontHuge,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.elderTextPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    choosingAccess
                        ? '¿Cómo quieres entrar?'
                        : isPending
                            ? 'Dile este código a tu familiar:'
                            : '¿Cómo prefieres usar la aplicación?',
                    style: const TextStyle(
                      fontSize: AppTheme.fontLarge,
                      color: AppTheme.elderTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),
                  // Las dos vías tienen el mismo peso: entrar sin registrarse
                  // es una opción legítima, no un camino escondido.
                  if (choosingAccess) ...[
                    _ModeButton(
                      label: 'Entrar con Google',
                      onTap: () => ref
                          .read(elderAuthControllerProvider.notifier)
                          .signInWithGoogle(),
                    ),
                    const SizedBox(height: 24),
                    _ModeButton(
                      label: 'Entrar sin registrarme',
                      onTap: () => ref
                          .read(elderAuthControllerProvider.notifier)
                          .continueWithoutAccount(),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Con Google no pierdes nada si cambias de móvil. Sin '
                      'registrarte, al borrar la aplicación se empieza de cero.',
                      style: TextStyle(
                        fontSize: AppTheme.fontMedium,
                        color: AppTheme.elderTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    TextButton(
                      onPressed: () => context.push('/companion/choice'),
                      child: const Text('Soy el acompañante'),
                    ),
                  ],
                  // Aquí ya ha entrado como mayor: el acceso del familiar se
                  // queda en el paso anterior, al que lleva la flecha.
                  if (choosingMode) ...[
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
                  ],
                  if (isPending) ...[
                    Text(
                      linkCode ?? '',
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.elderTextPrimary,
                        letterSpacing: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Sin botón de "Continuar": al vincular, el servidor borra
                    // el linkCode, currentUserProvider emite y el router
                    // navega solo.
                    const Text(
                      'Tu familiar deberá introducir este código en su aplicación. '
                      'Cuando lo haga, esta pantalla cambiará sola.',
                      style: TextStyle(
                        fontSize: AppTheme.fontMedium,
                        color: AppTheme.elderTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    TextButton(
                      onPressed: () => ref
                          .read(elderAuthControllerProvider.notifier)
                          .cancelLinkedMode(),
                      child: const Text('Cancelar'),
                    ),
                  ],
                  if (authState.status == AuthStatus.error) ...[
                    const SizedBox(height: 24),
                    Text(
                      authState.errorMessage,
                      style: const TextStyle(
                        fontSize: AppTheme.fontButton,
                        color: AppTheme.elderEmergency,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Al elegir modo ya se ha entrado: la flecha, y también el botón atrás
    // del sistema, deshacen esa entrada por si el mayor se equivocó (quería
    // Google, o es el familiar) en vez de salir de la aplicación.
    return PopScope(
      canPop: !choosingMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) backToAccessChoice();
      },
      child: page,
    );
  }
}

/// Centrada mientras quepa y desplazable cuando no: con los botones del mayor,
/// la bienvenida no cabe entera en un móvil de 360×800.
class _CenteredScroll extends StatelessWidget {
  const _CenteredScroll({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - padding.vertical),
          ),
          child: child,
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
    return ElevatedButton(
      onPressed: onTap,
      child: Text(label),
    );
  }
}
