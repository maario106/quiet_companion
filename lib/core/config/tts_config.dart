/// Parámetros de la síntesis de voz en nube (ADR-0017).
///
/// La voz, el idioma y el ritmo de síntesis NO están aquí: son constantes de
/// servidor en `functions/index.js` (`VOICE_NAME`, `LANGUAGE_CODE`,
/// `SPEAKING_RATE`). El cliente nunca envía parámetros de voz; solo el texto.
/// Cambiar de voz es un cambio de una línea en la Function y un redespliegue.
library;

/// Nombre de la callable de síntesis desplegada.
const String kSynthesizeSpeechCallable = 'synthesizeSpeech';

/// Región de despliegue de las Cloud Functions. Debe coincidir con la del
/// despliegue real: el SDK apunta a `us-central1` por defecto y una región
/// distinta da un 404 silencioso que aquí se traduciría en respaldo constante
/// al TTS del dispositivo. Europa por cercanía y por coherencia con Firestore
/// (`eur3`).
const String kTtsFunctionsRegion = 'europe-west1';

/// Tiempo máximo de espera por fragmento. Vencido, esa locución pasa al TTS
/// del dispositivo: sin reintentos ni backoff (ADR-0017). Para esta población
/// una voz peor pero inmediata es mejor que un silencio impredecible.
const Duration kTtsChunkTimeout = Duration(seconds: 4);

/// Tope de caracteres por fragmento. Refleja el tope de la Function (900): el
/// troceado ocurre en el cliente y ningún fragmento debe rebotar por longitud.
const int kTtsMaxChunkChars = 900;

/// Longitud mínima de un fragmento antes de fusionarlo con el siguiente.
/// Frases de dos palabras ("Claro.", "¿Y tú?") generarían un viaje de red por
/// cada una y un audio entrecortado.
const int kTtsMinFragmentChars = 25;

/// Conversión de `UserPreferences.speechRate` (escala de `flutter_tts`, donde
/// 0.5 es el ritmo natural) a velocidad de reproductor (donde 1.0 lo es).
/// `flutter_tts` aplica exactamente este mismo factor en Android, así que el
/// deslizador del familiar significa lo mismo en la voz de nube y en la del
/// dispositivo (ADR-0019).
const double kTtsRateToPlayerSpeed = 2.0;

/// Límites de velocidad del reproductor. El deslizador llega a 0.1 (≈0.2×),
/// ininteligible; se recorta al mínimo que admite Chirp 3: HD y el reproductor.
const double kTtsMinPlayerSpeed = 0.25;
const double kTtsMaxPlayerSpeed = 2.0;
