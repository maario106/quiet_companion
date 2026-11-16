import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/user_preferences.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/repositories/auth_repository.dart';
import 'package:quiet_companion/features/dashboard/domain/dashboard_state.dart';

/// Escrituras del panel del familiar sobre el documento del mayor, un campo cada vez.
class DashboardController extends StateNotifier<DashboardState> {
  DashboardController(this._repository, this._elderId)
      : super(const DashboardState());

  final AuthRepository _repository;
  final String? _elderId;

  Future<void> updateElderName(String name) async {
    final elderId = _elderId;
    final trimmed = name.trim();
    if (elderId == null || trimmed.isEmpty) return;

    try {
      await _repository.updateName(elderId, trimmed);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: 'No se ha podido guardar el nombre.');
    }
  }

  /// [field] es una clave de `UserPreferences` (`volumeKey`, …).
  Future<void> updateElderPreference(String field, double value) async {
    final elderId = _elderId;
    if (elderId == null) return;

    try {
      await _repository.updatePreferenceField(elderId, field, value);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: 'No se ha podido guardar el ajuste.');
    }
  }

  /// La voz del mayor: una clave de ttsVoices.
  Future<void> updateElderVoice(String voice) async {
    final elderId = _elderId;
    if (elderId == null) return;

    try {
      await _repository.updatePreferenceField(
          elderId, UserPreferences.voiceKey, voice);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: 'No se ha podido guardar la voz.');
    }
  }

  /// Un plazo de la conversación. [field] es una clave de ConversationSettings.
  Future<void> updateConversationSetting(String field, int value) async {
    final elderId = _elderId;
    if (elderId == null) return;

    try {
      await _repository.updateConversationSettingField(elderId, field, value);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: 'No se ha podido guardar el plazo.');
    }
  }

  /// La pantalla lo llama tras enseñar el error, para no repetirlo.
  void clearError() => state = const DashboardState();
}

final dashboardControllerProvider =
    StateNotifierProvider<DashboardController, DashboardState>((ref) {
  final elderId = ref.watch(
    currentUserProvider.select((user) => user.valueOrNull?.linkedElderId),
  );
  return DashboardController(ref.watch(authRepositoryProvider), elderId);
});
