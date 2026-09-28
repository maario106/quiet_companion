import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/elder_memory.dart';
import 'package:quiet_companion/core/services/gemini_service.dart';

void main() {
  final now = DateTime(2026, 9, 26, 20);

  test('sin memoria, el bloque se omite (no se dice que no hay)', () {
    expect(GeminiService.memoryContext('Carmen', null), isEmpty);
    expect(GeminiService.memoryContext('Carmen', const ElderMemory()), isEmpty);
  });

  test('con memoria, datos y conversaciones recientes', () {
    final context = GeminiService.memoryContext(
      'Carmen',
      ElderMemory(
        facts: const {'ciudad': 'Sevilla', 'nieto': 'Pablo, 8 años'},
        recent: [
          RecentSummary(
            endedAt: DateTime(2026, 9, 25, 18, 30),
            summary: 'Habló de su nieto.',
          ),
        ],
      ),
      now: now,
    );

    expect(context, contains('Lo que sabes de Carmen:'));
    expect(context, contains('- ciudad: Sevilla'));
    expect(context, contains('- nieto: Pablo, 8 años'));
    expect(context, contains('- ayer a las 18:30: Habló de su nieto.'));
    expect(context, contains('No lo recites'));
  });
}
