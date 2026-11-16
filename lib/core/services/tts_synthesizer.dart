import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:quiet_companion/core/config/functions_config.dart';
import 'package:quiet_companion/core/config/tts_config.dart';

/// Red de la síntesis, separada para testear [CloudTtsService] sin Firebase.
abstract interface class TtsSynthesizer {
  /// MP3 de [text] con la voz [voice]. Lanza si la síntesis falla.
  Future<Uint8List> synthesize(String text, {required String voice});
}

/// Sobre la callable synthesizeSpeech; solo envía el texto y la clave de voz.
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

    // El canal de plataforma entrega mapas sin tipar.
    final data = result.data;
    final audio = data is Map ? data['audioContent'] : null;
    if (audio is! String || audio.isEmpty) {
      throw const FormatException('Respuesta de síntesis sin audio.');
    }
    return base64Decode(audio);
  }
}
