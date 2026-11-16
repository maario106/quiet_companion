library;

/// Espera antes de la primera palabra, más larga que la pausa entre frases.
const Duration kSpeechLeadInTimeout = Duration(seconds: 8);

/// Espera al resultado final tras apagarse el micrófono: trae la última palabra.
const Duration kSpeechFinalResultWait = Duration(seconds: 1);

/// Pausa entre sesiones nativas; reanudar en el acto falla.
const Duration kSpeechResumeDelay = Duration(milliseconds: 250);

/// Tope de una sesión nativa, por si el sistema no la cierra.
const Duration kSpeechMaxNativeSession = Duration(seconds: 30);

/// Reanudaciones fallidas seguidas antes de rendirse.
const int kSpeechMaxResumeFailures = 5;

/// Español de España, coherente con el resto de la app y con la voz de síntesis.
const String kSpeechLocaleId = 'es_ES';
