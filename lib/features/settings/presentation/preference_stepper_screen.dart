import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/config/preference_scales.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/providers/tts_service_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/core/widgets/elder_screen_title.dart';

/// Subpantalla de todas las escalas de accesibilidad: "Más"/"Menos" y el
/// nombre del peldaño. Cada pulsación se guarda sola.
class PreferenceStepperScreen extends ConsumerStatefulWidget {
  const PreferenceStepperScreen({super.key, required this.scale});

  final PreferenceScale scale;

  @override
  ConsumerState<PreferenceStepperScreen> createState() =>
      _PreferenceStepperScreenState();
}

class _PreferenceStepperScreenState
    extends ConsumerState<PreferenceStepperScreen> {
  /// Peldaño elegido aquí; manda sobre Firestore mientras la pantalla está abierta.
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
      // Si no se guarda, se vuelve atrás.
      setState(() {
        _pendingIndex = previousIndex;
        _saving = false;
        _saveError = 'No se ha podido guardar. Inténtalo otra vez.';
      });
    }
  }

  /// Habla con las preferencias ya guardadas; el servicio se lee al pulsar.
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
    // La pantalla entera se pinta con el valor elegido: es la vista previa.
    final previewPrefs = scale.atIndex(user.preferences, index);
    final textScale = previewPrefs.textSizeMultiplier;

    return Scaffold(
      appBar: AppBar(),
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
                  ElderScreenTitle(scale.title, textScale: textScale),
                  const SizedBox(height: 24),
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
                    // Deshabilitado en el extremo, nunca oculto.
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
                    // Texto fijo y no SnackBar, que se va antes de leerlo.
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

/// Slug de preferencia inexistente (enlace profundo escrito a mano).
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
