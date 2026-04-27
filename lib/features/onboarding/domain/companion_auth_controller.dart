import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'companion_auth_state.dart';
import '../data/auth_repository.dart';
import 'package:quiet_companion/core/models/user_model.dart';

class CompanionAuthController extends StateNotifier<CompanionAuthState> {
  CompanionAuthController(this._authRepository)
      : super(const CompanionAuthState());

  final AuthRepository _authRepository;

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(status: CompanionAuthStatus.loading, errorMessage: '');
    try {
      final uid = await _authRepository.signInWithEmail(email, password);
      await _authRepository.ensureCompanionUserDoc(uid);

      final userData = await _authRepository.getUser(uid);

      state = state.copyWith(
        status: CompanionAuthStatus.authenticated,
        companionId: uid,
        linkedElderId: userData?.linkedElderId,
      );
    } catch (e) {
      state = state.copyWith(
        status: CompanionAuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> register(String email, String password) async {
    state = state.copyWith(status: CompanionAuthStatus.loading, errorMessage: '');
    try {
      final uid = await _authRepository.registerWithEmail(email, password);
      await _authRepository.ensureCompanionUserDoc(uid);
      state = state.copyWith(
        status: CompanionAuthStatus.authenticated,
        companionId: uid,
      );
    } catch (e) {
      state = state.copyWith(
        status: CompanionAuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> linkWithCode(String code) async {
    state = state.copyWith(status: CompanionAuthStatus.loading, errorMessage: '');
    try {
      // TODO: Considerar cambio a cloud function
      await _authRepository.linkCompanionToElder(code, state.companionId!);
      final updatedUser = await _authRepository.getUser(state.companionId!);

      state = state.copyWith(
        status: CompanionAuthStatus.linked,
        linkedElderId: updatedUser?.linkedElderId,
      );
    } catch (e) {
      state = state.copyWith(
        status: CompanionAuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}

final companionAuthControllerProvider =
    StateNotifierProvider<CompanionAuthController, CompanionAuthState>((ref) {
  return CompanionAuthController(ref.read(authRepositoryProvider));
});
