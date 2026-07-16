import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';
import 'companion_auth_state.dart';
import '../data/auth_repository.dart';

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
        errorMessage: e.toString(),
      );
    }
  }

  /// [name] y [phoneNumber] (E.164) se desnormalizan en el documento del
  /// mayor al vincular, como su contacto de emergencia.
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
        errorMessage: e.toString(),
      );
    }
  }

  void signOut() {
    state = const CompanionAuthState();
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
