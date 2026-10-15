import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/config/settings_rows.dart';
import 'package:quiet_companion/core/providers/conversation_providers.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/core/widgets/elder_button.dart';
import 'package:quiet_companion/features/conversation/domain/chat_controller.dart';
import 'package:quiet_companion/features/conversation/domain/chat_state.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Foco del campo del modo teclado: tenerlo es tener el teclado del sistema.
  final FocusNode _inputFocus = FocusNode(debugLabel: 'Campo del modo teclado');

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _closeKeyboard() => _inputFocus.unfocus();

  /// Envía lo escrito (ADR-0035). El campo se vacía al enviar y el teclado del
  /// sistema se cierra para que la respuesta se lea a pantalla completa. Si el
  /// turno falla, el texto vuelve al campo: no hay que escribirlo otra vez.
  Future<void> _sendTyped() async {
    final text = _textController.text.trim();
    if (text.isEmpty || !ref.read(chatControllerProvider).acceptsTypedTurn) {
      return;
    }
    _textController.clear();
    _closeKeyboard();

    final answered =
        await ref.read(chatControllerProvider.notifier).sendTypedMessage(text);
    if (!answered && mounted && _textController.text.isEmpty) {
      _textController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final status = chatState.status;

    ref.listen<ChatState>(chatControllerProvider, (previous, next) {
      if (next.status == ChatStatus.talking &&
          next.responseAI != previous?.responseAI) {
        _scrollToBottom();
      }
    });

    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final elderName = currentUser?.name;
    // Misma función pura que decide qué renderiza SettingsScreen: el botón
    // solo se muestra si hay al menos una fila de ajustes visible. Un botón
    // que abre una pantalla vacía es tan malo como uno que no responde.
    final showSettings =
        currentUser != null && visibleSettingsRows(currentUser).isNotEmpty;
    final textScale = currentUser?.preferences.textSizeMultiplier ?? 1.0;
    // "Mi semana" solo aparece cuando hay algo que enseñar: consentimiento y
    // al menos una conversación analizada (ADR-0033). Sin consentimiento ni
    // siquiera se abre la consulta.
    final showMyWeek = currentUser != null &&
        currentUser.hasConversationConsent &&
        (ref
                .watch(conversationRecordsProvider(currentUser.id))
                .valueOrNull
                ?.any((record) => record.isAnalyzed) ??
            false);

    final typing = chatState.inputMode == InputMode.keyboard;
    // Con el teclado del sistema abierto el mayor está escribiendo: se aparta
    // lo que no sirve para eso y la respuesta conserva el sitio.
    final composing = typing && MediaQuery.viewInsetsOf(context).bottom > 0;

    final padding = AppTheme.screenPadding(context);
    final maxWidth = AppTheme.contentMaxWidth(context);
    final micSize = AppTheme.micButtonSize(context);
    final micIconSz = AppTheme.micIconSize(context);

    String? statusLabel;
    String subtitle = '';

    switch (status) {
      case ChatStatus.initial:
        statusLabel = null;
        subtitle = chatState.responseAI;
      case ChatStatus.listening:
        statusLabel = 'Te escucho...';
        subtitle = chatState.userMessage.isEmpty
            ? 'Habla ahora...'
            : chatState.userMessage;
      case ChatStatus.thinking:
        statusLabel = 'Pensando...';
        subtitle = 'Dame un segundo';
      case ChatStatus.talking:
        statusLabel = 'Respondiendo...';
        subtitle = chatState.responseAI;
      case ChatStatus.error:
        statusLabel = 'Ups...';
        subtitle = chatState.responseAI;
    }

    Color micColor = AppTheme.elderPrimary;
    IconData micIcon = Icons.mic_none;
    bool isWorking = false;

    if (status == ChatStatus.listening) {
      micColor = AppTheme.elderEmergency;
      micIcon = Icons.mic;
    } else if (status == ChatStatus.thinking) {
      micColor = AppTheme.elderThinking;
      micIcon = Icons.hourglass_empty;
      isWorking = true;
    } else if (status == ChatStatus.talking) {
      micColor = AppTheme.elderTalking;
      micIcon = Icons.volume_up;
      isWorking = true;
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          elderName != null ? 'Hola, $elderName' : 'Hola',
          style: TextStyle(
            fontSize: AppTheme.fontMedium * textScale,
            fontWeight: FontWeight.bold,
            color: AppTheme.elderTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (statusLabel != null) ...[
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: AppTheme.fontLarge * textScale,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.elderTextPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: AppTheme.fontLarge * textScale,
                          color: AppTheme.elderTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (typing && !composing) ...[
                    _ReadAloudButton(
                      status: status,
                      textScale: textScale,
                      onRead: () => ref
                          .read(chatControllerProvider.notifier)
                          .readReplyAloud(),
                      onStop: () => ref
                          .read(chatControllerProvider.notifier)
                          .stopSpeaking(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Mic button, or the text field in keyboard mode
                  if (typing)
                    _TypedInput(
                      // Con clave porque al abrirse y cerrarse el teclado se
                      // quitan y se ponen botones a su alrededor: sin ella,
                      // Flutter rehace el campo cada vez, que pierde el foco
                      // y la conexión con el teclado del sistema.
                      key: const ValueKey('typed-input'),
                      controller: _textController,
                      focusNode: _inputFocus,
                      textScale: textScale,
                      canSend: chatState.acceptsTypedTurn,
                      onSend: _sendTyped,
                    )
                  else
                    GestureDetector(
                      onTap: () {
                        if (isWorking) return;
                        if (status == ChatStatus.initial ||
                            status == ChatStatus.error) {
                          ref
                              .read(chatControllerProvider.notifier)
                              .startListening();
                        } else if (status == ChatStatus.listening) {
                          ref
                              .read(chatControllerProvider.notifier)
                              .stopListeningAndSend();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: micSize,
                        height: micSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: micColor.withValues(alpha: 0.08),
                          boxShadow: status == ChatStatus.initial
                              ? [
                                  BoxShadow(
                                    color: AppTheme.elderPrimary
                                        .withValues(alpha: 0.18),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ]
                              : [],
                          border: Border.all(
                            color: micColor,
                            width: status == ChatStatus.listening ? 6 : 3,
                          ),
                        ),
                        child: Icon(micIcon, size: micIconSz, color: micColor),
                      ),
                    ),

                  SizedBox(height: typing ? 20 : 32),

                  if (showMyWeek && !composing) ...[
                    ElderButton(
                      label: 'Mi semana',
                      icon: Icons.calendar_view_week,
                      secondary: true,
                      textScale: textScale,
                      onPressed: () => context.push('/my-week'),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Bottom action row: emergency | keyboard or voice | settings
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ActionButton(
                        icon: Icons.phone_in_talk,
                        color: AppTheme.elderEmergency,
                        // Siempre visible: el 112 está disponible aunque no
                        // haya contacto configurado, así que la pantalla de
                        // emergencia nunca está vacía.
                        onPressed: () => context.push('/emergency'),
                      ),
                      _InputModeButton(
                        typing: typing,
                        textScale: textScale,
                        onPressed: () => ref
                            .read(chatControllerProvider.notifier)
                            .setInputMode(
                                typing ? InputMode.voice : InputMode.keyboard),
                      ),
                      // Mientras se escribe, Ajustes no hace falta y su sitio,
                      // justo encima del teclado, es para cerrarlo. Mismo
                      // tamaño: la fila no se ensancha con la letra grande.
                      if (composing)
                        _ActionButton(
                          icon: Icons.keyboard_hide_outlined,
                          color: AppTheme.elderPrimary,
                          tooltip: 'Cerrar teclado',
                          onPressed: _closeKeyboard,
                        )
                      else
                        Visibility(
                          visible: showSettings,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: _ActionButton(
                            icon: Icons.settings_outlined,
                            color: AppTheme.elderPrimary,
                            onPressed: () => context.push('/settings'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final Color color;

  /// `null` lo deshabilita: se pinta apagado y no responde.
  final VoidCallback? onPressed;

  /// Nombre del botón para el lector de pantalla.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final shade = onPressed == null
        ? AppTheme.elderTextSecondary.withValues(alpha: 0.4)
        : color;
    return Container(
      decoration: BoxDecoration(
        color: shade.withValues(alpha: 0.06),
        border: Border.all(color: shade, width: 2),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: shade.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        color: color,
        disabledColor: shade,
        tooltip: tooltip,
        iconSize: 40,
        padding: const EdgeInsets.all(20),
        onPressed: onPressed,
      ),
    );
  }
}

/// Cambia entre hablar y escribir (ADR-0035). Enseña el modo al que lleva, no
/// el que está activo: "¿Teclado?" mientras se habla, "¿Hablar?" mientras se
/// escribe.
class _InputModeButton extends StatelessWidget {
  const _InputModeButton({
    required this.typing,
    required this.textScale,
    required this.onPressed,
  });

  final bool typing;
  final double textScale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 80, minHeight: 80),
      child: Material(
        color: AppTheme.elderTextSecondary.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: InkWell(
          onTap: onPressed,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: AppTheme.elderTextSecondary, width: 1.5),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(typing ? Icons.mic_none : Icons.keyboard_outlined,
                    size: 26, color: AppTheme.elderTextSecondary),
                const SizedBox(height: 4),
                Text(
                  typing ? '¿Hablar?' : '¿Teclado?',
                  style: TextStyle(
                    fontSize: 14 * textScale,
                    color: AppTheme.elderTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Escuchar" del modo teclado: la respuesta a un turno escrito no se lee
/// sola, se lee si el mayor lo pide. Mientras suena, el mismo botón la para.
class _ReadAloudButton extends StatelessWidget {
  const _ReadAloudButton({
    required this.status,
    required this.textScale,
    required this.onRead,
    required this.onStop,
  });

  final ChatStatus status;
  final double textScale;
  final VoidCallback onRead;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final speaking = status == ChatStatus.talking;
    return ElderButton(
      label: speaking ? 'Parar' : 'Escuchar',
      icon: speaking ? Icons.stop : Icons.volume_up,
      secondary: true,
      textScale: textScale,
      onPressed: switch (status) {
        ChatStatus.talking => onStop,
        ChatStatus.initial || ChatStatus.error => onRead,
        ChatStatus.thinking || ChatStatus.listening => null,
      },
    );
  }
}

/// Campo de texto y botón de enviar del modo teclado (ADR-0035), con la letra
/// y los mínimos de toque del resto de la interfaz del mayor.
class _TypedInput extends StatelessWidget {
  const _TypedInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.textScale,
    required this.canSend,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final double textScale;

  /// La conversación admite ahora un turno escrito (no hay otro en vuelo).
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final fontSize = AppTheme.fontMedium * textScale;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            // Quien pulsa "¿Teclado?" quiere escribir ya: el teclado del
            // sistema se abre sin un toque más.
            autofocus: true,
            // Tocar fuera del campo cierra el teclado, también al arrastrar
            // para leer la respuesta. En el móvil Flutter no lo hace solo.
            onTapOutside: (_) => focusNode.unfocus(),
            minLines: 1,
            maxLines: 3,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.send,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => onSend(),
            style: TextStyle(
              fontSize: fontSize,
              color: AppTheme.elderTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Escribe aquí',
              hintStyle: TextStyle(
                fontSize: fontSize,
                color: AppTheme.elderTextSecondary,
              ),
              filled: true,
              fillColor: AppTheme.elderSurface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Sin texto no hay nada que enviar: el botón se apaga en vez de no
        // responder. Cuenta como parte del campo: tocarlo no es tocar fuera,
        // y el teclado no se cierra si no se envía nada.
        TextFieldTapRegion(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => _ActionButton(
              icon: Icons.send,
              color: AppTheme.elderPrimary,
              tooltip: 'Enviar',
              onPressed:
                  canSend && value.text.trim().isNotEmpty ? onSend : null,
            ),
          ),
        ),
      ],
    );
  }
}
