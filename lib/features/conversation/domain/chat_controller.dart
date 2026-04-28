import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/services/speech_service.dart';
import 'package:quiet_companion/core/services/tts_service.dart';
import 'chat_state.dart';
import 'package:quiet_companion/core/services/gemini_service.dart';

class ChatController extends StateNotifier<ChatState> {
  final GeminiService _geminiService;
  final SpeechService _speechService;
  final TtsService _ttsService;

  ChatController(this._geminiService, this._speechService, this._ttsService)
      : super(const ChatState());

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // 1. Begin thinking
    state = state.copyWith(
      status: ChatStatus.thinking,
      responseAI: 'Pensando...',
      userMessage: '',
    );

    try {
      // 2. Ask Gemini for a reply
      final response = await _geminiService.sendMessage(message);

      // 3. We have text, change status to TALKING
      state = state.copyWith(
        status: ChatStatus.talking,
        responseAI: response,
      );

      // 4. Play the audio.
      await _ttsService.speak(response);

      // 5. When it's done speaking, return to initial state
      // TODO call startListening() from here to open the mic automatically
      state = state.copyWith(status: ChatStatus.initial);
    } catch (e) {
      state = state.copyWith(
        status: ChatStatus.error,
        responseAI: 'Ups, ha habido un problema de conexión. ¿Puedes repetir?',
      );
    }
  }

  Future<void> startListening() async {
    // 1. Attempt to turn on the hardware
    final available = await _speechService.initiate();

    if (available) {
      // 2. Let the UI know that the mic is open
      state = state.copyWith(status: ChatStatus.listening);

      // 3. Start listening
      _speechService.beginListening((recognizedText) {
        state = state.copyWith(userMessage: recognizedText);
      });
    } else {
      // Handle the lack of permissions or hardware malfunction
      state = state.copyWith(
        status: ChatStatus.error,
        responseAI: 'No se ha podido acceder al micrófono.',
      );
    }
  }

  void stopListeningAndSend() {
    // 1. Turn off the hardware
    _speechService.stopListening();

    // 2. Catch last thing heard and send it to Gemini
    final finalText = state.userMessage;
    if (finalText.isNotEmpty) {
      sendMessage(finalText);
    } else {
      state = state.copyWith(status: ChatStatus.initial);
    }
  }
}

// Variable global
final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  final geminiService = GeminiService();
  final speechService = SpeechService();
  final ttsService = ref.watch(ttsServiceProvider);

  return ChatController(geminiService, speechService, ttsService);
});