import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/config/preference_scales.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/providers/tts_service_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';

/// Subpantalla única para todas las escalas de accesibilidad del mayor. No hay
/// una pantalla por ajuste: la [PreferenceScale] que llega por la ruta lleva
/// título, pregunta, peldaños y nombres, así que añadir un cuarto ajuste no
/// añade una pantalla (ADR-0021).
///
/// Dos botones enormes, "Más"/"Menos", y el nombre del peldaño en grande. Sin
/// deslizador (exige arrastre, prohibido por `CLAUDE.md` §Accessibility) y sin
/// botón de guardar: cada pulsación se persiste sola. Un mayor que sube la
/// letra ya ha visto el resultado — pedirle que además confirme es pedirle que
/// confirme algo que ya está mirando.
class PreferenceStepperScreen extends ConsumerStatefulWidget {
  const PreferenceStepperScreen({super.key, required this.scale});

  final PreferenceScale scale;

  @override
  ConsumerState<PreferenceStepperScreen> createState() =>
      _PreferenceStepperScreenState();
}

class _PreferenceStepperScreenState
    extends ConsumerState<PreferenceStepperScreen> {
  /// Peldaño elegido aquí, mientras la pantalla está abierta. Manda sobre el
  /// valor de Firestore: si el familiar mueve su deslizador a la vez, el mayor
  /// que tiene el dedo en la pantalla no ve saltar su propia elección.
  int? _pendingIndex;

  bool _saving = false;
  String? _saveError;

  int _indexFor(UserPreferences prefs) =>
      _pendingIndex ?? widget.scale.indexOf(prefs);

  Future<void> _step(int delta) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null || _saving) return;

    final scale = widget.scale;
    final next = _indexFor(user.preferences) + delta;
    if (next < 0 || next >= scale.steps.length) return;

    final previousIndex = _pendingIndex;
    setState(() {
      _pendingIndex = next;
      _saving = true;
      _saveError = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .updatePreferences(user.id, scale.atIndex(user.preferences, next));
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      if (!mounted) return;
      // Retroceso honesto (mismo criterio que DashboardController): nunca dejar
      // en pantalla una letra más grande que no ha llegado a guardarse.
      setState(() {
        _pendingIndex = previousIndex;
        _saving = false;
        _saveError = 'No se ha podido guardar. Inténtalo otra vez.';
      });
    }
  }

  /// Habla con las preferencias ya guardadas: `ttsServiceProvider` las recoge
  /// de `currentUserProvider`, de modo que lo que suena es exactamente lo que
  /// el mayor acaba de elegir. El servicio se lee en la pulsación, no en el
  /// build, para no construir la voz de nube al abrir la pantalla.
  Future<void> _preview() async {
    final phrase = widget.scale.previewPhrase;
    if (phrase == null) return;
    await ref.read(ttsServiceProvider).speak(phrase);
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final user = ref.watch(currentUserProvider).valueOrNull;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final index = _indexFor(user.preferences);
    // Preferencias "como quedarían": el tamaño de esta misma pantalla sale de
    // aquí, así que subir la letra la agranda en el acto. La vista previa del
    // tamaño es la pantalla entera, no un párrafo de muestra.
    final previewPrefs = scale.atIndex(user.preferences, index);
    final textScale = previewPrefs.textSizeMultiplier;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          scale.title,
          style: TextStyle(
            fontSize: AppTheme.fontMedium * textScale,
            fontWeight: FontWeight.bold,
            color: AppTheme.elderTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: AppTheme.contentMaxWidth(context)),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.screenPadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    scale.question,
                    style: TextStyle(
                      fontSize: AppTheme.fontMedium * textScale,
                      color: AppTheme.elderTextPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // El mayor lee el nombre del peldaño, nunca el número.
                  Semantics(
                    liveRegion: true,
                    label: '${scale.title}: ${scale.labels[index]}',
                    child: ExcludeSemantics(
                      child: Text(
                        scale.labels[index],
                        style: TextStyle(
                          fontSize: AppTheme.fontLarge * textScale,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.elderPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _StepButton(
                    label: 'Más',
                    icon: Icons.add,
                    textScale: textScale,
                    // Deshabilitado en el extremo, nunca oculto: una fila de
                    // botones que cambia de tamaño desorienta más que un botón
                    // que no responde.
                    onPressed:
                        index < scale.steps.length - 1 ? () => _step(1) : null,
                  ),
                  const SizedBox(height: 20),
                  _StepButton(
                    label: 'Menos',
                    icon: Icons.remove,
                    textScale: textScale,
                    onPressed: index > 0 ? () => _step(-1) : null,
                  ),
                  if (scale.hasVoicePreview) ...[
                    const SizedBox(height: 32),
                    _StepButton(
                      label: 'Escuchar cómo suena',
                      icon: Icons.volume_up,
                      textScale: textScale,
                      onPressed: _preview,
                    ),
                  ],
                  if (_saveError != null) ...[
                    const SizedBox(height: 24),
                    // Texto fijo en la pantalla, no SnackBar: un aviso que se
                    // va solo es un aviso que el mayor no llega a leer.
                    Text(
                      _saveError!,
                      style: TextStyle(
                        fontSize: AppTheme.fontButton * textScale,
                        color: AppTheme.emergency112,
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
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.icon,
    required this.textScale,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final double textScale;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppTheme.emergencyButtonMinHeight,
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 40 * textScale),
        label: Text(
          label,
          style: TextStyle(fontSize: AppTheme.fontButton * textScale),
        ),
      ),
    );
  }
}

/// Pantalla de un `slug` de preferencia que no existe. Solo se alcanza por un
/// enlace profundo escrito a mano; existe para que eso no sea un crash.
class UnknownPreferenceScreen extends StatelessWidget {
  const UnknownPreferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Ese ajuste no existe.',
            style: const TextStyle(
              fontSize: AppTheme.fontMedium,
              color: AppTheme.elderTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
