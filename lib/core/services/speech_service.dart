import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  SpeechService();

  Future<bool> initiate() async {
    return await _speechToText.initialize();
  }

  void beginListening(Function(String) onResult){
    _speechToText.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
      },
      localeId: 'es_ES',
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  void stopListening() {
    _speechToText.stop();
  }

  bool get isListening => _speechToText.isListening;
}

final speechServiceProvider = Provider<SpeechService>((ref) => SpeechService());