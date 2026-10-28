import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:quiet_companion/core/config/functions_config.dart';
import 'package:quiet_companion/core/config/tts_config.dart';

/// Costura de red de la síntesis: separada de [CloudTtsService] para que la
/// orquestación (troceado, prefetch, cancelación) se pueda testear sin
/// Firebase ni red.
abstract interface class TtsSynthesizer {
  /// Devuelve el MP3 de [text] dicho con la voz de clave [voice]. Lanza si la
  /// síntesis falla; el llamante decide la política de respaldo.
  Future<Uint8List> synthesize(String text, {required String voice});
}

/// Implementación real sobre la callable `synthesizeSpeech`.
///
/// El cliente solo envía el texto y la clave de la voz: el nombre real de la
/// voz, el idioma y el ritmo son constantes de servidor. Así ninguna
/// credencial de Google Cloud llega al binario (RNF-8) y desde el dispositivo
/// solo se puede elegir entre las voces de la lista.
class FunctionsTtsSynthesizer implements TtsSynthesizer {
  FunctionsTtsSynthesizer({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: kFunctionsRegion);

  final FirebaseFunctions _functions;

  @override
  Future<Uint8List> synthesize(String text, {required String voice}) async {
    final result = await _functions
        .httpsCallable(kSynthesizeSpeechCallable)
        .call<dynamic>(<String, dynamic>{'text': text, 'voice': voice});

    // El canal de plataforma entrega mapas sin tipar; se lee defensivamente
    // en vez de castear a Map<String, dynamic>, que falla en Android.
    final data = result.data;
    final audio = data is Map ? data['audioContent'] : null;
    if (audio is! String || audio.isEmpty) {
      throw const FormatException('Respuesta de síntesis sin audio.');
    }
    return base64Decode(audio);
  }
}
