import 'package:flutter/material.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';

/// Una opción de una lista corta de opciones grandes, de las que el mayor
/// elige una ("Qué ve mi familiar", "Voz"). La elegida se marca con borde,
/// icono y texto, no solo con color.
class ChoiceOptionTile extends StatelessWidget {
  const ChoiceOptionTile({
    super.key,
    required this.label,
    this.description,
    required this.selected,
    required this.textScale,
    required this.onTap,
  });

  /// Texto completo de la opción. Si va elegida, quien la usa le añade
  /// "(elegido)" o "(elegida)": la concordancia depende de lo que se elige.
  final String label;
  final String? description;
  final bool selected;
  final double textScale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.elderPrimary : AppTheme.elderTextSecondary;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? AppTheme.elderPrimary.withValues(alpha: 0.08)
            : AppTheme.elderSurface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppTheme.emergencyButtonMinHeight,
            ),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: selected ? 4 : 2),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 36 * textScale,
                  color: color,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: AppTheme.fontButton * textScale,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.elderTextPrimary,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          description!,
                          style: TextStyle(
                            fontSize: AppTheme.fontButton * textScale,
                            color: AppTheme.elderTextSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
