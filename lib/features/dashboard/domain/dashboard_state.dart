import 'package:quiet_companion/core/models/user_model.dart';

enum DashboardStatus { loading, loaded, error }

class DashboardState {
  final DashboardStatus status;
  final UserModel? linkedElder;
  final String errorMessage;

  const DashboardState({
    this.status = DashboardStatus.loading,
    this.linkedElder,
    this.errorMessage = '',
  });

  DashboardState copyWith({
    DashboardStatus? status,
    UserModel? linkedElder,
    String? errorMessage,
  }) {
    return DashboardState(
      status: status ?? this.status,
      linkedElder: linkedElder ?? this.linkedElder,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}