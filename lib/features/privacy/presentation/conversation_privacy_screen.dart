import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/providers/tts_service_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/core/utils/spanish_date.dart';
import 'package:quiet_companion/core/widgets/elder_button.dart';
import 'package:quiet_companion/core/widgets/stop_speaking_on_exit.dart';
import 'package:quiet_companion/features/privacy/domain/consent_controller.dart';
import 'package:quiet_companion/features/privacy/domain/consent_text.dart';
import 'package:quiet_companion/features/privacy/presentation/consent_sections.dart';

/// El detalle de lo que se guarda de las conversaciones.
///
/// Dos entradas, una pantalla:
/// - "Saber más" desde la pregunta del consentimiento ([manage] = false): solo
///   el texto completo.
/// - La fila "Guardar mis conversaciones" de Ajustes ([manage] = true): el
///   estado actual y el botón para activarlo o retirarlo, con un paso de
///   confirmación para retirar (ADR-0030: tan fácil como darlo, pero no por un
///   toque perdido).
class ConversationPrivacyScreen extends ConsumerStatefulWidget {
  const ConversationPrivacyScreen({super.key, required this.manage});

  final bool manage;

  @override
  ConsumerState<ConversationPrivacyScreen> createState() =>
      _ConversationPrivacyScreenState();
}

class _ConversationPrivacyScreenState
    extends ConsumerState<ConversationPrivacyScreen> {
  // Estado de vista puro: la segunda fase de "Dejar de guardarlas".
  bool _confirmingRevoke = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final consent = ref.watch(consentControllerProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final textScale = user.preferences.textSizeMultiplier;
    final text = ConsentText.forUser(user);

    return StopSpeakingOnExit(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.manage ? 'Guardar mis conversaciones' : 'Saber más',
            style: TextStyle(
              fontSize: AppTheme.fontMedium * textScale,
              fontWeight: FontWeight.bold,
              color: AppTheme.elderTextPrimary,
            ),
          ),
        ),
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
                    if (widget.manage) ...[
                      _Status(user: user, textScale: textScale),
                      const SizedBox(height: 24),
                      ..._actions(user, textScale, consent),
                      const SizedBox(height: 40),
                    ],
                    ConsentSections(sections: text.details, textScale: textScale),
                    ElderButton(
                      label: 'Escuchar',
                      icon: Icons.volume_up,
                      secondary: true,
                      textScale: textScale,
                      onPressed: () => ref.read(ttsServiceProvider).speak(
                            ConsentText.spoken(text.details, withQuestion: false),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(UserModel user, double textScale, ConsentState consent) {
    final controller = ref.read(consentControllerProvider.notifier);
    final error = consent.errorMessage;
    final errorText = error == null
        ? const <Widget>[]
        : [
            const SizedBox(height: 20),
            Text(
              error,
              style: TextStyle(
                fontSize: AppTheme.fontButton * textScale,
                color: AppTheme.emergency112,
              ),
              textAlign: TextAlign.center,
            ),
          ];

    if (!user.hasConversationConsent) {
      return [
        ElderButton(
          label: 'Sí, quiero guardarlas',
          icon: Icons.check,
          textScale: textScale,
          onPressed:
              consent.saving ? null : () => controller.answer(granted: true),
        ),
        ...errorText,
      ];
    }

    if (!_confirmingRevoke) {
      return [
        ElderButton(
          label: 'Dejar de guardarlas',
          secondary: true,
          textScale: textScale,
          onPressed: consent.saving
              ? null
              : () => setState(() => _confirmingRevoke = true),
        ),
        ...errorText,
      ];
    }

    final grace = user.effectiveConversationSettings.gracePeriodDays;
    final linked = user.linkedCompanionId != null;
    return [
      Text(
        '¿Seguro? Dejaré de guardar nuestras conversaciones'
        '${linked ? ' y tu familiar dejará de verlas' : ''}. '
        'Lo que ya está guardado se borrará dentro de $grace días. '
        'Si cambias de idea antes, lo recuperas.',
        style: TextStyle(
          fontSize: AppTheme.fontButton * textScale,
          color: AppTheme.elderTextPrimary,
        ),
      ),
      const SizedBox(height: 24),
      ElderButton(
        label: 'Sí, dejar de guardarlas',
        textScale: textScale,
        onPressed: consent.saving
            ? null
            : () async {
                final saved = await controller.answer(granted: false);
                if (saved && mounted) {
                  setState(() => _confirmingRevoke = false);
                }
              },
      ),
      const SizedBox(height: 20),
      ElderButton(
        label: 'No, seguir guardándolas',
        secondary: true,
        textScale: textScale,
        onPressed: () => setState(() => _confirmingRevoke = false),
      ),
      ...errorText,
    ];
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.user, required this.textScale});

  final UserModel user;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final consent = user.conversationConsent;
    final deleteAfter = consent?.deleteAfter;

    final String message;
    if (user.hasConversationConsent) {
      message = 'Ahora guardo un resumen de nuestras conversaciones.';
    } else if (consent != null && consent.isPendingDeletion && deleteAfter != null) {
      message = 'Ahora no guardo nuestras conversaciones. Lo que se guardó se '
          'borrará el ${longSpanishDate(deleteAfter)}. Si vuelves a activarlo '
          'antes, lo recuperas.';
    } else {
      message = 'Ahora no guardo nuestras conversaciones.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.elderPrimary.withValues(alpha: 0.06),
        border: Border.all(color: AppTheme.elderPrimary, width: 2),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: AppTheme.fontButton * textScale,
          fontWeight: FontWeight.bold,
          color: AppTheme.elderTextPrimary,
        ),
      ),
    );
  }
}
