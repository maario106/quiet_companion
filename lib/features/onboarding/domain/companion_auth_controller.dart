import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';
import 'companion_auth_state.dart';
import 'package:quiet_companion/core/repositories/auth_repository.dart';

class CompanionAuthController extends StateNotifier<CompanionAuthState> {
  CompanionAuthController(this._authRepository)
      : super(const CompanionAuthState()) {
    _init();
  }

  final AuthRepository _authRepository;

  Future<void> _init() async {
    final uid = _authRepository.currentUid();
    if (uid == null) return;
    final userData = await _authRepository.getUser(uid);
    if (userData == null || userData.role != UserRole.companion) return;
    state = state.copyWith(
      status: userData.linkedElderId != null
          ? CompanionAuthStatus.linked
          : CompanionAuthStatus.authenticated,
      companionId: uid,
      linkedElderId: userData.linkedElderId,
    );
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(status: CompanionAuthStatus.loading, errorMessage: '');
    try {
      final uid = await _authRepository.signInWithEmail(email, password);
      await _authRepository.ensureCompanionUserDoc(uid);

      final userData = await _authRepository.getUser(uid);

      state = state.copyWith(
        status: userData?.linkedElderId != null
            ? CompanionAuthStatus.linked
            : CompanionAuthStatus.authenticated,
        companionId: uid,
        linkedElderId: userData?.linkedElderId,
      );
    } catch (e) {
      state = state.copyWith(
        status: CompanionAuthStatus.error,
        errorMessage: _signInError(e),
      );
    }
  }

  /// [name] y [phoneNumber] (E.164) se copian al mayor al vincular.
  Future<void> register(
    String email,
    String password, {
    required String name,
    required String phoneNumber,
  }) async {
    state = state.copyWith(status: CompanionAuthStatus.loading, errorMessage: '');
    try {
      final uid = await _authRepository.registerWithEmail(email, password);
      await _authRepository.ensureCompanionUserDoc(
        uid,
        name: name,
        phoneNumber: phoneNumber,
      );
      state = state.copyWith(
        status: CompanionAuthStatus.authenticated,
        companionId: uid,
      );
    } catch (e) {
      state = state.copyWith(
        status: CompanionAuthStatus.error,
        errorMessage: _registerError(e),
      );
    }
  }

  void signOut() {
    state = const CompanionAuthState();
  }

  Future<void> linkWithCode(String code) async {
    state = state.copyWith(status: CompanionAuthStatus.loading, errorMessage: '');
    try {
      // La callable devuelve el id del mayor vinculado.
      final elderId = await _authRepository.linkCompanionToElder(code);

      state = state.copyWith(
        status: CompanionAuthStatus.linked,
        linkedElderId: elderId,
      );
    } catch (e) {
      state = state.copyWith(
        status: CompanionAuthStatus.error,
        errorMessage: e is PairingException
            ? e.message
            : 'No se ha podido vincular. Inténtalo otra vez.',
      );
    }
  }
}

// Firebase Auth da sus errores en inglés; al familiar se le dicen en español.

String _signInError(Object error) => switch (_authCode(error)) {
      // No se distingue un correo sin cuenta de una contraseña equivocada.
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' ||
      'invalid-email' =>
        'Correo o contraseña incorrectos. Inténtalo otra vez.',
      final code => _commonAuthError(code) ??
          'No se ha podido iniciar sesión. Inténtalo otra vez.',
    };

String _registerError(Object error) => switch (_authCode(error)) {
      'email-already-in-use' =>
        'Ya hay una cuenta con ese correo. Si es tuya, inicia sesión.',
      'invalid-email' => 'Ese correo no es válido.',
      'weak-password' =>
        'La contraseña es demasiado débil. Prueba con otra más larga.',
      final code => _commonAuthError(code) ??
          'No se ha podido crear la cuenta. Inténtalo otra vez.',
    };

String? _authCode(Object error) =>
    error is FirebaseAuthException ? error.code : null;

String? _commonAuthError(String? code) => switch (code) {
      'network-request-failed' =>
        'No hay conexión. Compruébala e inténtalo otra vez.',
      'too-many-requests' =>
        'Demasiados intentos seguidos. Espera unos minutos y vuelve a probar.',
      _ => null,
    };

final companionAuthControllerProvider =
    StateNotifierProvider<CompanionAuthController, CompanionAuthState>((ref) {
  return CompanionAuthController(ref.read(authRepositoryProvider));
});
