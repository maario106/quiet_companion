import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/config/conversation_config.dart';
import 'package:quiet_companion/core/models/conversation_settings.dart';
import 'package:quiet_companion/core/models/elder_memory.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';
import 'package:quiet_companion/core/providers/conversation_closer_provider.dart';
import 'package:quiet_companion/core/providers/conversation_providers.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/providers/intentional_background_exit_provider.dart';
import 'package:quiet_companion/core/providers/tts_service_provider.dart';
import 'package:quiet_companion/core/services/conversation_closer.dart';
import 'package:quiet_companion/core/services/gemini_service.dart';
import 'package:quiet_companion/core/services/speech_service.dart';
import 'package:quiet_companion/core/services/tts_service.dart';
import 'package:quiet_companion/features/onboarding/data/auth_repository.dart';
import 'chat_state.dart';

typedef TimerFactory = Timer Function(Duration duration, void Function() onFire);

class ChatController extends StateNotifier<ChatState> {
  final GeminiService _geminiService;
  final SpeechService _speechService;
  final TtsService _ttsService;
  final AuthRepository _authRepository;
  final ConversationCloser _closer;
  final String? _uid;
  final bool Function() _isIntentionalExit;
  final DateTime Function() _now;
  final TimerFactory _startTimer;

  ChatController(
    this._geminiService,
    this._speechService,
    this._ttsService,
    this._authRepository,
    this._uid,
    String? elderName, {
    ConversationCloser closer = const NoopConversationCloser(),
    bool consentGranted = false,
    ConversationSettings settings = const ConversationSettings(),
    ElderMemory? memory,
    bool Function()? isIntentionalExit,
    DateTime Function()? now,
    TimerFactory? startTimer,
  })  : _closer = closer,
        _consentGranted = consentGranted,
        _settings = settings,
        _memory = memory,
        _isIntentionalExit = isIntentionalExit ?? (() => false),
        _now = now ?? DateTime.now,
        _startTimer = startTimer ?? Timer.new,
        super(const ChatState()) {
    _elderName = elderName;
    _startSession();
  }

  /// Nombre con el que está sembrada la sesión del modelo. Se guarda para no
  /// resembrarla dos veces por el mismo nombre: cada resiembra es una sesión
  /// nueva del modelo, y hacerlo de más es trabajo y latencia sin motivo.
  String? _elderName;

  // ── Conversación en curso (ADR-0028) ────────────────────────────────────
  //
  // Una conversación empieza con el primer turno tras un cierre y termina
  // tras [ConversationSettings.inactivity] sin turnos o al salir la app a
  // segundo plano. Sus turnos viven solo aquí, en memoria: al cerrarse se
  // entregan a [_closer] y se olvidan.

  final List<ConversationTurn> _turns = [];
  DateTime? _startedAt;
  DateTime? _lastActivityAt;
  Timer? _inactivityTimer;

  /// La conversación anterior se cerró: el siguiente turno empieza sesión
  /// nueva del modelo. Se resiembra en el primer turno y no en el cierre para
  /// que dé tiempo a llegar a lo que el análisis acaba de aprender.
  bool _sessionStale = false;

  bool _consentGranted;
  ConversationSettings _settings;
  ElderMemory? _memory;

  /// Número de lo último que ha tomado la pantalla: un turno, una escucha o
  /// una lectura en voz alta. Una voz cortada termina tarde, cuando ya ha
  /// empezado otra cosa, y solo devuelve la pantalla a reposo si lo que la
  /// lanzó sigue siendo lo último (ADR-0035).
  int _epoch = 0;

  /// Siembra la sesión del modelo con el nombre y, si hay consentimiento, lo
  /// que recuerda del mayor (ADR-0032). Con [keepThread], la sesión nueva
  /// recibe los turnos de la conversación en curso y no pierde el hilo.
  void _startSession({bool keepThread = false}) {
    _geminiService.startSession(
      _elderName,
      memory: _consentGranted ? _memory : null,
      history: keepThread ? List.unmodifiable(_turns) : const [],
    );
  }

  /// Lleva un nombre nuevo al modelo sin reconstruir el controlador. Lo usan
  /// las dos vías por las que aparece: `guardarNombre` en mitad de un turno y
  /// el familiar escribiéndolo desde su panel.
  void updateElderName(String? name) {
    if (name == _elderName) return;
    _elderName = name;
    _startSession(keepThread: true);
  }

  /// Consentimiento vigente, entregado en vivo (ADR-0023). Sin él, una
  /// conversación se cierra igual pero no se envía nada (ADR-0030), y la
  /// memoria deja de inyectarse.
  void updateConsent(bool granted) {
    if (granted == _consentGranted) return;
    _consentGranted = granted;
    _refreshSessionWhenIdle();
  }

  /// Lo que el asistente recuerda, entregado en vivo. **Nunca** reinicia una
  /// conversación en curso (ADR-0032): se usa en la siguiente.
  void updateMemory(ElderMemory? memory) {
    _memory = memory;
    _refreshSessionWhenIdle();
  }

  /// Sin conversación en curso, la próxima empezará con sesión nueva; con
  /// conversación, se espera a que termine.
  void _refreshSessionWhenIdle() {
    if (_startedAt == null) _sessionStale = true;
  }

  /// Plazos vigentes, entregados en vivo. El nuevo plazo de inactividad se
  /// aplica en el siguiente temporizador.
  void updateSettings(ConversationSettings settings) => _settings = settings;

  /// Envía un turno del mayor y enseña la respuesta. Con [speakReply], además
  /// la lee en voz alta; un turno escrito no la lee (ADR-0035). Devuelve si
  /// el modelo respondió de verdad, y no con un mensaje de error de la app.
  Future<bool> sendMessage(String message, {bool speakReply = true}) async {
    if (message.trim().isEmpty) return false;

    final epoch = ++_epoch;
    _cancelInactivity();
    if (_sessionStale) {
      _sessionStale = false;
      _startSession();
    }

    state = state.copyWith(
      status: ChatStatus.thinking,
      responseAI: 'Pensando...',
      userMessage: '',
    );

    // La respuesta anterior aún puede estar sonando si el mayor escribe sin
    // esperar a que acabe: ya no viene a cuento y se corta.
    if (_ttsService.isSpeaking) await _silence();
    if (!mounted) return false;

    try {
      final geminiResponse = await _geminiService.sendMessage(message);
      if (!mounted) return false;

      final replyText =
          geminiResponse.text ?? 'No se ha podido generar una respuesta.';
      final answered = !geminiResponse.failed;

      // Una respuesta de error de la app no es conversación: sesgaría el
      // análisis hacia lo negativo. Se apunta antes de guardar el nombre para
      // que, si hay que resembrar, la sesión nueva incluya este turno.
      if (answered) {
        _recordTurn(ConversationRole.elder, message);
        _recordTurn(ConversationRole.assistant, replyText);
      }

      // If Gemini called guardarNombre, persist the name before speaking.
      final nombreToSave = geminiResponse.nombreToSave;
      if (nombreToSave != null && _uid != null) {
        await _authRepository.updateName(_uid, nombreToSave);
        if (!mounted) return answered;
        // Resiembra la sesión para que el modelo deje de preguntar. Va por
        // `updateElderName` y no por `startSession` directamente para que la
        // emisión de currentUserProvider que viene detrás no la repita.
        updateElderName(nombreToSave);
      }

      if (!speakReply) {
        state = state.copyWith(
          status: ChatStatus.initial,
          responseAI: replyText,
        );
        _armInactivity();
        return answered;
      }

      state = state.copyWith(
        status: ChatStatus.talking,
        responseAI: replyText,
      );

      await _ttsService.speak(replyText);
      if (!mounted || epoch != _epoch) return answered;

      state = state.copyWith(status: ChatStatus.initial);
      _armInactivity();
      return answered;
    } catch (e) {
      // Asignar `state` en un notifier ya desechado lanza, y lanzaría otra vez
      // dentro de este mismo catch: el error saldría del turno sin recoger.
      if (!mounted) return false;
      state = state.copyWith(
        status: ChatStatus.error,
        responseAI: 'Ups, ha habido un problema de conexión. ¿Puedes repetir?',
      );
      _armInactivity();
      return false;
    }
  }

  // ── Modo teclado (ADR-0035) ─────────────────────────────────────────────

  /// Turno escrito. Sigue el mismo camino que uno hablado, también para el
  /// análisis al cierre, pero la respuesta se enseña sin leerla: quien escribe
  /// puede estar donde no quiere que la app hable. Devuelve si el modelo
  /// respondió, para que la pantalla devuelva el texto al campo si no.
  Future<bool> sendTypedMessage(String text) async {
    if (!state.acceptsTypedTurn) return false;
    return sendMessage(text, speakReply: false);
  }

  /// Cambia entre hablar y escribir. Pasar al teclado con el micrófono
  /// abierto descarta lo que se estuviera oyendo: quien pide el teclado ha
  /// decidido no hablar, y enviarlo sería mandar algo que no ha confirmado.
  void setInputMode(InputMode mode) {
    if (mode == state.inputMode) return;
    if (state.status == ChatStatus.listening) {
      _speechService.cancelListening();
      state = state.copyWith(
        inputMode: mode,
        status: ChatStatus.initial,
        userMessage: '',
      );
      _armInactivity();
      return;
    }
    state = state.copyWith(inputMode: mode);
  }

  /// "Escuchar": lee en voz alta lo que hay en pantalla. Con él, el modo
  /// teclado recupera la voz cuando el mayor la quiere.
  Future<void> readReplyAloud() async {
    final previous = state.status;
    if (previous != ChatStatus.initial && previous != ChatStatus.error) return;
    final text = state.responseAI;
    if (text.trim().isEmpty) return;

    final epoch = ++_epoch;
    _cancelInactivity();
    state = state.copyWith(status: ChatStatus.talking);

    await _ttsService.speak(text);
    if (!mounted || epoch != _epoch) return;

    state = state.copyWith(status: previous);
    _armInactivity();
  }

  /// "Parar": corta la voz en curso. Lo que la lanzó vuelve a reposo por su
  /// cuenta en cuanto `speak` termina.
  void stopSpeaking() {
    if (state.status != ChatStatus.talking) return;
    unawaited(_silence());
  }

  /// Calla la voz de la app con tope y sin propagar errores: callarla ayuda,
  /// pero ni el micrófono ni un turno pueden quedar a merced de una llamada a
  /// la plataforma. Si no se pudo a tiempo, se sigue igual.
  Future<void> _silence() async {
    try {
      await _ttsService.stop().timeout(const Duration(seconds: 1));
    } catch (_) {
      // Se sigue igual.
    }
  }

  Future<void> startListening() async {
    // El mayor empieza a hablar: la conversación sigue viva.
    _cancelInactivity();
    ++_epoch;
    // Nunca se abre el micrófono con la voz de la app sonando: el reconocedor
    // la oiría a ella y no al mayor. Puede venir de otra pantalla ("Escuchar"
    // del consentimiento o de "Mi semana"), que no pasa por este controlador.
    await _silence();
    if (!mounted) return;
    final available = await _speechService.initiate();

    if (!available) {
      state = state.copyWith(
        status: ChatStatus.error,
        responseAI: 'No se ha podido acceder al micrófono.',
      );
      _armInactivity();
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
      _armInactivity();
      return;
    }
    state = state.copyWith(userMessage: message);
    sendMessage(message);
  }

  // ── Ciclo de vida de la app ─────────────────────────────────────────────

  /// La app pasa a segundo plano. Cierra la conversación mientras el proceso
  /// sigue vivo, que es cuando el envío tiene opciones de salir, salvo que el
  /// mayor haya ido al marcador de emergencia: entonces la conversación sigue
  /// y, si tarda en volver, la cierra el temporizador.
  void onAppPaused() {
    if (_isIntentionalExit()) return;
    endConversation(ConversationEndReason.background);
  }

  /// La app vuelve. Si el temporizador no pudo vencer mientras estaba fuera
  /// (proceso congelado), se comprueba aquí.
  void onAppResumed() {
    final last = _lastActivityAt;
    if (last == null || _startedAt == null) return;
    if (_now().difference(last) >= _settings.inactivity) {
      endConversation(ConversationEndReason.inactivity);
    }
  }

  /// Cierra la conversación en curso, si la hay. No espera ni avisa de nada:
  /// el mayor no debe notar el cierre.
  void endConversation(ConversationEndReason reason) {
    _cancelInactivity();
    final startedAt = _startedAt;
    if (startedAt == null) return;

    final turns = List<ConversationTurn>.unmodifiable(_turns);
    final elderTurns =
        turns.where((t) => t.role == ConversationRole.elder).length;

    _turns.clear();
    _startedAt = null;
    _lastActivityAt = null;
    _sessionStale = true;

    // Sin consentimiento no sale nada del teléfono, ni siquiera la actividad
    // (ADR-0030). El servidor lo comprueba otra vez por su cuenta.
    if (!_consentGranted) return;

    final conversation = ClosedConversation(
      startedAt: startedAt,
      endedAt: _now(),
      endReason: reason,
      elderTurns: elderTurns,
      turns: elderTurns >= kMinElderTurnsForAnalysis ? turns : null,
    );
    unawaited(_closer.close(conversation).catchError((Object _) {
      // Se pierde un análisis, no datos del mayor (aceptado en ADR-0015).
    }));
  }

  void _recordTurn(ConversationRole role, String text) {
    final now = _now();
    _startedAt ??= now;
    _lastActivityAt = now;
    _turns.add(ConversationTurn(role: role, text: text, at: now));
  }

  void _armInactivity() {
    _cancelInactivity();
    if (_startedAt == null) return;
    _lastActivityAt = _now();
    _inactivityTimer = _startTimer(
      _settings.inactivity,
      () => endConversation(ConversationEndReason.inactivity),
    );
  }

  void _cancelInactivity() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  @override
  void dispose() {
    _cancelInactivity();
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
  // `read`, no `watch`: solo siembran el estado inicial del controlador.
  final user = ref.read(currentUserProvider).valueOrNull;

  final controller = ChatController(
    ref.watch(geminiServiceProvider),
    ref.watch(speechServiceProvider),
    ref.watch(ttsServiceProvider),
    ref.watch(authRepositoryProvider),
    uid,
    user?.name,
    closer: ref.watch(conversationCloserProvider),
    consentGranted: user?.hasConversationConsent ?? false,
    settings: user?.effectiveConversationSettings ?? const ConversationSettings(),
    isIntentionalExit: () => ref.read(intentionalBackgroundExitProvider),
  );

  // Lo que el asistente recuerda del mayor (ADR-0032), también en vivo y sin
  // reconstruir: una memoria nueva se usa en la siguiente conversación.
  if (uid != null) {
    ref.listen<AsyncValue<ElderMemory?>>(
      elderMemoryProvider(uid),
      (previous, next) => controller.updateMemory(next.valueOrNull),
      fireImmediately: true,
    );
  }

  // Nada del documento reconstruye el controlador, así que se le entrega en
  // vivo (ADR-0023): el nombre, que puede cargar tarde o escribirlo el
  // familiar; y el consentimiento y los plazos, que pueden cambiar en mitad
  // de una conversación (ADR-0030, ADR-0034).
  ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (previous, next) {
    final user = next.valueOrNull;
    controller.updateElderName(user?.name);
    controller.updateConsent(user?.hasConversationConsent ?? false);
    controller.updateSettings(
        user?.effectiveConversationSettings ?? const ConversationSettings());
  });

  // El ciclo de vida se escucha aquí y no en una pantalla: la conversación
  // debe cerrarse aunque el mayor esté en Ajustes cuando sale de la app.
  final lifecycle = AppLifecycleListener(
    onPause: controller.onAppPaused,
    onResume: controller.onAppResumed,
  );
  ref.onDispose(lifecycle.dispose);

  return controller;
});
