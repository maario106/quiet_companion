import 'package:quiet_companion/core/models/user_preferences.dart';

/// Voz de nube elegible en Ajustes. El nombre real vive en VOICES de
/// functions/index.js, con las mismas claves.
class TtsVoice {
  const TtsVoice({required this.id, required this.label});

  /// Clave que se guarda en [UserPreferences.voice] y viaja en cada síntesis.
  final String id;

  /// Lo que lee el mayor: si es de hombre o de mujer y cómo suena.
  final String label;
}

/// Cuatro voces Chirp 3: HD, dos de mujer y dos de hombre.
const List<TtsVoice> ttsVoices = [
  TtsVoice(id: 'sulafat', label: 'Voz de mujer, cálida'),
  TtsVoice(id: 'vindemiatrix', label: 'Voz de mujer, dulce'),
  TtsVoice(id: 'achird', label: 'Voz de hombre, amable'),
  TtsVoice(id: 'algieba', label: 'Voz de hombre, suave'),
];

/// Voz guardada en [prefs]; una clave desconocida cae en la voz por defecto.
TtsVoice ttsVoiceFor(UserPreferences prefs) => ttsVoices.firstWhere(
      (voice) => voice.id == prefs.voice,
      orElse: () => ttsVoices
          .firstWhere((voice) => voice.id == UserPreferences.defaultVoice),
    );

/// Frase de prueba de cada voz, la misma que en volumen y velocidad.
const String kVoicePreviewPhrase = 'Así es como voy a hablarte.';
