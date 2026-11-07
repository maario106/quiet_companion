import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';

class CompanionAuthChoiceScreen extends ConsumerWidget {
  const CompanionAuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = AppTheme.screenPadding(context);
    final maxWidth = AppTheme.contentMaxWidth(context);

    return Scaffold(
      // Registro y acceso se apilan encima (`push`) y vuelven con `pop`: así
      // la flecha y el botón atrás del sistema deshacen los pasos en orden.
      // Con `go`, la pila se quedaría solo con la pantalla de destino y la
      // flecha no tendría adónde volver.
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Acceso para acompañantes',
                    style: TextStyle(
                      fontSize: AppTheme.companionFontTitle,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.companionTextPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vincula tu cuenta para ayudar a un ser querido.',
                    style: TextStyle(
                      fontSize: AppTheme.companionFontBody,
                      color: AppTheme.companionTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  FilledButton(
                    onPressed: () => context.push('/companion/register'),
                    child: const Text('Crear una cuenta nueva'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.push('/companion/login'),
                    child: const Text('Ya tengo una cuenta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
