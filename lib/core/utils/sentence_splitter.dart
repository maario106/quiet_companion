import 'package:quiet_companion/core/config/tts_config.dart';

/// Preparación del texto del LLM para ser sintetizado. Funciones puras, sin
/// dependencias: son el único punto del pipeline de voz que decide *qué* se
/// manda a sintetizar, y se testean sin red ni plugins.

const String _terminators = '.!?…';

/// Marcas de lista al principio de línea (`- `, `* `, `• `, `1. `).
final RegExp _bulletMarkers = RegExp(r'^[ \t]*(?:[-*•]|\d+[.)])[ \t]+',
    multiLine: true);

/// Encabezados markdown (`## Título`).
final RegExp _headingMarkers = RegExp(r'^[ \t]*#{1,6}[ \t]*', multiLine: true);

/// Restos de énfasis markdown. Se eliminan como caracteres sueltos en vez de
/// intentar emparejar delimitadores: el TTS solo necesita que no se lean, no
/// reconstruir el formato.
final RegExp _emphasisMarkers = RegExp(r'[*_`~#]');

/// Emojis y pictogramas. El motor de nube los ignora o los lee como ruido, y
/// el del dispositivo llega a deletrearlos.
final RegExp _pictographs = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2190}-\u{21FF}\u{2300}-\u{23FF}\u{2460}-\u{27BF}'
  r'\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]',
  unicode: true,
);

final RegExp _whitespaceRun = RegExp(r'\s+');

/// Limpia los artefactos de markdown y los emojis que el LLM puede emitir.
/// Se aplica SIEMPRE antes de trocear: el texto que llega al sintetizador es
/// el que se va a oír.
String sanitizeForSpeech(String text) {
  return text
      .replaceAll(_bulletMarkers, '')
      .replaceAll(_headingMarkers, '')
      .replaceAll(_emphasisMarkers, '')
      .replaceAll(_pictographs, '')
      .replaceAll(_whitespaceRun, ' ')
      .trim();
}

/// Trocea [text] en frases sintetizables, en orden.
///
/// Una frase termina en `.`, `!`, `?` o `…` seguidos de espacio o fin de
/// texto: por eso `3.5` no se parte y `Bueno... ¿qué tal?` produce un único
/// corte. Los fragmentos cortos se fusionan con el siguiente ([
/// kTtsMinFragmentChars]) y ninguno supera [kTtsMaxChunkChars], el tope de la
/// Function. Devuelve lista vacía si no queda nada que decir.
List<String> splitIntoSentences(String text) {
  final clean = text.trim();
  if (clean.isEmpty) return const [];

  final sentences = <String>[];
  final buffer = StringBuffer();

  for (var i = 0; i < clean.length; i++) {
    buffer.write(clean[i]);
    if (!_terminators.contains(clean[i])) continue;

    // Una racha de terminadores ("...", "?!", "!!") es un solo corte.
    while (i + 1 < clean.length && _terminators.contains(clean[i + 1])) {
      i++;
      buffer.write(clean[i]);
    }

    final isBoundary = i + 1 == clean.length || _isSpace(clean[i + 1]);
    if (!isBoundary) continue; // Decimales: el "." de "3.5" no corta.

    _addIfNotEmpty(sentences, buffer.toString());
    buffer.clear();
  }
  _addIfNotEmpty(sentences, buffer.toString()); // Cola sin puntuación final.

  return _enforceMaxLength(_mergeShortFragments(sentences));
}

bool _isSpace(String char) => char.trim().isEmpty;

void _addIfNotEmpty(List<String> target, String candidate) {
  final trimmed = candidate.trim();
  if (trimmed.isNotEmpty) target.add(trimmed);
}

/// Acumula frases hasta alcanzar el mínimo. Un resto corto al final se pega a
/// la frase anterior: no hay "siguiente" con quien fusionarlo y no merece un
/// viaje de red propio.
List<String> _mergeShortFragments(List<String> sentences) {
  final merged = <String>[];
  final pending = StringBuffer();

  for (final sentence in sentences) {
    if (pending.isNotEmpty) pending.write(' ');
    pending.write(sentence);
    if (pending.length < kTtsMinFragmentChars) continue;
    merged.add(pending.toString());
    pending.clear();
  }

  if (pending.isEmpty) return merged;
  if (merged.isEmpty) return [pending.toString()];
  merged[merged.length - 1] = '${merged.last} $pending';
  return merged;
}

/// Corta por espacios lo que exceda el tope del servidor. Solo actúa ante un
/// monólogo sin puntuación: si se colara entero, la Function lo rechazaría y
/// la locución entera caería al respaldo.
List<String> _enforceMaxLength(List<String> sentences) {
  if (sentences.every((s) => s.length <= kTtsMaxChunkChars)) return sentences;

  final capped = <String>[];
  for (final sentence in sentences) {
    var rest = sentence;
    while (rest.length > kTtsMaxChunkChars) {
      final window = rest.substring(0, kTtsMaxChunkChars);
      final cut = window.lastIndexOf(' ');
      // Sin espacios donde cortar (palabra imposible): corte duro.
      final at = cut > 0 ? cut : kTtsMaxChunkChars;
      capped.add(rest.substring(0, at).trim());
      rest = rest.substring(at).trim();
    }
    if (rest.isNotEmpty) capped.add(rest);
  }
  return capped;
}
