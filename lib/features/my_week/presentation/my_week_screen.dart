import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/models/companion_sharing.dart';
import 'package:quiet_companion/core/providers/conversation_providers.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/providers/tts_service_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/core/utils/week_summary.dart';
import 'package:quiet_companion/core/widgets/elder_button.dart';
import 'package:quiet_companion/features/my_week/domain/my_week_text.dart';

/// "Mi semana": el mayor ve su propio análisis (ADR-0033). Todo mayor con el
/// consentimiento activo, independiente o vinculado.
///
/// Frases y no gráficas, un botón para escucharlo y, si tiene familiar, qué ve
/// este y cómo cambiarlo: es también su ventana a lo que se guarda de él.
class MyWeekScreen extends ConsumerWidget {
  const MyWeekScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final textScale = user.preferences.textSizeMultiplier;
    final records = ref.watch(conversationRecordsProvider(user.id));
    final contents =
        ref.watch(conversationContentsProvider(user.id)).valueOrNull ?? const {};

    final titleStyle = TextStyle(
      fontSize: AppTheme.fontMedium * textScale,
      fontWeight: FontWeight.bold,
      color: AppTheme.elderTextPrimary,
    );
    final bodyStyle = TextStyle(
      fontSize: AppTheme.fontButton * textScale,
      color: AppTheme.elderTextPrimary,
    );

    return Scaffold(
      appBar: AppBar(title: Text('Mi semana', style: titleStyle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: AppTheme.contentMaxWidth(context)),
            child: records.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Ahora no puedo enseñarte tu semana. Inténtalo más tarde.',
                  style: bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              data: (list) {
                final now = DateTime.now();
                final week =
                    summarizeWeek(records: list, contents: contents, now: now);
                final sentences = myWeekSentences(week, now);
                final sharing = user.linkedCompanionId == null
                    ? null
                    : (user.companionSharing ?? CompanionSharing.none);

                return SingleChildScrollView(
                  padding: EdgeInsets.all(AppTheme.screenPadding(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DaysRow(week: week, textScale: textScale),
                      const SizedBox(height: 32),
                      for (final sentence in sentences) ...[
                        Text(sentence, style: bodyStyle),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 8),
                      ElderButton(
                        label: 'Escuchar',
                        icon: Icons.volume_up,
                        secondary: true,
                        textScale: textScale,
                        onPressed: () => ref
                            .read(ttsServiceProvider)
                            .speak(sentences.join(' ')),
                      ),
                      if (sharing != null) ...[
                        const SizedBox(height: 40),
                        Text('Lo que ve tu familiar', style: titleStyle),
                        const SizedBox(height: 8),
                        Text(sharing.description, style: bodyStyle),
                        const SizedBox(height: 16),
                        ElderButton(
                          label: 'Cambiar lo que ve',
                          secondary: true,
                          textScale: textScale,
                          onPressed: () =>
                              context.push('/settings/companion-sharing'),
                        ),
                      ],
                      const SizedBox(height: 32),
                      Text(
                        'Esto lo resumo yo a partir de lo que hablamos, y puedo '
                        'equivocarme.',
                        style: bodyStyle.copyWith(
                          color: AppTheme.elderTextSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Los siete días, con una marca en los que hemos hablado. Refuerzo, no
/// evaluación: no se pinta el ánimo de cada día.
class _DaysRow extends StatelessWidget {
  const _DaysRow({required this.week, required this.textScale});

  final WeekSummary week;
  final double textScale;

  static const _initials = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final day in week.days)
          Column(
            children: [
              Text(
                _initials[day.day.weekday - 1],
                style: TextStyle(
                  fontSize: AppTheme.fontButton * textScale,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.elderTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Icon(
                day.conversations > 0 ? Icons.check_circle : Icons.circle_outlined,
                size: 36 * textScale,
                color: day.conversations > 0
                    ? AppTheme.elderPrimary
                    : AppTheme.elderTextSecondary.withValues(alpha: 0.4),
                semanticLabel: day.conversations > 0 ? 'hablamos' : 'no hablamos',
              ),
            ],
          ),
      ],
    );
  }
}
