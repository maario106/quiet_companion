import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/companion_sharing.dart';
import 'package:quiet_companion/core/models/conversation_settings.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/core/widgets/choice_option_tile.dart';
import 'package:quiet_companion/core/widgets/elder_screen_title.dart';
import 'package:quiet_companion/features/privacy/domain/consent_controller.dart';

/// Una de las decisiones del mayor sobre sus conversaciones, como lista corta
/// de opciones grandes. Un toque elige y guarda; la elegida se marca con
/// borde, icono y texto, no solo con color.
///
/// Opciones y no escala de "Más/Menos" (ADR-0021): son tres o cuatro, cada una
/// con su nombre, y ver todas a la vez es más claro que recorrerlas.
enum PrivacyChoice {
  companionSharing(
    title: 'Qué ve mi familiar',
    question: '¿Qué quieres que vea tu familiar de nuestras conversaciones?',
  ),
  inactivity(
    title: 'Cuándo termina una conversación',
    question: '¿Cuánto tiempo en silencio doy por terminada una conversación?',
  ),
  retention(
    title: 'Cuánto tiempo se guardan',
    question: '¿Cuánto tiempo guardo cada resumen antes de borrarlo?',
  );

  const PrivacyChoice({required this.title, required this.question});

  final String title;
  final String question;
}

class _Option {
  const _Option(this.label, {this.description});

  final String label;
  final String? description;
}

class PrivacyChoiceScreen extends ConsumerWidget {
  const PrivacyChoiceScreen({super.key, required this.choice});

  final PrivacyChoice choice;

  List<_Option> _options() => switch (choice) {
        PrivacyChoice.companionSharing => [
            for (final level in CompanionSharing.values)
              _Option(level.label, description: level.description),
          ],
        PrivacyChoice.inactivity => [
            for (final label in ConversationSettings.inactivityMinutesLabels)
              _Option(label),
          ],
        PrivacyChoice.retention => [
            for (final label in ConversationSettings.retentionDaysLabels)
              _Option(label),
          ],
      };

  int _selected(UserModel user) {
    final settings = user.effectiveConversationSettings;
    return switch (choice) {
      PrivacyChoice.companionSharing =>
        (user.companionSharing ?? CompanionSharing.none).index,
      PrivacyChoice.inactivity => ConversationSettings.inactivityMinutesSteps
          .indexOf(settings.inactivityMinutes),
      PrivacyChoice.retention =>
        ConversationSettings.retentionDaysSteps.indexOf(settings.retentionDays),
    };
  }

  Future<void> _select(ConsentController controller, int index) {
    return switch (choice) {
      PrivacyChoice.companionSharing =>
        controller.setCompanionSharing(CompanionSharing.values[index]),
      PrivacyChoice.inactivity => controller.setConversationSetting(
          ConversationSettings.inactivityMinutesKey,
          ConversationSettings.inactivityMinutesSteps[index],
        ),
      PrivacyChoice.retention => controller.setConversationSetting(
          ConversationSettings.retentionDaysKey,
          ConversationSettings.retentionDaysSteps[index],
        ),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final state = ref.watch(consentControllerProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final textScale = user.preferences.textSizeMultiplier;
    final options = _options();
    final selected = _selected(user);
    final controller = ref.read(consentControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: AppTheme.contentMaxWidth(context)),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.screenPadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElderScreenTitle(choice.title, textScale: textScale),
                  const SizedBox(height: 24),
                  Text(
                    choice.question,
                    style: TextStyle(
                      fontSize: AppTheme.fontMedium * textScale,
                      color: AppTheme.elderTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  for (var i = 0; i < options.length; i++) ...[
                    ChoiceOptionTile(
                      label: i == selected
                          ? '${options[i].label} (elegido)'
                          : options[i].label,
                      description: options[i].description,
                      selected: i == selected,
                      textScale: textScale,
                      onTap: state.saving || i == selected
                          ? null
                          : () => _select(controller, i),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (state.errorMessage != null)
                    Text(
                      state.errorMessage!,
                      style: TextStyle(
                        fontSize: AppTheme.fontButton * textScale,
                        color: AppTheme.emergency112,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
