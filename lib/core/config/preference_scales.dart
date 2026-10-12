import 'package:quiet_companion/core/models/user_preferences.dart';

/// Un ajuste de accesibilidad del mayor expresado como **escala discreta**.
///
/// El familiar mueve deslizadores continuos desde su panel (HU-4); el mayor no
/// puede: `CLAUDE.md` §Accessibility prohíbe el gesto de arrastre y ADR-0013
/// prescribe controles de incremento/decremento. Un `Slider` es exactamente el
/// widget que no se puede usar aquí. La traducción entre ambos mundos es esta
/// escala: unos pocos peldaños con nombre ("Grande", "Muy despacio") sobre el
/// mismo `double` que ya guarda [UserPreferences], sin cambiar el modelo de
/// datos ni el esquema de Firestore.
///
/// Los peldaños cubren el rango completo que el panel del familiar puede
/// escribir, para que el mayor nunca sufra un recorte silencioso de un valor
/// que otro fijó por él.
class PreferenceScale {
  const PreferenceScale({
    required this.slug,
    required this.title,
    required this.question,
    required this.steps,
    required this.labels,
    required this.read,
    required this.apply,
    this.previewPhrase,
  }) : assert(steps.length == labels.length,
            'Cada peldaño necesita su nombre: labels es paralelo a steps.');

  /// Identifica la escala en la ruta. Se mantiene en inglés como el resto de
  /// segmentos de ruta del proyecto (`emergency-contact`), aunque todo lo que
  /// el mayor lee sea es-ES.
  final String slug;

  /// Título de la fila de ajustes y de la barra de la subpantalla.
  final String title;

  /// Pregunta guía de la subpantalla, en segunda persona.
  final String question;

  /// Peldaños en orden ascendente.
  final List<double> steps;

  /// Nombre de cada peldaño, paralelo a [steps]. Es lo único que el mayor lee:
  /// nunca se le enseña el número crudo.
  final List<String> labels;

  final double Function(UserPreferences prefs) read;

  /// Devuelve unas preferencias nuevas con este parámetro puesto a [value].
  /// Los demás quedan intactos: dos escalas nunca se pisan entre sí.
  final UserPreferences Function(UserPreferences prefs, double value) apply;

  /// Frase que se pronuncia al pulsar "Escuchar cómo suena". `null` en las
  /// escalas que no se oyen (el tamaño del texto se ve, no se escucha).
  final String? previewPhrase;

  bool get hasVoicePreview => previewPhrase != null;

  String get route => '/settings/preference/$slug';

  /// Peldaño más cercano al valor guardado. Redondear en vez de exigir
  /// coincidencia exacta es obligatorio: el deslizador del familiar escribe
  /// valores que no caen en ningún peldaño (0,5 de velocidad, 1,3 de tamaño),
  /// y el mayor debe ver el nombre más parecido, no un hueco.
  int indexOf(UserPreferences prefs) {
    final value = read(prefs);
    var best = 0;
    var bestDistance = (steps.first - value).abs();
    for (var i = 1; i < steps.length; i++) {
      final distance = (steps[i] - value).abs();
      // Estrictamente menor: en un empate gana el peldaño más bajo. Determinista
      // y conservador — ante la duda, la letra más pequeña o la voz más lenta.
      if (distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    return best;
  }

  String labelFor(UserPreferences prefs) => labels[indexOf(prefs)];

  /// Preferencias resultantes de situar esta escala en el peldaño [index].
  /// Fuera de rango devuelve las de entrada: los extremos no dan la vuelta.
  UserPreferences atIndex(UserPreferences prefs, int index) {
    if (index < 0 || index >= steps.length) return prefs;
    return apply(prefs, steps[index]);
  }
}

/// Tamaño del texto: 1,0–2,0, el mismo rango del deslizador del familiar.
/// El valor de fábrica (1,2) se llama "Normal" porque es lo que el mayor ve
/// desde el primer arranque; por debajo hay un peldaño, no un vacío.
final PreferenceScale textSizeScale = PreferenceScale(
  slug: 'text-size',
  title: 'Tamaño de la letra',
  question: '¿Ves bien esta letra?',
  steps: const [1.0, 1.2, 1.4, 1.6, 1.8, 2.0],
  labels: const [
    'Pequeña',
    'Normal',
    'Grande',
    'Muy grande',
    'Enorme',
    'La más grande',
  ],
  read: (prefs) => prefs.textSizeMultiplier,
  apply: (prefs, value) => prefs.copyWith(textSizeMultiplier: value),
);

/// Volumen de la voz: 0,2–1,0. **El cero queda fuera a propósito.** Un mayor
/// que se baja el volumen hasta silenciar la app no encuentra un ajuste
/// apagado: encuentra una app rota, y el fallo es mudo por definición. El
/// peldaño más bajo se oye.
final PreferenceScale volumeScale = PreferenceScale(
  slug: 'volume',
  title: 'Volumen de la voz',
  question: '¿Me oyes bien?',
  steps: const [0.2, 0.4, 0.6, 0.8, 1.0],
  labels: const ['Muy bajo', 'Bajo', 'Medio', 'Alto', 'El más alto'],
  read: (prefs) => prefs.volume,
  apply: (prefs, value) => prefs.copyWith(volume: value),
  previewPhrase: 'Así es como voy a hablarte.',
);

/// Velocidad del habla: 0,2–1,0, todo el rango del panel del familiar. El
/// valor de fábrica (0,4) se llama "Normal" — ya es más lento que el habla
/// corriente, y así lo describe [UserPreferences].
final PreferenceScale speechRateScale = PreferenceScale(
  slug: 'speech-rate',
  title: 'Velocidad de la voz',
  question: '¿Hablo demasiado deprisa?',
  steps: const [0.2, 0.4, 0.6, 0.8, 1.0],
  labels: const [
    'Muy despacio',
    'Normal',
    'Algo rápida',
    'Rápida',
    'Muy rápida',
  ],
  read: (prefs) => prefs.speechRate,
  apply: (prefs, value) => prefs.copyWith(speechRate: value),
  previewPhrase: 'Así es como voy a hablarte.',
);

/// Cuánto silencio espera la app antes de dar por terminado lo que dice el
/// mayor y contestarle (ADR-0036). Segundos concretos y no nombres: como en
/// los plazos de la conversación (ADR-0034), aquí el número sí significa algo
/// para quien lo lee. El peldaño más alto no es "nunca": quien necesita más
/// tiene el botón del micrófono, que envía en el acto.
final PreferenceScale listenPauseScale = PreferenceScale(
  slug: 'listen-pause',
  title: 'Tiempo que te espero',
  question: '¿Te corto antes de que termines de hablar?',
  steps: const [2, 3, 4, 6, 10],
  labels: const [
    '2 segundos',
    '3 segundos',
    '4 segundos',
    '6 segundos',
    '10 segundos',
  ],
  read: (prefs) => prefs.listenPauseSeconds,
  apply: (prefs, value) => prefs.copyWith(listenPauseSeconds: value),
);

/// Las escalas de accesibilidad, en el orden en que se ofrecen al mayor:
/// primero lo que se ve, después lo que se oye y, al final, cuánto se le
/// escucha.
final List<PreferenceScale> preferenceScales = [
  textSizeScale,
  volumeScale,
  speechRateScale,
  listenPauseScale,
];

/// Resuelve el segmento `:id` de la ruta. Devuelve `null` en un slug
/// desconocido para que el enrutador enseñe un error en vez de reventar: la
/// ruta es tecleable desde un enlace profundo.
PreferenceScale? preferenceScaleBySlug(String? slug) {
  for (final scale in preferenceScales) {
    if (scale.slug == slug) return scale;
  }
  return null;
}
