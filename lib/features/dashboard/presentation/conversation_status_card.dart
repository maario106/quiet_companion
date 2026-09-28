import 'package:flutter/material.dart';
import 'package:quiet_companion/core/models/companion_sharing.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/core/utils/spanish_date.dart';

/// Estado del registro de conversaciones del mayor, visto por el familiar.
///
/// **Solo lectura.** El consentimiento y lo que ve el familiar los decide el
/// mayor en su móvil (ADR-0030, ADR-0031); aquí se explica qué hay y, si no hay
/// nada, cómo se consigue: hablándolo en persona, no desde este panel.
class ConversationStatusCard extends StatelessWidget {
  const ConversationStatusCard({super.key, required this.elder});

  final UserModel elder;

  static String sharingLabel(CompanionSharing level) => switch (level) {
        CompanionSharing.none => 'nada',
        CompanionSharing.wellbeing => 'cómo se encuentra',
        CompanionSharing.full => 'cómo se encuentra y de qué habláis',
      };

  @override
  Widget build(BuildContext context) {
    final who = elder.name?.isNotEmpty == true ? elder.name! : 'Tu mayor';
    final consent = elder.conversationConsent;

    final String title;
    final String body;
    if (consent == null) {
      title = 'Aún no ha respondido';
      body = 'La próxima vez que abra la app, $who verá la pregunta de si '
          'quiere guardar un resumen de sus conversaciones. Lo decide en su '
          'móvil.';
    } else if (consent.granted) {
      final since = consent.answeredAt;
      final level = elder.companionSharing ?? CompanionSharing.none;
      title = 'Guarda sus conversaciones';
      body = '${since == null ? '' : 'Desde el ${longSpanishDate(since)}. '}'
          'Te deja ver: ${sharingLabel(level)}. Lo puede cambiar cuando quiera '
          'en su móvil.';
    } else if (consent.isPendingDeletion) {
      title = 'Ha dejado de guardarlas';
      body = 'Ya no ves sus conversaciones. Lo guardado se borrará el '
          '${longSpanishDate(consent.deleteAfter!)}, salvo que lo vuelva a '
          'activar antes.';
    } else {
      title = 'Ha preferido no guardarlas';
      body = 'Solo $who puede activarlo, desde Ajustes en su móvil. Si os '
          'parece bien, habladlo en persona.';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.forum_outlined,
                    color: AppTheme.companionPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: AppTheme.companionFontTitle,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.companionTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: const TextStyle(
                fontSize: AppTheme.companionFontBody,
                color: AppTheme.companionTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
