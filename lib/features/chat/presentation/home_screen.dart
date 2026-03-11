import 'package:flutter/material.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top bar transparente con iconos a los lados
      appBar: AppBar(
        // leading: IconButton(
        //   icon: const Icon(Icons.home_outlined),
        //   onPressed: () {
        //     // TODO Acción de home
        //   },
        // ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              // TODO Acción de perfil. No sé si hará algo
            },
          ),
          const SizedBox(width: 8), // Pequeño margen
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // SALUDO
              const Text(
                // TODO insertar nombre usuario
                'Hola!',
                style: TextStyle(
                  fontSize: AppTheme.fontHuge,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                // TODO: Esta frase podrá editarla el familiar/usuario configurador?
                '¿Cómo va el día?',
                style: TextStyle(
                  fontSize: AppTheme.fontLarge,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 2),

              // BOTÓN GIGANTE DE MICRÓFONO
              GestureDetector(
                onTap: () {
                  // TODO: Conectar la transición a la pantalla de "Escuchando"
                  print("Botón de micro pulsado");
                },
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // TODO: comprobar qué pasa con withOpacity pq en TECNOSONRISAS tb salía así pero funcionaba
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 4,
                    ),
                  ),
                  child: const Icon(
                    Icons.mic_none,
                    size: 100,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // BOTÓN DE TECLADO
              OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    side: const BorderSide(color: AppTheme.textSecondary, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                onPressed: () {
                    // TODO: Lógica para abrir el teclado
                },
                child: const Text(
                  '¿Utilizar teclado?',
                  style: TextStyle(
                    fontSize: AppTheme.fontButton,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // BOTONES INFERIORES (Emergencia y Ajustes)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Emergencia (Rojo y cuadrado)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.emergencyColor, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.phone_in_talk),
                      color: AppTheme.emergencyColor,
                      iconSize: 40,
                      padding: const EdgeInsets.all(16),
                      onPressed: () {
                        // TODO: Llamar al contacto que tenga configurado el user
                      },
                    ),
                  ),
                  // Ajustes
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primaryColor, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      color: AppTheme.primaryColor,
                      iconSize: 40,
                      padding: const EdgeInsets.all(16),
                      onPressed: () {
                        // TODO: Rerouting a la pantalla de ajustes.
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}