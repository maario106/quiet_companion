import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/providers/intentional_background_exit_provider.dart';
import 'package:quiet_companion/core/providers/tts_service_provider.dart';
import 'package:quiet_companion/core/services/emergency_call_service.dart';
import 'package:quiet_companion/core/services/speech_service.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';

/// Pantalla de llamada de emergencia. Siempre ofrece el 112; el contacto, si lo hay.
class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen>
    with WidgetsBindingObserver {
  // Aviso persistente si falló el último intento de marcar (nunca un SnackBar).
  bool _dialFailed = false;

  static const String _dialErrorText = 'Este dispositivo no puede hacer llamadas';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Se cancela la escucha sin enviar lo dicho: su respuesta sonaría encima.
      ref.read(speechServiceProvider).cancelListening();
      _announce();
    });
  }

  Future<void> _announce() async {
    final tts = ref.read(ttsServiceProvider);
    // Primero parar la locución en curso, luego hablar.
    await tts.stop();
    await tts.speak('Elige a quién llamar');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(intentionalBackgroundExitProvider.notifier).state = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _dial(String phoneE164) async {
    // Salir al marcador es una salida deliberada, no un abandono.
    ref.read(intentionalBackgroundExitProvider.notifier).state = true;
    final launched =
        await ref.read(emergencyCallServiceProvider).dial(phoneE164);
    if (launched) return;

    ref.read(intentionalBackgroundExitProvider.notifier).state = false;
    if (!mounted) return;
    setState(() => _dialFailed = true);
    final tts = ref.read(ttsServiceProvider);
    await tts.stop();
    await tts.speak(_dialErrorText);
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final contact = user?.emergencyContact;
    final textScale = user?.preferences.textSizeMultiplier ?? 1.0;

    // Atrás hace lo mismo que "Cancelar".
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        // Sin AppBar: la única salida es "Cancelar" / atrás.
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: AppTheme.contentMaxWidth(context)),
              child: Padding(
                padding: EdgeInsets.all(AppTheme.screenPadding(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'Elige a quién llamar',
                      style: TextStyle(
                        fontSize: AppTheme.fontLarge * textScale,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.elderTextPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_dialFailed) ...[
                      const SizedBox(height: 24),
                      // Aviso persistente, dentro de la propia pantalla.
                      Text(
                        _dialErrorText,
                        style: TextStyle(
                          fontSize: AppTheme.fontMedium * textScale,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.emergency112,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const Spacer(),
                    if (contact != null) ...[
                      _CallButton(
                        label: 'Llamar a ${contact.name}',
                        color: AppTheme.emergencyContactCall,
                        icon: Icons.phone,
                        textScale: textScale,
                        onPressed: () => _dial(contact.phone),
                      ),
                      // Separación grande entre las dos llamadas.
                      const SizedBox(height: 40),
                    ],
                    _CallButton(
                      label: 'Llamar al 112',
                      semanticsLabel: 'Llamar a emergencias, uno uno dos',
                      color: AppTheme.emergency112,
                      icon: Icons.emergency,
                      textScale: textScale,
                      onPressed: () => _dial(kEmergencyNumber),
                    ),
                    const Spacer(),
                    // Zona inferior, menos destacada y lejos de los botones de llamada.
                    Semantics(
                      button: true,
                      label: 'Cancelar',
                      child: TextButton(
                        onPressed: _cancel,
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            fontSize: AppTheme.fontButton * textScale,
                            color: AppTheme.elderTextSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.label,
    this.semanticsLabel,
    required this.color,
    required this.icon,
    required this.textScale,
    required this.onPressed,
  });

  final String label;

  /// Etiqueta para TalkBack (que "112" no se lea "ciento doce").
  final String? semanticsLabel;
  final Color color;
  final IconData icon;
  final double textScale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppTheme.emergencyButtonMinHeight,
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            minimumSize: const Size(
              double.infinity,
              AppTheme.emergencyButtonMinHeight,
            ),
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 40 * textScale),
          label: ExcludeSemantics(
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.fontMedium * textScale,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
