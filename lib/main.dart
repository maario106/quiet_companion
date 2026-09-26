import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/config/app_router.dart';
import 'package:quiet_companion/core/config/emulator_config.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';

// FIREBASE
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Antes de cualquier lectura o escritura: los SDK fijan su destino en la
  // primera operación. No hace nada salvo con --dart-define=USE_EMULATOR=true.
  await connectToEmulators();
  await dotenv.load(fileName: '.env');

  runApp(
    const ProviderScope(
      child: AsistenteTFGApp(),
    ),
  );
}

class AsistenteTFGApp extends ConsumerWidget {
  const AsistenteTFGApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Asistente TFG',
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}