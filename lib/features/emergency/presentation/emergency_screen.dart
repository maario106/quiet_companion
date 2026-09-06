import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/providers/intentional_background_exit_provider.dart';
import 'package:quiet_companion/core/providers/tts_service_provider.dart';
import 'package:quiet_companion/core/services/emergency_call_service.dart';
import 'package:quiet_companion/core/services/speech_service.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';

/// Pantalla de llamada de emergencia del mayor. Se presenta como fullscreen
/// dialog desde el botón rojo de HomeScreen. Siempre ofrece el 112; el botón
/// de contacto solo aparece si hay contacto configurado. El render es
/// idéntico venga el contacto de la vinculación o de configuración manual:
/// `source` solo afecta a la escritura, nunca a esta pantalla.
class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen>
    with WidgetsBindingObserver {
  // Estado de vista puro (no de negocio): si el último intento de marcar
  // falló, se muestra un aviso persistente — nunca un SnackBar, que
  // desaparece solo y es inútil para esta población.
  bool _dialFailed = false;

  static const String _dialErrorText = 'Este dispositivo no puede hacer llamadas';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Obligatorio al abrir: el marcador nativo compite por el AudioSession
      // y el TTS seguiría hablando encima. La conversación deja de tener
      // sentido en cuanto se abre esta UI, así que se para aquí, no al marcar.
      ref.read(speechServiceProvider).stopListening();
      _announce();
    });
  }

  Future<void> _announce() async {
    final tts = ref.read(ttsServiceProvider);
    // Primero parar la locución en curso, luego hablar — nunca simultáneo.
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
    // Señal para el futuro disparador de fin de sesión (pending.md §4):
    // salir al marcador es una salida deliberada, no un abandono.
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

    // El botón atrás del sistema se comporta exactamente igual que
    // "Cancelar", de forma explícita (no comportamiento por defecto).
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
                      // Separación grande: son acciones no equivalentes y no
                      // revocables; un fallo de puntería no puede convertir
                      // una en la otra.
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
                    // Zona visualmente distinta: inferior, menor tamaño y
                    // peso, sin relleno de color, nunca adyacente a los
                    // botones de llamada.
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

  /// Etiqueta para TalkBack cuando el texto visible no se debe leer tal cual
  /// (p. ej. que "112" no se lea "ciento doce").
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
          // El color del icono/texto viene del foregroundColor blanco del
          // ElevatedButtonTheme de elderTheme.
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
