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

    test('quita viñetas y encabezados al principio de línea', () {
      expect(
        sanitizeForSpeech('## Ideas\n- Pasear\n- Llamar a tu hija'),
        equals('Ideas Pasear Llamar a tu hija'),
      );
    });

    test('quita listas numeradas', () {
      expect(
        sanitizeForSpeech('1. Desayunar\n2. Pasear'),
        equals('Desayunar Pasear'),
      );
    });

    test('quita emojis: el motor del dispositivo llega a deletrearlos', () {
      expect(
        sanitizeForSpeech('¡Qué bien! 😊👋 Me alegro.'),
        equals('¡Qué bien! Me alegro.'),
      );
    });

    test('colapsa los saltos de línea y espacios repetidos', () {
      expect(
        sanitizeForSpeech('Hola.\n\n   ¿Qué tal?  '),
        equals('Hola. ¿Qué tal?'),
      );
    });

    test('un texto solo de adornos queda vacío', () {
      expect(sanitizeForSpeech('  **  \n 🙂 '), isEmpty);
    });
  });

  group('splitIntoSentences', () {
    test('texto vacío o en blanco no produce fragmentos', () {
      expect(splitIntoSentences(''), isEmpty);
      expect(splitIntoSentences('   \n  '), isEmpty);
    });

    test('separa por punto, interrogación y exclamación', () {
      expect(
        splitIntoSentences(
          'Buenos días, me alegro mucho de verte. '
          '¿Has descansado bien esta noche? '
          '¡Cuéntame cómo te encuentras hoy!',
        ),
        equals([
          'Buenos días, me alegro mucho de verte.',
          '¿Has descansado bien esta noche?',
          '¡Cuéntame cómo te encuentras hoy!',
        ]),
      );
    });

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

    test('los puntos suspensivos son un solo corte', () {
      final chunks = splitIntoSentences(
        'Déjame que lo piense un momento... '
        'Creo que hoy hace un día estupendo para pasear.',
      );
      expect(chunks, hasLength(2));
      expect(chunks.first, equals('Déjame que lo piense un momento...'));
      expect(chunks.first, isNot(contains('..  ')));
    });

    test('los signos repetidos no generan fragmentos vacíos', () {
      final chunks = splitIntoSentences(
        '¡¡Qué alegría verte por aquí!! '
        '¿Cómo te ha ido la mañana en el centro?',
      );
      expect(chunks, hasLength(2));
      expect(chunks.every((c) => c.trim().isNotEmpty), isTrue);
    });

    test('una frase corta se fusiona con la siguiente', () {
      // "Claro." son 6 caracteres: un viaje de red entero para media palabra.
      final chunks = splitIntoSentences(
        'Claro. Me parece una idea estupenda para esta tarde.',
      );
      expect(chunks, hasLength(1));
      expect(chunks.single, startsWith('Claro. Me parece'));
    });

    test('un resto corto final se pega a la frase anterior', () {
      final chunks = splitIntoSentences(
        'Me alegro mucho de que hayas dormido bien esta noche. ¿Y tú?',
      );
      expect(chunks, hasLength(1));
      expect(chunks.single, endsWith('¿Y tú?'));
    });

    test('la cola sin puntuación final también se dice', () {
      final chunks = splitIntoSentences(
        'Hoy hace un día precioso para salir a pasear un rato. '
        'Y mañana también lo hará según dicen',
      );
      expect(chunks.last, endsWith('según dicen'));
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
