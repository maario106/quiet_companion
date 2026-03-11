import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:quiet_companion/core/config/env.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    final systemInstruction = Content.system(
        "Eres un acompañante virtual diseñado específicamente para conversar con personas mayores "
            "y combatir la soledad. Tu objetivo principal es hacer compañía, escuchar activamente, "
            "y ser muy respetuoso y cálido.\n\n"
            "REGLAS:\n"
            "1. Respuestas MUY breves (máximo 2 o 3 frases). Van a ser leídas por voz.\n"
            "2. Termina siempre con una pregunta sencilla para mantener la conversación.\n"
            "3. Actúa como un oyente humano empático. No digas que eres una IA.\n"
            "4. Si el usuario menciona problemas de salud, dile amablemente que lo consulte con su familia o médico."
    );

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: Env.geminiApiKey,
      systemInstruction: systemInstruction,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.high),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.high),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.high),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.high),
      ],
    );
  }

  Future<String> sendMessage(String text) async {
    try {
      final response = await _model.generateContent([Content.text(text)]);
      return response.text ?? 'No se ha podido generar una respuesta.';
    } catch (e) {
      print('ERROR GEMINI: $e');
      return 'Upss, ha habido un problema con la conexión. ¿Puedes repetir?';
    }
  }
}