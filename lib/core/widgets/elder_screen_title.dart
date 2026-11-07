import 'package:flutter/material.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';

/// Título de una pantalla del mayor. Va al principio del contenido y no en la
/// barra superior: la barra lo deja en una línea y corta con "…" lo que no
/// cabe, y con la letra ampliada no cabe casi ninguno. Aquí ocupa las líneas
/// que necesite y se desplaza con el resto de la pantalla.
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
