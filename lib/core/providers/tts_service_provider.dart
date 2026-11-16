import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/services/cloud_tts_service.dart';
import 'package:quiet_companion/core/services/device_tts_service.dart';
import 'package:quiet_companion/core/services/tts_audio_player.dart';
import 'package:quiet_companion/core/services/tts_service.dart';
import 'package:quiet_companion/core/services/tts_synthesizer.dart';

/// Voz de nube con respaldo al motor del dispositivo. Aplica las preferencias
/// del mayor cada vez que cambian.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = CloudTtsService(
    synthesizer: FunctionsTtsSynthesizer(),
    player: JustAudioTtsPlayer(),
    fallback: DeviceTtsService(),
  );

  // fireImmediately: la primera locución ya suena con las preferencias del mayor.
  ref.listen<AsyncValue<UserModel?>>(
    currentUserProvider,
    (previous, next) {
      final prefs = next.valueOrNull?.preferences;
      if (prefs == null) return;
      service.applyPreferences(prefs);
    },
    fireImmediately: true,
  );

  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
