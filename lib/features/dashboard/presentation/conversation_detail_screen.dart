import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/companion_sharing.dart';
import 'package:quiet_companion/core/models/conversation_record.dart';
import 'package:quiet_companion/core/providers/conversation_providers.dart';
import 'package:quiet_companion/core/providers/linked_elder_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/core/utils/spanish_date.dart';
import 'package:quiet_companion/features/dashboard/presentation/wellbeing_section.dart';

/// Una conversación, vista por el familiar. Lee de los mismos providers que el
/// panel: no hace lecturas nuevas, y respeta el mismo nivel (ADR-0031).
class ConversationDetailScreen extends ConsumerWidget {
  const ConversationDetailScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elder = ref.watch(linkedElderProvider).valueOrNull;
    final level = elder?.companionSharing ?? CompanionSharing.none;
    ConversationRecord? record;
    ConversationContent? content;
    if (elder != null &&
        elder.hasConversationConsent &&
        level != CompanionSharing.none) {
      final records =
          ref.watch(conversationRecordsProvider(elder.id)).valueOrNull;
      for (final r in records ?? const <ConversationRecord>[]) {
        if (r.id == conversationId) record = r;
      }
      if (level == CompanionSharing.full) {
        content = ref
            .watch(conversationContentsProvider(elder.id))
            .valueOrNull?[conversationId];
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Conversación')),
      body: record == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Esta conversación ya no está disponible.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.all(AppTheme.screenPadding(context)),
              children: [
                _Row('Cuándo',
                    '${longSpanishDate(record.startedAt)}, de '
                    '${timeSpanish(record.startedAt)} a '
                    '${timeSpanish(record.endedAt)}'),
                _Row('Duración', durationSpanish(record.duration)),
                _Row('Intervenciones suyas', '${record.elderTurns}'),
                if (!record.isAnalyzed)
                  _Row(
                    'Análisis',
                    record.status == ConversationStatus.tooShort
                        ? 'Demasiado breve para analizarla.'
                        : 'No se pudo analizar.',
                  )
                else ...[
                  _Row('Ánimo', record.sentiment?.label ?? 'Sin datos'),
                  _Row(
                    'Ha mencionado',
                    record.signals.isEmpty
                        ? 'Nada que llame la atención.'
                        : record.signals.map((s) => s.label).join(', '),
                  ),
                  if (content != null) ...[
                    _Row('Resumen', content.summary),
                    if (content.topics.isNotEmpty)
                      _Row('Temas', content.topics.join(', ')),
                  ] else if (level == CompanionSharing.wellbeing)
                    const _Row(
                      'Resumen',
                      'Ha elegido que no veas de qué habláis.',
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    kEstimateDisclaimer,
                    style: TextStyle(
                      fontSize: AppTheme.companionFontLabel,
                      color: AppTheme.companionTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTheme.companionFontLabel,
              color: AppTheme.companionTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: AppTheme.companionFontBody,
              color: AppTheme.companionTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
