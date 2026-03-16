import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class TempMenuScreen extends StatelessWidget {
  const TempMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú de Demostración TFG'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Selecciona la vista a probar:',
              style: TextStyle(fontSize: AppTheme.fontMedium, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40), 

            // Botón hacia el Boceto Visual
            ElevatedButton.icon(
              icon: const Icon(Icons.design_services, size: 30),
              label: const Text('1. Ver Boceto UI (HomeScreen)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: AppTheme.fontButton),
              ),
              onPressed: () {
                context.push('/home'); // Navega a la pantalla del boceto
              },
            ),

            const SizedBox(height: 20),

            // Botón hacia el Prototipo de IA
            ElevatedButton.icon(
              icon: const Icon(Icons.smart_toy, size: 30),
              label: const Text('2. Ver Prototipo IA (ChatScreen)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: AppTheme.textSecondary,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: AppTheme.fontButton),
              ),
              onPressed: () {
                context.push('/chat'); // Navega a la pantalla de la IA
              },
            ),
          ],
        ),
      ),
    );
  }
}