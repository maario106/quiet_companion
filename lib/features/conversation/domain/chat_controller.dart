import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/services/gemini_service.dart';
import 'package:quiet_companion/core/services/speech_service.dart';
import 'package:quiet_companion/core/services/tts_service.dart';
import 'package:quiet_companion/features/onboarding/data/auth_repository.dart';
import 'chat_state.dart';

class ChatController extends StateNotifier<ChatState> {
  final GeminiService _geminiService;
  final SpeechService _speechService;
  final TtsService _ttsService;
  final AuthRepository _authRepository;
  final String? _uid;

  ChatController(
    this._geminiService,
    this._speechService,
    this._ttsService,
    this._authRepository,
    this._uid,
    String? elderName,
  ) : super(const ChatState()) {
    _geminiService.startSession(elderName);
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    state = state.copyWith(
      status: ChatStatus.thinking,
      responseAI: 'Pensando...',
      userMessage: '',
    );

    try {
      final geminiResponse = await _geminiService.sendMessage(message);

      // If Gemini called guardarNombre, persist the name before speaking.
      final nombreToSave = geminiResponse.nombreToSave;
      if (nombreToSave != null && _uid != null) {
        await _authRepository.updateName(_uid, nombreToSave);
        // Refresh the session so the model no longer asks for the name.
        // currentUserProvider will emit the updated UserModel automatically;
        // the provider will rebuild this controller with the new name on the
        // next state change. Refreshing here covers the current session turn.
        _geminiService.startSession(nombreToSave);
      }

      final replyText =
          geminiResponse.text ?? 'No se ha podido generar una respuesta.';

      state = state.copyWith(
        status: ChatStatus.talking,
        responseAI: replyText,
      );

      await _ttsService.speak(replyText);

      state = state.copyWith(status: ChatStatus.initial);
    } catch (e) {
      state = state.copyWith(
        status: ChatStatus.error,
        responseAI: 'Ups, ha habido un problema de conexión. ¿Puedes repetir?',
      );
    }
  }

  Future<void> startListening() async {
    final available = await _speechService.initiate();

    if (available) {
      state = state.copyWith(status: ChatStatus.listening);

      _speechService.beginListening((recognizedText) {
        state = state.copyWith(userMessage: recognizedText);
      });
    } else {
      state = state.copyWith(
        status: ChatStatus.error,
        responseAI: 'No se ha podido acceder al micrófono.',
      );
    }
  }

  void stopListeningAndSend() {
    _speechService.stopListening();

    final finalText = state.userMessage;
    if (finalText.isNotEmpty) {
      sendMessage(finalText);
    } else {
      state = state.copyWith(status: ChatStatus.initial);
    }
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  final uid = currentUser?.id ?? FirebaseAuth.instance.currentUser?.uid;
  final elderName = currentUser?.name;

  return ChatController(
    ref.watch(geminiServiceProvider),
    ref.watch(speechServiceProvider),
    ref.watch(ttsServiceProvider),
    ref.watch(authRepositoryProvider),
    uid,
    elderName,
  );
});
