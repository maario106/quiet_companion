import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/services/cloud_tts_service.dart';
import 'package:quiet_companion/core/services/device_tts_service.dart';
import 'package:quiet_companion/core/services/tts_audio_player.dart';
import 'package:quiet_companion/core/services/tts_service.dart';
import 'package:quiet_companion/core/services/tts_synthesizer.dart';

/// Provider del [TtsService] de la app: voz de nube con respaldo al motor del
/// dispositivo. Quien lo consume (chat de voz, pantalla de emergencia) habla
/// contra la interfaz y no sabe cuál de las dos está sonando.
///
/// Escucha [currentUserProvider] y propaga las preferencias del mayor
/// (volumen, velocidad) cada vez que cambian en Firestore. El servicio no
/// guarda estado de preferencias: es el provider quien orquesta la
/// propagación.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = CloudTtsService(
    synthesizer: FunctionsTtsSynthesizer(),
    player: JustAudioTtsPlayer(),
    fallback: DeviceTtsService(),
  );

  // fireImmediately: el usuario suele estar ya cargado cuando se crea el
  // servicio; sin esto, la primera locución de la sesión sonaría con los
  // valores de fábrica del reproductor y no con los del mayor.
  ref.listen<AsyncValue<UserModel?>>(
    currentUserProvider,
    (previous, next) {
      final prefs = next.valueOrNull?.preferences;
      if (prefs == null) return;
      service.applyPreferences(prefs);
    },
    fireImmediately: true,
  );

  // dispose() es Future<void>; envolverlo en una closure deja explícito que es
  // fire-and-forget (el callback de onDispose es void Function()).
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
