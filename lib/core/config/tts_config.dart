library;

/// Nombre de la callable de síntesis desplegada.
const String kSynthesizeSpeechCallable = 'synthesizeSpeech';

/// Espera máxima por fragmento; vencida, habla la voz del dispositivo, sin reintentos.
const Duration kTtsChunkTimeout = Duration(seconds: 4);

/// Mismo tope que MAX_TEXT_LENGTH en la Function.
const int kTtsMaxChunkChars = 900;

/// Longitud mínima de un fragmento; los más cortos se fusionan con el siguiente.
const int kTtsMinFragmentChars = 25;

/// De speechRate (escala de flutter_tts, natural en 0.5) a velocidad de
/// reproductor (natural en 1.0); es el mismo factor que aplica flutter_tts.
const double kTtsRateToPlayerSpeed = 2.0;

/// Límites de velocidad del reproductor (el mínimo que admite Chirp 3: HD).
const double kTtsMinPlayerSpeed = 0.25;
const double kTtsMaxPlayerSpeed = 2.0;
