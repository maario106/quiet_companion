import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/companion_sharing.dart';
import 'package:quiet_companion/core/providers/consent_prompt_deferred_provider.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/features/privacy/data/consent_repository.dart';
import 'package:quiet_companion/features/privacy/domain/consent_text.dart';

class ConsentState {
  const ConsentState({this.saving = false, this.errorMessage});

  final bool saving;
  final String? errorMessage;
}

/// Decisiones del mayor sobre sus conversaciones. El resultado vuelve por
/// currentUserProvider.
class ConsentController extends StateNotifier<ConsentState> {
  ConsentController(this._repository, this._uid, this._deferPrompt)
      : super(const ConsentState());

  final ConsentRepository _repository;
  final String? _uid;
  final void Function() _deferPrompt;

  /// Responde a la pregunta; true si quedó guardada. Un "Ahora no" que no se
  /// guarda deja pasar igual y se vuelve a preguntar en el siguiente arranque.
  Future<bool> answer({required bool granted, bool deferOnFailure = false}) async {
    if (state.saving) return false;
    state = const ConsentState(saving: true);
    try {
      await _repository.answer(
        granted: granted,
        textVersion: kConsentTextVersion,
      );
      if (mounted) state = const ConsentState();
      return true;
    } catch (_) {
      if (!granted && deferOnFailure) {
        _deferPrompt();
        if (mounted) state = const ConsentState();
        return false;
      }
      if (mounted) {
        state = const ConsentState(
          errorMessage:
              'No se ha podido guardar. Comprueba la conexión e inténtalo otra vez.',
        );
      }
      return false;
    }
  }

  Future<bool> setCompanionSharing(CompanionSharing level) =>
      _write((uid) => _repository.updateCompanionSharing(uid, level));

  /// [field] es una clave de `ConversationSettings`.
  Future<bool> setConversationSetting(String field, int value) =>
      _write((uid) => _repository.updateConversationSetting(uid, field, value));

  Future<bool> _write(Future<void> Function(String uid) write) async {
    final uid = _uid;
    if (uid == null || state.saving) return false;
    state = const ConsentState(saving: true);
    try {
      await write(uid);
      if (mounted) state = const ConsentState();
      return true;
    } catch (_) {
      if (mounted) {
        state = const ConsentState(
          errorMessage: 'No se ha podido guardar. Inténtalo otra vez.',
        );
      }
      return false;
    }
  }
}

final consentControllerProvider =
    StateNotifierProvider.autoDispose<ConsentController, ConsentState>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u.valueOrNull?.id));
  return ConsentController(
    ref.watch(consentRepositoryProvider),
    uid,
    () => ref.read(consentPromptDeferredProvider.notifier).state = true,
  );
});
