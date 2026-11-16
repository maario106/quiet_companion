import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/config/app_router.dart';
import 'package:quiet_companion/core/config/emulator_config.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Antes de cualquier operación; solo actúa con --dart-define=USE_EMULATOR=true.
  await connectToEmulators();

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