import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/providers/tts_service_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/core/widgets/elder_button.dart';
import 'package:quiet_companion/core/widgets/elder_screen_title.dart';
import 'package:quiet_companion/core/widgets/stop_speaking_on_exit.dart';
import 'package:quiet_companion/features/privacy/domain/consent_controller.dart';
import 'package:quiet_companion/features/privacy/domain/consent_text.dart';
import 'package:quiet_companion/features/privacy/presentation/consent_sections.dart';

/// La pregunta del consentimiento. El router la enseña una vez, sin flecha
/// atrás; las dos respuestas pesan igual.
class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final consent = ref.watch(consentControllerProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final textScale = user.preferences.textSizeMultiplier;
    final text = ConsentText.forUser(user);
    final controller = ref.read(consentControllerProvider.notifier);

    return StopSpeakingOnExit(
      child: Scaffold(
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
                    ElderScreenTitle('Antes de empezar', textScale: textScale),
                    const SizedBox(height: 24),
                    Text(
                      ConsentText.question,
                      style: TextStyle(
                        fontSize: AppTheme.fontLarge * textScale,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.elderTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ConsentSections(sections: text.summary, textScale: textScale),
                    const SizedBox(height: 8),
                    ElderButton(
                      label: 'Escuchar',
                      icon: Icons.volume_up,
                      secondary: true,
                      textScale: textScale,
                      onPressed: () => ref
                          .read(ttsServiceProvider)
                          .speak(ConsentText.spoken(text.summary)),
                    ),
                    const SizedBox(height: 16),
                    ElderButton(
                      label: 'Saber más',
                      icon: Icons.info_outline,
                      secondary: true,
                      textScale: textScale,
                      onPressed: () => context.push('/consent/details'),
                    ),
                    const SizedBox(height: 40),
                    ElderButton(
                      label: 'Sí, quiero',
                      icon: Icons.check,
                      textScale: textScale,
                      // El router navega cuando el servidor guarda la respuesta.
                      onPressed: consent.saving
                          ? null
                          : () => controller.answer(granted: true),
                    ),
                    const SizedBox(height: 20),
                    ElderButton(
                      label: 'Ahora no',
                      secondary: true,
                      textScale: textScale,
                      onPressed: consent.saving
                          ? null
                          : () => controller.answer(
                                granted: false,
                                deferOnFailure: true,
                              ),
                    ),
                    if (consent.errorMessage != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        consent.errorMessage!,
                        style: TextStyle(
                          fontSize: AppTheme.fontButton * textScale,
                          color: AppTheme.emergency112,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
