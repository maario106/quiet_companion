import 'package:quiet_companion/core/models/user_model.dart';

enum AuthStatus { checking, nonAuthenticated, authenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String errorMessage;

  const AuthState ({
    this.status = AuthStatus.checking,
    this.user,
    this.errorMessage = '',
  });

  AuthState copyWith ({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}