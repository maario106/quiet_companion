import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/config/tts_config.dart';
import 'package:quiet_companion/core/utils/sentence_splitter.dart';

void main() {
  group('sanitizeForSpeech', () {
    test('quita el énfasis markdown que el LLM puede colar', () {
      expect(
        sanitizeForSpeech('Me alegro **mucho** de _verte_ hoy.'),
        equals('Me alegro mucho de verte hoy.'),
      );
    });
  });

  group('splitIntoSentences', () {
    test('un decimal no parte la frase', () {
      expect(
        splitIntoSentences(
          'La temperatura de hoy es de 21.5 grados en toda la ciudad.',
        ),
        equals([
          'La temperatura de hoy es de 21.5 grados en toda la ciudad.',
        ]),
      );
    });

    test('ningún fragmento supera el tope de la Function', () {
      // Monólogo sin puntuación: si se colara entero, el servidor lo
      // rechazaría por longitud y la locución caería al respaldo.
      final monologue = List.filled(400, 'palabra').join(' ');
      final chunks = splitIntoSentences(monologue);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(kTtsMaxChunkChars));
      }
      // No se pierde texto por el camino.
      expect(chunks.join(' '), equals(monologue));
    });
  });
}
