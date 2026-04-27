import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/features/onboarding/domain/companion_auth_controller.dart';
import 'package:quiet_companion/features/onboarding/data/auth_repository.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/features/dashboard/domain/dashboard_state.dart';

class DashboardController extends StateNotifier<DashboardState> {
  DashboardController(this._repository, this._elderId) : super(const DashboardState()) {
    _init();
  }

  final AuthRepository _repository;
  final String? _elderId;

  Future<void> _init() async {
    if (_elderId == null) {
      state = state.copyWith(status: DashboardStatus.error, errorMessage: 'No hay mayor vinculado');
      return;
    }
    await refreshElderData();
  }

  Future<void> refreshElderData() async {
    try {
      final elder = await _repository .getUser(_elderId!);
      state = state.copyWith(status: DashboardStatus.loaded, linkedElder: elder);
    } catch (e) {
      state = state.copyWith(status: DashboardStatus.error, errorMessage: e.toString());
    }
  }

  // Method CLAVE: Actualiza las preferencias en Firebase
  Future<void> updateElderPreferences(UserPreferences newPrefs) async {
    if (state.linkedElder == null) return;

    final updatedElder = state.linkedElder!.copyWith(preferences: newPrefs);

    // Optimizamos la UI: actualizamos localmente primero
    state = state.copyWith(linkedElder: updatedElder);

    try {
      await _repository.saveUser(updatedElder);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error al guardar: $e');
    }
  }
}

// Provider que depende del CompanionAuthController para saber a qué mayor mirar
final dashboardControllerProvider = StateNotifierProvider<DashboardController, DashboardState>((ref) {
  final companionState = ref.watch(companionAuthControllerProvider);
  final elderId = companionState.linkedElderId; // Obtenemos el ID del abuelo desde el perfil del familiar

  return DashboardController(
    ref.read(authRepositoryProvider),
    elderId,
  );
});