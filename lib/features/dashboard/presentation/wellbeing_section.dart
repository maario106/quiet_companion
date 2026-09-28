import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/models/companion_sharing.dart';
import 'package:quiet_companion/core/models/conversation_record.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/conversation_providers.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/core/utils/spanish_date.dart';
import 'package:quiet_companion/core/utils/week_summary.dart';

/// Lo que el familiar ve del análisis de las conversaciones (HU-6, RF-8).
///
/// Ordenado de lo más fiable a lo menos: primero la actividad (dato objetivo,
/// sin IA), luego las señales, el ánimo y los temas. Solo pide lo que el nivel
/// elegido por el mayor le deja leer (ADR-0031); si no hay nada que enseñar, no
/// pinta nada y `ConversationStatusCard` explica por qué.
class WellbeingSection extends ConsumerWidget {
  const WellbeingSection({super.key, required this.elder});

  final UserModel elder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = elder.companionSharing ?? CompanionSharing.none;
    if (!elder.hasConversationConsent || level == CompanionSharing.none) {
      return const SizedBox.shrink();
    }
    final full = level == CompanionSharing.full;

    final records = ref.watch(conversationRecordsProvider(elder.id));
    final contents = full
        ? ref.watch(conversationContentsProvider(elder.id)).valueOrNull ??
            const <String, ConversationContent>{}
        : const <String, ConversationContent>{};

    return records.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const _Note(
        'No se han podido cargar las conversaciones.',
        isError: true,
      ),
      data: (list) {
        final now = DateTime.now();
        final week = summarizeWeek(records: list, contents: contents, now: now);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WeekCard(week: week, now: now),
            _SignalsCard(week: week),
            if (full && week.topTopics.isNotEmpty) _TopicsCard(week: week),
            _ConversationList(records: list, contents: contents, now: now),
            if (full) _MemoryCard(elderId: elder.id),
          ],
        );
      },
    );
  }
}

// ── Piezas compartidas por el panel y el detalle ──────────────────────────

IconData sentimentIcon(Sentiment? sentiment) => switch (sentiment) {
      Sentiment.positive => Icons.sentiment_satisfied_alt,
      Sentiment.neutral => Icons.sentiment_neutral,
      Sentiment.negative => Icons.sentiment_dissatisfied,
      null => Icons.remove,
    };

Color sentimentColor(Sentiment? sentiment) => switch (sentiment) {
      Sentiment.positive => const Color(0xFF2D8A4E),
      Sentiment.neutral => AppTheme.companionTextSecondary,
      Sentiment.negative => const Color(0xFFB26A00),
      null => AppTheme.companionTextSecondary,
    };

/// El aviso que acompaña a todo lo que estima el modelo.
const String kEstimateDisclaimer =
    'Orientativo: lo estima un modelo de IA a partir de lo que dice. '
    'No es un diagnóstico.';

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: AppTheme.companionFontTitle,
                fontWeight: FontWeight.w600,
                color: AppTheme.companionTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppTheme.companionFontBody,
          color: isError
              ? AppTheme.companionError
              : AppTheme.companionTextSecondary,
        ),
      ),
    );
  }
}

const TextStyle _body = TextStyle(
  fontSize: AppTheme.companionFontBody,
  color: AppTheme.companionTextPrimary,
);

const TextStyle _small = TextStyle(
  fontSize: AppTheme.companionFontLabel,
  color: AppTheme.companionTextSecondary,
);

// ── Esta semana ────────────────────────────────────────────────────────────

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week, required this.now});

  final WeekSummary week;
  final DateTime now;

  static const _initials = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final last = week.lastConversationAt;
    final quietDays = last == null
        ? null
        : DateTime(now.year, now.month, now.day)
            .difference(DateTime(last.year, last.month, last.day))
            .inDays;

    return _SectionCard(
      title: 'Esta semana',
      children: [
        if (last == null)
          const Text('Todavía no ha hablado con el asistente.', style: _body)
        else
          Text(
            'Última conversación: ${relativeSpanish(last, now)}.',
            style: quietDays != null && quietDays >= 2
                ? _body.copyWith(
                    color: const Color(0xFFB26A00),
                    fontWeight: FontWeight.w600,
                  )
                : _body,
          ),
        const SizedBox(height: 8),
        Text(
          'Ha hablado ${week.daysWithConversation} de los últimos 7 días: '
          '${week.conversationCount} '
          '${week.conversationCount == 1 ? 'conversación' : 'conversaciones'}, '
          '${durationSpanish(week.talkTime)} en total.',
          style: _body,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final day in week.days)
              Semantics(
                label: '${weekdaySpanish(day.day)}: '
                    '${day.conversations} conversaciones'
                    '${day.mood == null ? '' : ', ánimo ${day.mood!.label.toLowerCase()}'}',
                child: ExcludeSemantics(
                  child: Column(
                    children: [
                      Text(_initials[day.day.weekday - 1], style: _small),
                      const SizedBox(height: 4),
                      Icon(
                        day.conversations == 0
                            ? Icons.circle_outlined
                            : sentimentIcon(day.mood),
                        size: 28,
                        color: day.conversations == 0
                            ? AppTheme.companionTextSecondary
                                .withValues(alpha: 0.4)
                            : sentimentColor(day.mood),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          week.mood == null
              ? 'Ánimo de la semana: sin datos suficientes.'
              : 'Ánimo de la semana: ${week.mood!.label.toLowerCase()}.',
          style: _body,
        ),
        const SizedBox(height: 4),
        const Text(kEstimateDisclaimer, style: _small),
      ],
    );
  }
}

// ── Señales ────────────────────────────────────────────────────────────────

class _SignalsCard extends StatelessWidget {
  const _SignalsCard({required this.week});

  final WeekSummary week;

  @override
  Widget build(BuildContext context) {
    final risk = week.signalCounts[ConversationSignal.risk] ?? 0;
    final others = [
      for (final signal in ConversationSignal.values)
        if (signal != ConversationSignal.risk &&
            (week.signalCounts[signal] ?? 0) > 0)
          signal,
    ];

    return _SectionCard(
      title: 'Qué ha mencionado',
      children: [
        if (risk > 0) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.companionError.withValues(alpha: 0.08),
              border: Border.all(color: AppTheme.companionError),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            // No es una alarma (la app no avisa en el momento, ADR-0029): es
            // lo que el familiar ve al abrir el panel, con qué hacer.
            child: const Text(
              'Esta semana habló de hacerse daño o de no querer vivir. '
              'Habla con él o con ella hoy. Si crees que hay peligro, llama al '
              '112. La línea 024 atiende también a familiares, gratis y a '
              'cualquier hora.',
              style: TextStyle(
                fontSize: AppTheme.companionFontBody,
                fontWeight: FontWeight.w600,
                color: AppTheme.companionError,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (others.isEmpty && risk == 0)
          const Text('Nada que llame la atención esta semana.', style: _body)
        else
          for (final signal in others)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${signal.label}: en ${week.signalCounts[signal]} '
                '${week.signalCounts[signal] == 1 ? 'conversación' : 'conversaciones'}.',
                style: _body,
              ),
            ),
        const SizedBox(height: 8),
        const Text(kEstimateDisclaimer, style: _small),
      ],
    );
  }
}

// ── Temas ──────────────────────────────────────────────────────────────────

class _TopicsCard extends StatelessWidget {
  const _TopicsCard({required this.week});

  final WeekSummary week;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'De qué ha hablado',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final topic in week.topTopics) Chip(label: Text(topic)),
          ],
        ),
      ],
    );
  }
}

// ── Lista de conversaciones ────────────────────────────────────────────────

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.records,
    required this.contents,
    required this.now,
  });

  final List<ConversationRecord> records;
  final Map<String, ConversationContent> contents;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Conversaciones del último mes',
      children: [
        if (records.isEmpty)
          const Text('Ninguna todavía.', style: _body)
        else
          for (final record in records)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                sentimentIcon(record.isAnalyzed ? record.sentiment : null),
                color: sentimentColor(record.sentiment),
              ),
              title: Text(
                _capitalize(relativeSpanish(record.endedAt, now)),
                style: _body,
              ),
              subtitle: Text(
                [
                  durationSpanish(record.duration),
                  if (!record.isAnalyzed) 'sin analizar',
                  ...?contents[record.id]?.topics.take(3),
                ].join(' · '),
                style: _small,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/dashboard/conversation/${record.id}'),
            ),
      ],
    );
  }
}

// ── Lo que el asistente recuerda (ADR-0032) ────────────────────────────────

class _MemoryCard extends ConsumerWidget {
  const _MemoryCard({required this.elderId});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facts =
        ref.watch(elderMemoryProvider(elderId)).valueOrNull?.facts ?? const {};

    return _SectionCard(
      title: 'Lo que el asistente recuerda',
      children: [
        if (facts.isEmpty)
          const Text(
            'Nada todavía. Lo irá aprendiendo de lo que cuente.',
            style: _body,
          )
        else
          for (final fact in facts.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${_capitalize(fact.key)}: ${fact.value}', style: _body),
            ),
        const SizedBox(height: 8),
        // Corregirlo desde aquí es trabajo futuro (ADR-0032); hoy, si algo está
        // mal, se corrige hablando: "eso no es así" o "no lo recuerdes".
        const Text(
          'Lo extrae la IA de las conversaciones y puede equivocarse. Si algo no '
          'es correcto, basta con que se lo diga al asistente.',
          style: _small,
        ),
      ],
    );
  }
}

String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
