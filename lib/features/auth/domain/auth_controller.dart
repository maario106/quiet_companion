import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_state.dart';
import 'package:quiet_companion/core/models/user_model.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController()
      : super(const AuthState(status: AuthStatus.nonAuthenticated));

  // Simula el login invisible cuando abre la App TODO firebase
  void anonymousLocalLogin() {
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: const UserModel(id: 'user_local_13', role: UserRole.elder),
    );
  }

  // Se llama cuando pulsa "Usar por mi cuenta"
  void selectIndependentMode() {
    if (state.user == null) return;

    final userUpdated = state.user!.copyWith(
      autonomy: AutonomyStatus.independent,
      linkCode: null,
    );

    state = state.copyWith(user: userUpdated);
    // TODO: más adelante, aquí se guardará en Firebase Firestore
  }

  void selectLinkedMode() {
    if (state.user == null) return;

    final code = _genCode();

    final userUpdated = state.user!.copyWith(
      autonomy: AutonomyStatus.dependent,
      linkCode: code,
    );

    state = state.copyWith(user: userUpdated);
    // TODO: más adelante, aquí se guardará en Firebase Firestore
  }

  String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Quito O, 0, 1, I por accesibilidad visual
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController();
});