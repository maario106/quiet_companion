import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/user_model.dart';
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
    _elderName = elderName;
    _geminiService.startSession(elderName);
  }

  /// Nombre con el que está sembrada la sesión del modelo. Se guarda para no
  /// resembrarla dos veces por el mismo nombre: `startSession` borra el hilo
  /// de la conversación, y hacerlo de más le costaría al mayor el contexto de
  /// lo que acaba de contar.
  String? _elderName;

  /// Lleva un nombre nuevo al modelo sin reconstruir el controlador. Lo usan
  /// las dos vías por las que aparece: `guardarNombre` en mitad de un turno y
  /// el familiar escribiéndolo desde su panel.
  void updateElderName(String? name) {
    if (name == _elderName) return;
    _elderName = name;
    _geminiService.startSession(name);
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
      if (!mounted) return;

      // If Gemini called guardarNombre, persist the name before speaking.
      final nombreToSave = geminiResponse.nombreToSave;
      if (nombreToSave != null && _uid != null) {
        await _authRepository.updateName(_uid, nombreToSave);
        if (!mounted) return;
        // Resiembra la sesión para que el modelo deje de preguntar. Va por
        // `updateElderName` y no por `startSession` directamente para que la
        // emisión de currentUserProvider que viene detrás no la repita.
        updateElderName(nombreToSave);
      }

      final replyText =
          geminiResponse.text ?? 'No se ha podido generar una respuesta.';

      state = state.copyWith(
        status: ChatStatus.talking,
        responseAI: replyText,
      );

      await _ttsService.speak(replyText);
      if (!mounted) return;

      state = state.copyWith(status: ChatStatus.initial);
    } catch (e) {
      // Asignar `state` en un notifier ya desechado lanza, y lanzaría otra vez
      // dentro de este mismo catch: el error saldría del turno sin recoger.
      if (!mounted) return;
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
  // `select` sobre el uid, no `watch` del UserModel entero.
  //
  // Observar el modelo completo ataba la vida del controlador a CUALQUIER
  // cambio del documento del mayor. Y el turno que enseña su nombre cambia el
  // documento: `guardarNombre` escribe `name`, Firestore emite (dos veces: la
  // escritura local y el eco del servidor) y el provider destruía el
  // controlador **en mitad de `sendMessage`**. La respuesta de ese turno moría
  // con él y la pantalla se reiniciaba con el estado nuevo: el nombre se
  // guardaba, pero el turno que lo guardó no llegaba nunca a la interfaz.
  //
  // Con `select`, solo un cambio de identidad reconstruye. El nombre lo
  // refresca el propio controlador (`startSession`) al guardarlo, y la
  // cabecera lo lee de `currentUserProvider` por su cuenta. De paso, mover un
  // ajuste de accesibilidad tampoco tumba ya la conversación.
  final uid = ref.watch(currentUserProvider.select((u) => u.valueOrNull?.id)) ??
      FirebaseAuth.instance.currentUser?.uid;
  // `read`, no `watch`: solo siembra la sesión inicial de Gemini.
  final elderName = ref.read(currentUserProvider).valueOrNull?.name;

  final controller = ChatController(
    ref.watch(geminiServiceProvider),
    ref.watch(speechServiceProvider),
    ref.watch(ttsServiceProvider),
    ref.watch(authRepositoryProvider),
    uid,
    elderName,
  );

  // El nombre ya no reconstruye el controlador, así que se le entrega en vivo.
  // Cubre los dos casos que el `select` deja fuera: que el documento cargue
  // después de construirse el chat, y que sea el familiar quien escriba el
  // nombre desde su panel mientras el mayor conversa.
  ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (previous, next) {
    controller.updateElderName(next.valueOrNull?.name);
  });

  return controller;
});
