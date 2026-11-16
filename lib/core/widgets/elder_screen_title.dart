import 'package:flutter/material.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';

/// Título de una pantalla del mayor, en el contenido y no en la barra, para
/// que no se corte con la letra ampliada.
class ElderScreenTitle extends StatelessWidget {
  const ElderScreenTitle(this.text, {super.key, required this.textScale});

  final String text;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: SizedBox(
        width: double.infinity,
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppTheme.fontMedium * textScale,
            fontWeight: FontWeight.bold,
            color: AppTheme.elderTextPrimary,
          ),
        ),
      ),
    );
  }
}
