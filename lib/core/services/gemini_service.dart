import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:quiet_companion/core/config/env.dart';
import 'package:quiet_companion/core/models/elder_memory.dart';
import 'package:quiet_companion/core/services/conversation_closer.dart';
import 'package:quiet_companion/core/utils/spanish_date.dart';

const _guardarNombreFn = 'guardarNombre';

/// Result of a single Gemini turn.
///
/// [text] is the text reply to speak/display.
/// [nombreToSave] is non-null when the model called `guardarNombre` — the
/// controller must persist this value and then call [startSession] again with
/// the updated name so the model stops asking.
class GeminiResponse {
  final String? text;
  final String? nombreToSave;

  /// La respuesta es un mensaje de error de la app, no del modelo. No es
  /// conversación: no entra en el búfer que se analiza al cerrar (ADR-0028).
  final bool failed;

  const GeminiResponse({this.text, this.nombreToSave, this.failed = false});
}

class GeminiService {
  ChatSession? _session;

  static final _tools = [
    Tool(functionDeclarations: [
      FunctionDeclaration(
        _guardarNombreFn,
        'Guarda el nombre del mayor en el sistema. Llama a esta función en '
        'cuanto el mayor confirme su nombre.',
        Schema.object(
          properties: {
            'nombre': Schema.string(
              description: 'Nombre del mayor, tal como él lo ha dicho.',
            ),
          },
          requiredProperties: ['nombre'],
        ),
      ),
    ]),
  ];

  static final _safetySettings = [
    SafetySetting(HarmCategory.harassment, HarmBlockThreshold.high),
    SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.high),
    SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.high),
    SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.high),
  ];

  /// Lo que el modelo sabe del mayor al empezar la conversación (ADR-0032).
  /// Vacío si no hay memoria: el bloque se omite, no se dice que no la hay.
  static String memoryContext(String? elderName, ElderMemory? memory,
      {DateTime? now}) {
    if (memory == null || memory.isEmpty) return '';
    final who = elderName ?? 'la persona con la que hablas';
    final buffer = StringBuffer();
    if (memory.facts.isNotEmpty) {
      buffer.writeln('Lo que sabes de $who:');
      for (final fact in memory.facts.entries) {
        buffer.writeln('- ${fact.key}: ${fact.value}');
      }
      buffer.writeln();
    }
    if (memory.recent.isNotEmpty) {
      buffer.writeln('De vuestras últimas conversaciones:');
      for (final item in memory.recent) {
        final when = relativeSpanish(item.endedAt, now ?? DateTime.now());
        buffer.writeln('- $when: ${item.summary}');
      }
      buffer.writeln();
    }
    buffer
      ..writeln('Usa esto con naturalidad y solo cuando venga a cuento. No lo '
          'recites, no digas que tienes notas y no preguntes lo que ya sabes.')
      ..writeln();
    return buffer.toString();
  }

  GenerativeModel _buildModel(String? elderName, ElderMemory? memory) {
    final nameContext = elderName != null
        ? 'Ya conoces el nombre del mayor: se llama $elderName. '
            'Salúdale por su nombre y NO vuelvas a preguntárselo.'
        : 'Aún no sabes el nombre del mayor. '
            'Pregúntaselo de forma natural en los primeros turnos de la conversación. '
            'En cuanto te lo diga, confirma el nombre y llama a la función '
            '`$_guardarNombreFn` con ese nombre.';

    return GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: Env.geminiApiKey,
      systemInstruction: Content.system(
        'Eres un acompañante virtual diseñado específicamente para conversar con personas mayores '
        'y combatir la soledad. Tu objetivo principal es hacer compañía, escuchar activamente, '
        'y ser muy respetuoso y cálido.\n\n'
        '$nameContext\n\n'
        '${memoryContext(elderName, memory)}'
        'REGLAS:\n'
        '1. Respuestas MUY breves (máximo 2 o 3 frases). Van a ser leídas por voz.\n'
        '2. Termina siempre con una pregunta sencilla para mantener la conversación.\n'
        '3. Actúa como un oyente humano empático. No digas que eres una IA.\n'
        '4. Si el usuario menciona problemas de salud, dile amablemente que lo consulte con su familia o médico.\n'
        '5. Si habla de hacerse daño, de no querer vivir o de que sería mejor no estar, responde con calma y cariño, '
        'no le quites importancia y anímale a hablarlo ahora con alguien de confianza. Recuérdale que puede llamar '
        'gratis al 024, a cualquier hora, y al 112 si está en peligro.',
      ),
      tools: _tools,
      safetySettings: _safetySettings,
    );
  }

  /// (Re)starts the chat session with updated name context.
  ///
  /// Call this once on first use and again whenever [elderName] changes (e.g.
  /// after persisting the name from a `guardarNombre` function call).
  ///
  /// [memory] es lo que el asistente recuerda del mayor (ADR-0032).
  /// [history] son los turnos de la conversación en curso: al resembrar a
  /// mitad de conversación, la sesión nueva no pierde el hilo (ADR-0023).
  void startSession(
    String? elderName, {
    ElderMemory? memory,
    List<ConversationTurn> history = const [],
  }) {
    _session = _buildModel(elderName, memory).startChat(history: [
      for (final turn in history)
        turn.role == ConversationRole.elder
            ? Content.text(turn.text)
            : Content.model([TextPart(turn.text)]),
    ]);
  }

  /// Sends a user message and returns the model's response.
  ///
  /// If the model calls `guardarNombre`, a [FunctionResponse] is automatically
  /// sent back so the conversation continues. The final spoken text and the
  /// name to persist are both returned in [GeminiResponse].
  Future<GeminiResponse> sendMessage(String text) async {
    if (_session == null) startSession(null);
    final session = _session!;

    try {
      final response = await session.sendMessage(Content.text(text));

      String? nombreToSave;
      String? replyText = response.text;

      final calls = response.functionCalls.toList();
      if (calls.isNotEmpty) {
        for (final call in calls) {
          if (call.name == _guardarNombreFn) {
            nombreToSave = call.args['nombre'] as String?;
          }
        }

        if (nombreToSave != null) {
          final followUp = await session.sendMessage(
            Content.functionResponse(
              _guardarNombreFn,
              {'guardado': true, 'nombre': nombreToSave},
            ),
          );
          replyText = followUp.text ?? replyText;
        }
      }

      return GeminiResponse(
        text: replyText ?? 'No se ha podido generar una respuesta.',
        nombreToSave: nombreToSave,
        failed: replyText == null,
      );
    } catch (_) {
      return const GeminiResponse(
        text: 'Upss, ha habido un problema con la conexión. ¿Puedes repetir?',
        failed: true,
      );
    }
  }
}

final geminiServiceProvider = Provider<GeminiService>((ref) => GeminiService());