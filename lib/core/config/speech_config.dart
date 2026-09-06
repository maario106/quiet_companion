/// Parámetros de la escucha del mayor (ADR-0022).
///
/// Separados del servicio porque son la parte que se ajusta al probar con
/// personas: cuánto silencio significa "he terminado de hablar" no es una
/// constante universal, y en esta población tiende a ser más largo de lo que
/// parece razonable en el escritorio del desarrollador.
library;

/// Silencio que da el turno por terminado **una vez el mayor ya ha empezado a
/// hablar**. Vencido, la respuesta se procesa sola, sin pulsar nada.
///
/// Ojo al subirlo o bajarlo: por debajo de ~1,5 s el reconocedor nativo de
/// Android todavía está devolviendo resultados de la frase anterior y el turno
/// se cerraría a media idea.
const Duration kSpeechSilenceTimeout = Duration(seconds: 2);

/// Espera **antes de la primera palabra**. Deliberadamente mucho más larga que
/// [kSpeechSilenceTimeout]: entre pulsar el micrófono y arrancar a hablar pasa
/// un tiempo que para esta población no son dos segundos. Con un único plazo,
/// el turno se cerraría en vacío antes de que al mayor le diera tiempo a
/// empezar.
const Duration kSpeechLeadInTimeout = Duration(seconds: 8);

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
