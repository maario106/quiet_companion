import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'elder_auth_state.dart';
import '../data/auth_repository.dart';
import 'package:quiet_companion/core/models/user_model.dart';

class ElderAuthController extends StateNotifier<AuthState> {
  ElderAuthController(this._authRepository)
      : super(const AuthState(status: AuthStatus.checking)){
    initSession();
  }

  final AuthRepository _authRepository;

  late StreamSubscription<UserModel?> _userSubscription;

  Future<void> initSession() async {
    state = state.copyWith(status: AuthStatus.checking);
    try {
      final uid = await _authRepository.signInAnonymously();
      _userSubscription = _authRepository.streamUser(uid).listen((existingUser) {
        final user = existingUser ?? UserModel(id: uid, role: UserRole.elder);
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      });
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  Future<void> selectIndependentMode() async {
    if (state.user == null) return;
    final updatedUser = state.user!.copyWith(
      autonomy: AutonomyStatus.independent,
      linkCode: null,
    );
    state = state.copyWith(user: updatedUser);
    try {
      await _authRepository.saveUser(updatedUser);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> selectLinkedMode() async {
    if (state.user == null) return;
    final code = _genCode();
    final updatedUser = state.user!.copyWith(
      autonomy: AutonomyStatus.dependent,
      linkCode: code,
    );
    state = state.copyWith(user: updatedUser);
    try {
      await _authRepository.saveUser(updatedUser);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> cancelLinkedMode() async {
    if (state.user == null) return;
    final updatedUser = state.user!.copyWith(
      autonomy: AutonomyStatus.none,
      linkCode: null,
    );
    state = state.copyWith(user: updatedUser);
    try {
      await _authRepository.saveUser(updatedUser);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  // TODO: Hacer un sistema en "tiempo real" que compruebe si el familiar ha metido el
  // TODO: código en vez de tener este method.
  Future<void> checkPairingStatus() async {
    if (state.user == null) return;

    try {
      // 1. Preguntamos a Firebase por los datos más recientes del Mayor
      final updatedUser = await _authRepository.getUser(state.user!.id);

      if (updatedUser != null) {
        // 2. Actualizamos el estado local.
        // Si el familiar hizo bien su trabajo, este updatedUser ya no tendrá linkCode.
        state = state.copyWith(user: updatedUser);
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excluye O, 0, I, 1 por accesibilidad visual
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }
}

final elderAuthControllerProvider =
StateNotifierProvider<ElderAuthController, AuthState>((ref) {
  return ElderAuthController(ref.read(authRepositoryProvider));
});
