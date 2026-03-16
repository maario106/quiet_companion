import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  SpeechService();

  Future<bool> initiate() async {
    bool available = await _speechToText.initialize(
      onStatus: (status) => print('🎤 Estado del micro: $status'),
      onError: (error) => print('Error del micro; $error'),
    );
    return available;
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