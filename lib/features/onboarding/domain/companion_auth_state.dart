enum CompanionAuthStatus { idle, loading, authenticated, linked, error }

class CompanionAuthState {
  final CompanionAuthStatus status;
  final String errorMessage;
  final String? companionId;
  final String? linkedElderId;

  const CompanionAuthState({
    this.status = CompanionAuthStatus.idle,
    this.errorMessage = '',
    this.companionId,
    this.linkedElderId,
  });

  static const _unset = Object();

  CompanionAuthState copyWith({
    CompanionAuthStatus? status,
    String? errorMessage,
    Object? companionId = _unset,
    Object? linkedElderId = _unset,
  }) {
    return CompanionAuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      companionId: companionId == _unset
          ? this.companionId
          : companionId as String?,
      linkedElderId: linkedElderId == _unset
          ? this.linkedElderId
          : linkedElderId as String?,
    );
  }
}
