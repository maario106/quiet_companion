import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/models/conversation_record.dart';
import 'package:quiet_companion/core/utils/week_summary.dart';
import 'package:quiet_companion/features/my_week/domain/my_week_text.dart';

final _now = DateTime(2026, 9, 26, 20);

WeekSummary _week({
  List<ConversationRecord> records = const [],
  Map<String, ConversationContent> contents = const {},
}) =>
    summarizeWeek(records: records, contents: contents, now: _now);

ConversationRecord _record(String id, DateTime at,
        {Sentiment sentiment = Sentiment.positive,
        List<ConversationSignal> signals = const []}) =>
    ConversationRecord(
      id: id,
      startedAt: at.subtract(const Duration(minutes: 5)),
      endedAt: at,
      sentiment: sentiment,
      signals: signals,
    );

void main() {
  test('joinSpanish', () {
    expect(joinSpanish([]), '');
    expect(joinSpanish(['a']), 'a');
    expect(joinSpanish(['a', 'b']), 'a y b');
    expect(joinSpanish(['a', 'b', 'c']), 'a, b y c');
  });

  test('semana sin conversaciones: una invitación, sin reproches', () {
    final text = myWeekSentences(_week(), _now);
    expect(text.single, contains('todavía no hemos hablado'));
  });

  test('cuenta los días y cuándo fue la última vez', () {
    final text = myWeekSentences(
      _week(records: [
        _record('a', DateTime(2026, 9, 26, 10)),
        _record('b', DateTime(2026, 9, 24, 10)),
      ]),
      _now,
    );
    expect(text, contains('Esta semana hemos hablado 2 días.'));
    expect(text, contains('La última vez fue hoy a las 10:00.'));
    expect(text, contains('La mayoría de las veces te he notado bien.'));
  });

  test('nunca nombra las señales clínicas', () {
    final text = myWeekSentences(
      _week(records: [
        _record('a', DateTime(2026, 9, 26),
            sentiment: Sentiment.negative,
            signals: [ConversationSignal.loneliness, ConversationSignal.risk]),
      ]),
      _now,
    ).join(' ').toLowerCase();

    expect(text, isNot(contains('soledad')));
    expect(text, isNot(contains('sola')));
    expect(text, isNot(contains('daño')));
    expect(text, contains('más difíciles'));
  });

  test('lo que le ha rondado la cabeza sale de los temas con preocupación', () {
    final text = myWeekSentences(
      _week(
        records: [
          _record('a', DateTime(2026, 9, 26), signals: [ConversationSignal.worry]),
        ],
        contents: {
          'a': ConversationContent(
              id: 'a', endedAt: DateTime(2026, 9, 26), topics: ['médico']),
        },
      ),
      _now,
    );
    expect(text, contains('Lo que más te ha rondado la cabeza: médico.'));
  });
}
