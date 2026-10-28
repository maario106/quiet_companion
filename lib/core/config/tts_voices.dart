import 'package:quiet_companion/core/models/user_preferences.dart';

/// Una de las voces de nube que el mayor puede elegir en Ajustes.
///
/// El cliente solo conoce la clave y el nombre que lee el mayor. El nombre
/// real de la voz (`es-ES-Chirp3-HD-Sulafat`) vive en el servidor, en la tabla
/// `VOICES` de `functions/index.js`, con estas mismas claves: una clave que el
/// servidor no conozca suena con la voz por defecto, no falla.
class TtsVoice {
  const TtsVoice({required this.id, required this.label});

  /// Clave que se guarda en [UserPreferences.voice] y viaja en cada síntesis.
  final String id;

  /// Lo que lee el mayor: si es de hombre o de mujer y cómo suena, nunca el
  /// nombre del catálogo de Google.
  final String label;
}

/// Las cuatro voces del catálogo Chirp 3: HD que Google describe con el
/// registro de un acompañante: *Warm*, *Gentle*, *Friendly* y *Smooth*. Dos de
/// mujer y dos de hombre, y no más: el mayor las compara de oído, y con más
/// opciones ya no recuerda cómo sonaba la primera.
const List<TtsVoice> ttsVoices = [
  TtsVoice(id: 'sulafat', label: 'Voz de mujer, cálida'),
  TtsVoice(id: 'vindemiatrix', label: 'Voz de mujer, dulce'),
  TtsVoice(id: 'achird', label: 'Voz de hombre, amable'),
  TtsVoice(id: 'algieba', label: 'Voz de hombre, suave'),
];

/// Voz guardada en [prefs]. Una clave desconocida (una voz retirada, un
/// documento editado a mano) se muestra como la voz por defecto, que es
/// también la que el servidor usará con ella.
TtsVoice ttsVoiceFor(UserPreferences prefs) => ttsVoices.firstWhere(
      (voice) => voice.id == prefs.voice,
      orElse: () => ttsVoices
          .firstWhere((voice) => voice.id == UserPreferences.defaultVoice),
    );

/// Frase que dice cada voz al tocarla en Ajustes: la misma que las escalas de
/// volumen y velocidad, para que solo cambie la voz.
const String kVoicePreviewPhrase = 'Así es como voy a hablarte.';
