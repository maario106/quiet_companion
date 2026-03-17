import 'package:go_router/go_router.dart';
import 'package:quiet_companion/features/chat/presentation/home_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    // Resto de rutas en el futuro.
  ],
);