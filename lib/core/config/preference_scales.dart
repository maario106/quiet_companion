import 'package:quiet_companion/core/models/user_preferences.dart';

/// Ajuste de accesibilidad del mayor como escala de peldaños con nombre, sobre
/// el mismo valor de [UserPreferences] que el familiar mueve con deslizadores.
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

  /// Segmento de la ruta.
  final String slug;

  /// Título de la fila de ajustes y de la barra de la subpantalla.
  final String title;

  /// Pregunta guía de la subpantalla, en segunda persona.
  final String question;

  /// Peldaños en orden ascendente.
  final List<double> steps;

  /// Nombre de cada peldaño, paralelo a [steps]; el mayor nunca ve el número.
  final List<String> labels;

  final double Function(UserPreferences prefs) read;

  /// Devuelve [prefs] con este parámetro puesto a [value].
  final UserPreferences Function(UserPreferences prefs, double value) apply;

  /// Frase de "Escuchar cómo suena"; null en las escalas que no se oyen.
  final String? previewPhrase;

  bool get hasVoicePreview => previewPhrase != null;

  String get route => '/settings/preference/$slug';

  /// Peldaño más cercano al valor guardado, que puede no coincidir con ninguno.
  int indexOf(UserPreferences prefs) {
    final value = read(prefs);
    var best = 0;
    var bestDistance = (steps.first - value).abs();
    for (var i = 1; i < steps.length; i++) {
      final distance = (steps[i] - value).abs();
      // En empate gana el peldaño más bajo.
      if (distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    return best;
  }

  String labelFor(UserPreferences prefs) => labels[indexOf(prefs)];

  /// Preferencias con la escala en el peldaño [index]; fuera de rango, sin cambios.
  UserPreferences atIndex(UserPreferences prefs, int index) {
    if (index < 0 || index >= steps.length) return prefs;
    return apply(prefs, steps[index]);
  }
}

/// Tamaño del texto: 1,0–2,0. El valor de fábrica (1,2) es "Normal".
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

/// Volumen de la voz: 0,2–1,0. Sin cero, para que la app nunca quede muda.
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

/// Velocidad del habla: 0,2–1,0. El valor de fábrica (0,4) es "Normal".
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

/// Silencio que espera la app antes de dar el turno por terminado.
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

/// Escalas en el orden en que se ofrecen: lo que se ve, lo que se oye y la escucha.
final List<PreferenceScale> preferenceScales = [
  textSizeScale,
  volumeScale,
  speechRateScale,
  listenPauseScale,
];

/// Escala del segmento `:id` de la ruta; null si el slug no existe.
PreferenceScale? preferenceScaleBySlug(String? slug) {
  for (final scale in preferenceScales) {
    if (scale.slug == slug) return scale;
  }
  return null;
}
