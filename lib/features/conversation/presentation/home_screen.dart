import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
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

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    final isDependent = currentUser?.autonomy == AutonomyStatus.dependent;
    final textScale = currentUser?.preferences.textSizeMultiplier ?? 1.0;

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
      micColor = const Color(0xFFE07B20);
      micIcon = Icons.hourglass_empty;
      isWorking = true;
    } else if (status == ChatStatus.talking) {
      micColor = const Color(0xFF2D8A4E);
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

                  // Mic button
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

                  const SizedBox(height: 32),

                  // Bottom action row: emergency | keyboard | settings
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
                      _KeyboardButton(
                        textScale: textScale,
                        onPressed: () {},
                      ),
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
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color, width: 2),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        color: color,
        iconSize: 40,
        padding: const EdgeInsets.all(20),
        onPressed: onPressed,
      ),
    );
  }
}

class _KeyboardButton extends StatelessWidget {
  const _KeyboardButton({
    required this.textScale,
    required this.onPressed,
  });

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
                Icon(Icons.keyboard_outlined,
                    size: 26, color: AppTheme.elderTextSecondary),
                const SizedBox(height: 4),
                Text(
                  '¿Teclado?',
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