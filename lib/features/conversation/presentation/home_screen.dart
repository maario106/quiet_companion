import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';

import 'package:quiet_companion/features/conversation/domain/chat_state.dart';
import 'package:quiet_companion/features/conversation/domain/chat_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // TODO botón de teclado de futuro
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the GLOBAL STATE
    final chatState = ref.watch(chatControllerProvider);
    final status = chatState.status;

    // Multiplicador de tamaño de texto controlado por el familiar desde el dashboard.
    final textScale = ref
            .watch(currentUserProvider)
            .valueOrNull
            ?.preferences
            .textSizeMultiplier ??
        1.0;

    // DYNAMIC VISUAL LOGIC: Ready the texts according to the State
    String title = '';
    String subtitle = '';

    switch(status) {
      case ChatStatus.initial:
        title = '¡Hola!'; // TODO: incluir nombre del usuario cuando UserModel tenga `name`
        subtitle = chatState.responseAI;
        break;
      case ChatStatus.listening:
        title = 'Te escucho...';
        subtitle = chatState.userMessage.isEmpty ? 'Habla ahora...' : chatState.userMessage;
        break;
      case ChatStatus.thinking:
        title = 'Pensando...';
        subtitle = 'Dame un segundo';
        break;
      case ChatStatus.talking:
        title = 'Respondiendo...';
        subtitle = chatState.responseAI;
        break;
      case ChatStatus.error:
        title = 'Ups...';
        subtitle = chatState.responseAI;
        break;
    }

    // VISUAL LOGIC BUTTON: Dynamic colors and icons
    Color micColor = AppTheme.primaryColor;
    IconData micIcon = Icons.mic_none;
    bool isWorking = false; // To avoid the button being clicked a million times

    if (status == ChatStatus.listening) {
      micColor = AppTheme.emergencyColor; // Rojo "grabando"
      micIcon = Icons.mic;
    } else if (status == ChatStatus.thinking) {
      micColor = Colors.orange;
      micIcon = Icons.hourglass_empty;
      isWorking = true;
    } else if (status == ChatStatus.talking) {
      micColor = Colors.green;
      micIcon = Icons.volume_up;
      isWorking = true;
    }

    return Scaffold(
      // Top bar transparente con iconos a los lados
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: () {
            // TODO Acción de home
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              // TODO Acción de perfil. No sé si hará algo
            },
          ),
          const SizedBox(width: 8), // Pequeño margen
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // DYNAMIC TEXTS (Reactive to RiverPod)
              // SALUDO
              Text(
                title,
                style: TextStyle(
                  fontSize: AppTheme.fontHuge * textScale,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // For longer AI responses.
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppTheme.fontLarge * textScale,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // BOTÓN GIGANTE DE MICRÓFONO
              GestureDetector(
                onTap: () {
                  if(isWorking) return;

                  if (status == ChatStatus.initial || status == ChatStatus.error) {
                    ref.read(chatControllerProvider.notifier).startListening();
                  } else if (status == ChatStatus.listening) {
                    ref.read(chatControllerProvider.notifier).stopListeningAndSend();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // TODO: comprobar qué pasa con withOpacity pq en TECNOSONRISAS tb salía así pero funcionaba
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    border: Border.all(
                      color: micColor,
                      width: status == ChatStatus.listening ? 8 : 4,
                    ),
                  ),
                  child: Icon(
                    micIcon,
                    size: 100,
                    color: micColor,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // BOTÓN DE TECLADO
              OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    side: const BorderSide(color: AppTheme.textSecondary, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                onPressed: () {
                  // TODO: Lógica para abrir el teclado
                   print("Abrir Teclado");
                },
                child: Text(
                  '¿Utilizar teclado?',
                  style: TextStyle(
                    fontSize: AppTheme.fontButton * textScale,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // BOTONES INFERIORES (Emergencia y Ajustes)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Emergencia (Rojo y cuadrado)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.emergencyColor, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.phone_in_talk),
                      color: AppTheme.emergencyColor,
                      iconSize: 40,
                      padding: const EdgeInsets.all(16),
                      onPressed: () {
                        // TODO: Llamar al contacto que tenga configurado el user
                      },
                    ),
                  ),
                  // Ajustes
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primaryColor, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      color: AppTheme.primaryColor,
                      iconSize: 40,
                      padding: const EdgeInsets.all(16),
                      onPressed: () {
                        // TODO: Rerouting a la pantalla de ajustes.
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}