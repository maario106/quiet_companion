import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/config/conversation_config.dart';
import 'package:quiet_companion/core/models/conversation_settings.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/core/providers/conversation_closer_provider.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/providers/intentional_background_exit_provider.dart';
import 'package:quiet_companion/core/providers/tts_service_provider.dart';
import 'package:quiet_companion/core/services/conversation_closer.dart';
import 'package:quiet_companion/core/services/gemini_service.dart';
import 'package:quiet_companion/core/services/speech_service.dart';
import 'package:quiet_companion/core/services/tts_service.dart';
import 'chat_state.dart';

typedef TimerFactory = Timer Function(Duration duration, void Function() onFire);

class ChatController extends StateNotifier<ChatState> {
  final GeminiService _geminiService;
  final SpeechService _speechService;
  final TtsService _ttsService;
  final ConversationCloser _closer;
  final bool Function() _isIntentionalExit;
  final DateTime Function() _now;
  final TimerFactory _startTimer;

  ChatController(
    this._geminiService,
    this._speechService,
    this._ttsService, {
    ConversationCloser closer = const NoopConversationCloser(),
    bool consentGranted = false,
    ConversationSettings settings = const ConversationSettings(),
    Duration? listenPause,
    bool Function()? isIntentionalExit,
    DateTime Function()? now,
    TimerFactory? startTimer,
  })  : _closer = closer,
        _consentGranted = consentGranted,
        _settings = settings,
        _listenPause = listenPause ?? const UserPreferences().listenPause,
        _isIntentionalExit = isIntentionalExit ?? (() => false),
        _now = now ?? DateTime.now,
        _startTimer = startTimer ?? Timer.new,
        super(const ChatState());

  // Conversación en curso: sus turnos solo viven aquí, en memoria, y al cerrarse
  // se entregan a [_closer] y se olvidan.

  final List<ConversationTurn> _turns = [];
  DateTime? _startedAt;
  DateTime? _lastActivityAt;
  Timer? _inactivityTimer;

  bool _consentGranted;
  ConversationSettings _settings;

  /// Silencio tras el que se da por terminado lo que dice el mayor.
  Duration _listenPause;

  /// Número de lo último que ha tomado la pantalla; una voz cortada que termina
  /// tarde solo vuelve a reposo si sigue siendo lo último.
  int _epoch = 0;

  /// Consentimiento vigente. Sin él, la conversación se cierra sin enviar nada.
  void updateConsent(bool granted) => _consentGranted = granted;

  /// Plazos vigentes; se aplican en el siguiente temporizador.
  void updateSettings(ConversationSettings settings) => _settings = settings;

  /// Pausa de escucha vigente; se aplica en el siguiente turno.
  void updateListenPause(Duration pause) => _listenPause = pause;

  /// Envía un turno y enseña la respuesta; con [speakReply], además la lee.
  /// Devuelve si respondió el modelo y no un error de la app.
  Future<bool> sendMessage(String message, {bool speakReply = true}) async {
    if (message.trim().isEmpty) return false;

    final epoch = ++_epoch;
    _cancelInactivity();

    state = state.copyWith(
      status: ChatStatus.thinking,
      responseAI: 'Pensando...',
      userMessage: '',
    );

    // Si la respuesta anterior aún suena, se corta.
    if (_ttsService.isSpeaking) await _silence();
    if (!mounted) return false;

    try {
      final geminiResponse = await _geminiService.sendMessage(
        message,
        history: List.unmodifiable(_turns),
      );
      if (!mounted) return false;

      final replyText =
          geminiResponse.text ?? 'No se ha podido generar una respuesta.';
      final answered = !geminiResponse.failed;

      // Un error de la app no es conversación: no entra en el análisis.
      if (answered) {
        _recordTurn(ConversationRole.elder, message);
        _recordTurn(ConversationRole.assistant, replyText);
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
      // En un notifier desechado, asignar state lanzaría.
      if (!mounted) return false;
      state = state.copyWith(
        status: ChatStatus.error,
        responseAI: 'Ups, ha habido un problema de conexión. ¿Puedes repetir?',
      );
      _armInactivity();
      return false;
    }
  }

  // Modo teclado

  /// Turno escrito: igual que uno hablado, pero la respuesta no se lee en voz alta.
  Future<bool> sendTypedMessage(String text) async {
    if (!state.acceptsTypedTurn) return false;
    return sendMessage(text, speakReply: false);
  }

  /// Cambia entre hablar y escribir. Pasar al teclado descarta lo que se estaba oyendo.
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

  /// "Escuchar": lee en voz alta la respuesta en pantalla.
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

  /// "Parar": corta la voz en curso.
  void stopSpeaking() {
    if (state.status != ChatStatus.talking) return;
    unawaited(_silence());
  }

  /// Calla la voz de la app con tope y sin propagar errores.
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
    // Nunca se abre el micrófono con la voz de la app sonando.
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
        // Vienen de temporizadores: el controlador puede haberse reconstruido.
        if (!mounted || state.status != ChatStatus.listening) return;
        state = state.copyWith(userMessage: text);
      },
      onFinal: (text) {
        if (!mounted || state.status != ChatStatus.listening) return;
        _submit(text);
      },
      silenceTimeout: _listenPause,
    );
  }

  /// Cierre manual del turno. Envía por el mismo onFinal que el cierre por silencio.
  void stopListeningAndSend() {
    // Si el silencio ya cerró el turno, no se envía dos veces.
    if (state.status != ChatStatus.listening) return;
    // Sin turno abierto (lo canceló otra pantalla) no llegará onFinal: vuelve a reposo.
    if (!_speechService.finishListening()) _submit('');
  }

  /// Único punto de envío, compartido por el cierre automático y el manual.
  void _submit(String text) {
    final message = text.trim();
    if (message.isEmpty) {
      // Turno vacío: vuelve a reposo sin llamar al modelo.
      state = state.copyWith(status: ChatStatus.initial, userMessage: '');
      _armInactivity();
      return;
    }
    state = state.copyWith(userMessage: message);
    sendMessage(message);
  }

  // Ciclo de vida de la app

  /// La app pasa a segundo plano: cierra la conversación, salvo si el mayor ha
  /// ido al marcador de emergencia.
  void onAppPaused() {
    if (_isIntentionalExit()) return;
    endConversation(ConversationEndReason.background);
  }

  /// La app vuelve; comprueba el temporizador por si no pudo vencer fuera.
  void onAppResumed() {
    final last = _lastActivityAt;
    if (last == null || _startedAt == null) return;
    if (_now().difference(last) >= _settings.inactivity) {
      endConversation(ConversationEndReason.inactivity);
    }
  }

  /// Cierra la conversación en curso, si la hay, sin que el mayor lo note.
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

    // Sin consentimiento no sale nada del teléfono.
    if (!_consentGranted) return;

    final conversation = ClosedConversation(
      startedAt: startedAt,
      endedAt: _now(),
      endReason: reason,
      elderTurns: elderTurns,
      turns: elderTurns >= kMinElderTurnsForAnalysis ? turns : null,
    );
    unawaited(_closer.close(conversation).catchError((Object _) {
      // Se pierde el análisis, no datos del mayor.
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
    // Nunca dejar el micrófono abierto detrás de un controlador muerto.
    _speechService.cancelListening();
    super.dispose();
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  // Solo un cambio de cuenta reconstruye el controlador; el resto llega por listen.
  ref.watch(currentUserProvider.select((u) => u.valueOrNull?.id));
  // read: solo siembran el estado inicial.
  final user = ref.read(currentUserProvider).valueOrNull;

  final controller = ChatController(
    ref.watch(geminiServiceProvider),
    ref.watch(speechServiceProvider),
    ref.watch(ttsServiceProvider),
    closer: ref.watch(conversationCloserProvider),
    consentGranted: user?.hasConversationConsent ?? false,
    settings: user?.effectiveConversationSettings ?? const ConversationSettings(),
    listenPause: user?.preferences.listenPause,
    isIntentionalExit: () => ref.read(intentionalBackgroundExitProvider),
  );

  // Consentimiento, plazos y pausa de escucha pueden cambiar a mitad de conversación.
  ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (previous, next) {
    final user = next.valueOrNull;
    controller.updateConsent(user?.hasConversationConsent ?? false);
    controller.updateSettings(
        user?.effectiveConversationSettings ?? const ConversationSettings());
    controller.updateListenPause(
        (user?.preferences ?? const UserPreferences()).listenPause);
  });

  // Aquí y no en una pantalla: la conversación se cierra aunque el mayor esté en Ajustes.
  final lifecycle = AppLifecycleListener(
    onPause: controller.onAppPaused,
    onResume: controller.onAppResumed,
  );
  ref.onDispose(lifecycle.dispose);

  return controller;
});
