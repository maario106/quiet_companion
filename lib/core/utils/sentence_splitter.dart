import 'package:quiet_companion/core/config/tts_config.dart';

const String _terminators = '.!?…';

/// Marcas de lista al principio de línea (`- `, `* `, `• `, `1. `).
final RegExp _bulletMarkers = RegExp(r'^[ \t]*(?:[-*•]|\d+[.)])[ \t]+',
    multiLine: true);

/// Encabezados markdown (`## Título`).
final RegExp _headingMarkers = RegExp(r'^[ \t]*#{1,6}[ \t]*', multiLine: true);

/// Restos de énfasis markdown, eliminados como caracteres sueltos.
final RegExp _emphasisMarkers = RegExp(r'[*_`~#]');

/// Emojis y pictogramas, que el TTS ignora o deletrea.
final RegExp _pictographs = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2190}-\u{21FF}\u{2300}-\u{23FF}\u{2460}-\u{27BF}'
  r'\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]',
  unicode: true,
);

final RegExp _whitespaceRun = RegExp(r'\s+');

/// Limpia el markdown y los emojis del LLM; siempre antes de trocear.
String sanitizeForSpeech(String text) {
  return text
      .replaceAll(_bulletMarkers, '')
      .replaceAll(_headingMarkers, '')
      .replaceAll(_emphasisMarkers, '')
      .replaceAll(_pictographs, '')
      .replaceAll(_whitespaceRun, ' ')
      .trim();
}

/// Trocea [text] en frases sintetizables. Funde las cortas y respeta
/// [kTtsMaxChunkChars]; "3.5" no se parte.
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

/// Acumula frases hasta el mínimo; un resto corto se pega a la anterior.
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

/// Corta por espacios lo que exceda el tope del servidor.
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
