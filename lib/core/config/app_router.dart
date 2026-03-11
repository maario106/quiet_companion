import 'package:go_router/go_router.dart';
import 'package:quiet_companion/features/chat/presentation/chat_screen.dart';
import 'package:quiet_companion/features/chat/presentation/home_screen.dart';
import 'package:quiet_companion/features/chat/presentation/temp_menu_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const TempMenuScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatScreen(),
    ),
    // Resto de rutas en el futuro.
  ],
);