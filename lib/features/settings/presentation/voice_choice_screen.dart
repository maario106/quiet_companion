import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/config/tts_voices.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/providers/tts_service_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/core/widgets/choice_option_tile.dart';
import 'package:quiet_companion/core/widgets/elder_screen_title.dart';
import 'package:quiet_companion/core/widgets/stop_speaking_on_exit.dart';

/// Elección de la voz: un toque elige, guarda y la dice. Tocar la elegida la repite.
class VoiceChoiceScreen extends ConsumerStatefulWidget {
  const VoiceChoiceScreen({super.key});

  @override
  ConsumerState<VoiceChoiceScreen> createState() => _VoiceChoiceScreenState();
}

class _VoiceChoiceScreenState extends ConsumerState<VoiceChoiceScreen> {
  /// Voz tocada aquí; manda sobre Firestore mientras la pantalla está abierta.
  String? _pendingVoice;

  bool _saving = false;
  String? _saveError;

  Future<void> _choose(TtsVoice voice) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null || _saving) return;

    final tts = ref.read(ttsServiceProvider);
    final prefs = user.preferences.copyWith(voice: voice.id);
    final alreadyChosen =
        voice.id == (_pendingVoice ?? user.preferences.voice);
    final previous = _pendingVoice;

    if (!alreadyChosen) {
      setState(() {
        _pendingVoice = voice.id;
        _saving = true;
        _saveError = null;
      });
    }

    // Se aplica ya, sin esperar a Firestore, para que la frase suene con esa voz.
    await tts.applyPreferences(prefs);
    unawaited(tts.speak(kVoicePreviewPhrase));
    if (alreadyChosen) return;

    try {
      await ref.read(authRepositoryProvider).updatePreferences(user.id, prefs);
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      // Si no se guarda, se vuelve a la voz anterior.
      unawaited(tts.applyPreferences(user.preferences));
      if (!mounted) return;
      setState(() {
        _pendingVoice = previous;
        _saving = false;
        _saveError = 'No se ha podido guardar. Inténtalo otra vez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final textScale = user.preferences.textSizeMultiplier;
    final chosen = _pendingVoice ?? ttsVoiceFor(user.preferences).id;

    return StopSpeakingOnExit(
      child: Scaffold(
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
                    ElderScreenTitle('Voz', textScale: textScale),
                    const SizedBox(height: 24),
                    Text(
                      '¿Con qué voz quieres que te hable? Toca una para oírla.',
                      style: TextStyle(
                        fontSize: AppTheme.fontMedium * textScale,
                        color: AppTheme.elderTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    for (final voice in ttsVoices) ...[
                      ChoiceOptionTile(
                        label: voice.id == chosen
                            ? '${voice.label} (elegida)'
                            : voice.label,
                        selected: voice.id == chosen,
                        textScale: textScale,
                        onTap: _saving ? null : () => _choose(voice),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_saveError != null)
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
