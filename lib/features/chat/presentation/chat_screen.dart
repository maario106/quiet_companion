import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quiet_companion/features/chat/domain/chat_controller.dart';
import 'package:quiet_companion/features/chat/domain/chat_state.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();

}

class _ChatScreenState extends ConsumerState<ChatScreen> {

  final TextEditingController _textController = TextEditingController();

  void _sendMessage() {
    final message = _textController.text.trim();
    if (message.isEmpty) return;

    _textController.clear();
    ref.read(chatControllerProvider.notifier).sendMessage(message);
  }

  // Buena práctica: limpiar el controlador de texto al destruir la pantalla
  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final isThinking = chatState.status == ChatStatus.thinking;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Acompañante'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pantalla de Foco: Texto Gigante de la IA
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Text(
                    chatState.responseAI,
                    style: const TextStyle(
                      fontSize: 32, // Letra gigante por accesibilidad
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Input y botón de enviar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: "Escribe tu mensaje aquí...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    enabled: !isThinking,
                    // 5. Volvemos a llamar a nuestra función interna
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 60,
                  width: 60,
                  child: FloatingActionButton(
                    // 5. Volvemos a llamar a nuestra función interna
                    onPressed: isThinking ? null : _sendMessage,
                    child: isThinking
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.send, size: 30),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}