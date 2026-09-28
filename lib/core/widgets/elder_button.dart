import 'package:flutter/material.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';

/// Botón de la interfaz del mayor: ancho completo, al menos 88 px de alto,
/// texto escalado por su preferencia de tamaño. Mismo aspecto que los de la
/// pantalla de emergencia y los de las escalas de Ajustes.
///
/// [secondary] lo pinta con borde en vez de relleno, para la opción que no es
/// la principal ("Ahora no"): las dos se ven igual de grandes y de tocables,
/// pero no igual de destacadas.
class ElderButton extends StatelessWidget {
  const ElderButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.textScale,
    this.icon,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final double textScale;
  final IconData? icon;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: TextStyle(fontSize: AppTheme.fontButton * textScale),
      textAlign: TextAlign.center,
    );
    final iconWidget = icon == null ? null : Icon(icon, size: 32 * textScale);

    final Widget button;
    if (secondary) {
      button = iconWidget == null
          ? OutlinedButton(onPressed: onPressed, child: text)
          : OutlinedButton.icon(
              onPressed: onPressed, icon: iconWidget, label: text);
    } else {
      button = iconWidget == null
          ? ElevatedButton(onPressed: onPressed, child: text)
          : ElevatedButton.icon(
              onPressed: onPressed, icon: iconWidget, label: text);
    }

    return ConstrainedBox(
      constraints:
          const BoxConstraints(minHeight: AppTheme.emergencyButtonMinHeight),
      child: button,
    );
  }
}
