import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:quiet_companion/core/config/app_router.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  // Me aseguro de que los bindings de Flutter estén listos antes de cargar el .env
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  runApp(
      ProviderScope(
        child: const AsistenteTFGApp(),
      ),
  );
}


class AsistenteTFGApp extends StatelessWidget {
  const AsistenteTFGApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Asistente TFG',
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}