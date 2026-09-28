/// Estado propio del panel: solo lo que no está en Firestore.
///
/// Los datos del mayor no viven aquí sino en `linkedElderProvider`: guardar
/// una copia en el controlador es lo que hacía que el panel enseñara —y
/// reescribiera— valores viejos (ADR-0027).
class DashboardState {
  /// Último fallo de guardado, para enseñarlo una vez. `null` = sin error.
  final String? errorMessage;

  const DashboardState({this.errorMessage});

  DashboardState copyWith({String? errorMessage}) {
    return DashboardState(errorMessage: errorMessage);
  }
}
