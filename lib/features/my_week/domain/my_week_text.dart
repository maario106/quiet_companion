import 'package:quiet_companion/core/models/conversation_record.dart';
import 'package:quiet_companion/core/utils/spanish_date.dart';
import 'package:quiet_companion/core/utils/week_summary.dart';

/// "a", "a y b", "a, b y c".
String joinSpanish(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.single;
  return '${items.sublist(0, items.length - 1).join(', ')} y ${items.last}';
}

/// Lo que "Mi semana" le cuenta al mayor, en segunda persona y sin etiquetas
/// clínicas.
List<String> myWeekSentences(WeekSummary week, DateTime now) {
  final sentences = <String>[];

  final days = week.daysWithConversation;
  if (days == 0) {
    sentences.add('Esta semana todavía no hemos hablado. Cuando quieras, aquí '
        'estoy.');
  } else {
    sentences.add(days == 1
        ? 'Esta semana hemos hablado un día.'
        : 'Esta semana hemos hablado $days días.');
  }

  final last = week.lastConversationAt;
  if (last != null && days > 0) {
    sentences.add('La última vez fue ${relativeSpanish(last, now)}.');
  }

  switch (week.mood) {
    case Sentiment.positive:
      sentences.add('La mayoría de las veces te he notado bien.');
    case Sentiment.neutral:
      sentences.add('En general, han sido días tranquilos.');
    case Sentiment.negative:
      sentences.add('Algunos días han sido más difíciles. Si te apetece, '
          'cuéntamelo, o habla con alguien de confianza.');
    case null:
      break;
  }

  if (week.topTopics.isNotEmpty) {
    sentences.add(
        'De lo que más hemos hablado: ${joinSpanish(week.topTopics.take(3).toList())}.');
  }

  if (week.worryTopics.isNotEmpty) {
    sentences.add('Lo que más te ha rondado la cabeza: '
        '${joinSpanish(week.worryTopics)}.');
  }

  return sentences;
}
