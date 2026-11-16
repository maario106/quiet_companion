/// Estado propio del panel; los datos del mayor están en linkedElderProvider.
class DashboardState {
  /// Último fallo de guardado, para enseñarlo una vez. `null` = sin error.
  final String? errorMessage;

  const DashboardState({this.errorMessage});

  DashboardState copyWith({String? errorMessage}) {
    return DashboardState(errorMessage: errorMessage);
  }
}
