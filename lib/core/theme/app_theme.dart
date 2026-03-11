import 'package:flutter/material.dart';

class AppTheme {
  // Paleta de colores de Alta Legibilidad

  // TODO: Hacer más investigación sobre UI/UX y paletas de colores adecuadas

  static const Color primaryColor = Color(0xFF006D77); // Verde azulado calmante
  static const Color backgroundColor = Color(0xFFF8F9FA); // Blanco roto, no daña la vista
  static const Color emergencyColor = Color(0xFFD90429); // Rojo alerta para emergencias
  static const Color textPrimary = Color(0xFF212529); // Casi negro para máximo contraste
  static const Color textSecondary = Color(0xFF495057);

  // Tamaños de fuente accesibles (WCAG)

  // TODO: Para futuro --> Comprobar responsividad con los tamaños más grandes

  static const double fontHuge = 40.0;
  static const double fontLarge = 32.0;
  static const double fontMedium = 24.0;
  static const double fontButton = 20.0;

  static ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          error: emergencyColor,
      ),
      fontFamily: 'Roboto', // TODO: Mirar fuentes WCAG (comparar con proyecto TECNOSONRISAS)
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor, size: 40),
      ),
      iconTheme: const IconThemeData(
        color: primaryColor,
        size: 48, // Iconos gigante por defecto
      ),
    );
  }
}