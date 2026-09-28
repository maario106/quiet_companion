import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/conversation_settings.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/features/dashboard/domain/dashboard_controller.dart';

/// Plazos de las conversaciones del mayor vinculado, que gestiona su familiar
/// (ADR-0034). El mayor los ve en su móvil pero no los cambia; lo que sí
/// decide él es si se guardan y qué ve su familiar.
class ConversationSettingsCard extends ConsumerWidget {
  const ConversationSettingsCard({super.key, required this.elder});

  final UserModel elder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = elder.effectiveConversationSettings;
    final controller = ref.read(dashboardControllerProvider.notifier);

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plazos de las conversaciones',
              style: TextStyle(
                fontSize: AppTheme.companionFontTitle,
                fontWeight: FontWeight.w600,
                color: AppTheme.companionTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Una conversación termina tras este tiempo en silencio',
              style: TextStyle(
                fontSize: AppTheme.companionFontBody,
                color: AppTheme.companionTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _StepSelector(
              steps: ConversationSettings.inactivityMinutesSteps,
              labels: const ['2 min', '5 min', '10 min', '15 min'],
              selected: settings.inactivityMinutes,
              onSelected: (value) => controller.updateConversationSetting(
                ConversationSettings.inactivityMinutesKey,
                value,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Cada resumen se guarda durante',
              style: TextStyle(
                fontSize: AppTheme.companionFontBody,
                color: AppTheme.companionTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _StepSelector(
              steps: ConversationSettings.retentionDaysSteps,
              labels: const ['1 mes', '2 meses', '3 meses', '6 meses'],
              selected: settings.retentionDays,
              onSelected: (value) => controller.updateConversationSetting(
                ConversationSettings.retentionDaysKey,
                value,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Si acortas el plazo, lo que ya quede fuera se borra tras la '
              'siguiente conversación.',
              style: TextStyle(
                fontSize: AppTheme.companionFontLabel,
                color: AppTheme.companionTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepSelector extends StatelessWidget {
  const _StepSelector({
    required this.steps,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<int> steps;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
        showSelectedIcon: false,
        segments: [
          for (var i = 0; i < steps.length; i++)
            ButtonSegment(value: steps[i], label: Text(labels[i])),
        ],
        selected: {selected},
        onSelectionChanged: (values) => onSelected(values.single),
      ),
    );
  }
}
