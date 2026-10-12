/// Parámetros de la escucha del mayor (ADR-0022).
///
/// Separados del servicio porque son la parte que se ajusta al probar con
/// personas: cuánto silencio significa "he terminado de hablar" no es una
/// constante universal, y en esta población tiende a ser más largo de lo que
/// parece razonable en el escritorio del desarrollador.
library;

// El silencio que da el turno por terminado una vez el mayor ya ha empezado a
// hablar ya no vive aquí: lo elige cada mayor en Ajustes ("Tiempo que te
// espero", `UserPreferences.listenPauseSeconds`, ADR-0036). Lo que sigue son
// los plazos que no dependen de la persona.

/// Espera **antes de la primera palabra**. Deliberadamente mucho más larga que
/// la pausa entre frases: entre pulsar el micrófono y arrancar a hablar pasa
/// un tiempo que para esta población no son dos segundos. Con un único plazo,
/// el turno se cerraría en vacío antes de que al mayor le diera tiempo a
/// empezar. Si el mayor ha elegido una pausa aún más larga, manda la suya.
const Duration kSpeechLeadInTimeout = Duration(seconds: 8);

/// Cuánto se espera el resultado final de una sesión nativa después de que
/// el micrófono se apague. Android avisa de que ha dejado de grabar **antes**
/// de entregar ese resultado, y es el único que trae la última palabra: los
/// parciales van por detrás de la voz (ADR-0036). Normalmente llega en unos
/// cientos de milisegundos; esto es solo el tope para no esperar a un final
/// que no va a venir. Lo mismo al cerrar el turno, por silencio o con el botón.
const Duration kSpeechFinalResultWait = Duration(seconds: 1);

/// Respiro entre que el reconocedor nativo cierra una sesión y se abre la
/// siguiente. Reanudar en el acto lanza `ListenFailedException`: el motor aún
/// se está cerrando. Es también el hueco en el que se pierde audio, así que se
/// quiere lo más corto que el dispositivo tolere.
const Duration kSpeechResumeDelay = Duration(milliseconds: 250);

/// Tope de una sesión nativa. Android impone el suyo, más corto ("on the order
/// of ten seconds or so" según el propio paquete); esto solo evita que una
/// sesión quede colgada indefinidamente si el sistema no la cierra.
const Duration kSpeechMaxNativeSession = Duration(seconds: 30);

/// Reanudaciones fallidas seguidas antes de rendirse. Sin este tope, un fallo
/// permanente (micrófono ocupado, motor de voz ausente) haría girar el bucle
/// de reanudación hasta que venciera el plazo de silencio.
const int kSpeechMaxResumeFailures = 5;

/// Español de España, coherente con el resto de la app y con la voz de síntesis.
const String kSpeechLocaleId = 'es_ES';
