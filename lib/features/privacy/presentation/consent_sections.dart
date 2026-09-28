import 'package:flutter/material.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/features/privacy/domain/consent_text.dart';

/// Bloques título + texto del consentimiento, con la tipografía del mayor.
class ConsentSections extends StatelessWidget {
  const ConsentSections({
    super.key,
    required this.sections,
    required this.textScale,
  });

  final List<ConsentSection> sections;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in sections) ...[
          Text(
            section.title,
            style: TextStyle(
              fontSize: AppTheme.fontMedium * textScale,
              fontWeight: FontWeight.bold,
              color: AppTheme.elderPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: TextStyle(
              fontSize: AppTheme.fontButton * textScale,
              color: AppTheme.elderTextPrimary,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}
