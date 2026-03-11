import 'package:flutter/material.dart';
import 'package:quiet_companion/core/services/gemini_service.dart'; // Asegúrate de que esta ruta sea correcta

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // 1. Instanciamos nuestro nuevo servicio. La pantalla ya no sabe nada de API Keys ni de Prompts
  final GeminiService _geminiService = GeminiService();

  final TextEditingController _textController = TextEditingController();

  String _AIreply = "¡Hola! ¿De qué quieres que hablemos hoy?";
  bool _isThinking = false;

  // Ya no necesitamos el initState() ni inicializar el modelo aquí.

  // 2. Mantenemos nuestra función local para gestionar el "Estado" (lo que se ve en pantalla)
  Future<void> _sendMessage() async {
    final message = _textController.text.trim();
    if (message.isEmpty) return;

    // Actualizamos la UI para mostrar que estamos pensando y limpiamos la caja de texto
    setState(() {
      _isThinking = true;
      _AIreply = "Pensando...";
      _textController.clear();
    });

    // 3. ¡LA MAGIA! Le pasamos la pelota al servicio y esperamos su respuesta.
    final respuesta = await _geminiService.sendMessage(message);

    // 4. Actualizamos la UI con la respuesta final que nos ha devuelto el servicio
    setState(() {
      _AIreply = respuesta;
      _isThinking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    _AIreply,
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
                    enabled: !_isThinking,
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
                    onPressed: _isThinking ? null : _sendMessage,
                    child: _isThinking
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