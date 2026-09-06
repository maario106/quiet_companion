import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/providers/tts_service_provider.dart';
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

    if (!available) {
      state = state.copyWith(
        status: ChatStatus.error,
        responseAI: 'No se ha podido acceder al micrófono.',
      );
      return;
    }

    state = state.copyWith(status: ChatStatus.listening, userMessage: '');

    _speechService.beginListening(
      onPartial: (text) {
        // Los dos callbacks llegan desde temporizadores: el controlador puede
        // haberse reconstruido (currentUserProvider) mientras el mayor hablaba.
        if (!mounted || state.status != ChatStatus.listening) return;
        state = state.copyWith(userMessage: text);
      },
      onFinal: (text) {
        if (!mounted || state.status != ChatStatus.listening) return;
        _submit(text);
      },
    );
  }

  /// Cierre manual del turno: el mayor pulsa el botón sin esperar a la pausa.
  void stopListeningAndSend() {
    // Si el silencio ya cerró el turno, `status` ya no es `listening` y este
    // camino no debe enviar por segunda vez.
    if (state.status != ChatStatus.listening) return;
    _submit(_speechService.stopListening());
  }

  /// Único punto de envío, compartido por el cierre automático y el manual.
  void _submit(String text) {
    final message = text.trim();
    if (message.isEmpty) {
      // Turno en vacío (nadie habló): se vuelve a reposo sin molestar al LLM
      // ni enseñar un error, que no lo hay.
      state = state.copyWith(status: ChatStatus.initial, userMessage: '');
      return;
    }
    state = state.copyWith(userMessage: message);
    sendMessage(message);
  }

  @override
  void dispose() {
    // Nunca dejar el reconocedor abierto detrás de un controlador muerto: es
    // el micrófono del mayor y el provider es de toda la app.
    _speechService.cancelListening();
    super.dispose();
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
