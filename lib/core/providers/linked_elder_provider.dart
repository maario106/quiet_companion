import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';

/// El mayor vinculado, en tiempo real, visto desde el dispositivo del familiar.
///
/// Es al familiar lo que [currentUserProvider] es al propio usuario (ADR-0009):
/// la única fuente de verdad del documento del mayor en el panel. Sustituye a
/// la lectura única que hacía `DashboardController`, que dejaba al familiar
/// viendo —y reescribiendo— una copia que envejecía en cuanto el mayor cambiaba
/// algo desde su propio móvil (ADR-0027).
///
/// Solo se reconstruye si cambia el `linkedElderId` del familiar, no con
/// cualquier cambio de su documento (ADR-0023).
final linkedElderProvider = StreamProvider<UserModel?>((ref) {
  final elderId = ref.watch(
    currentUserProvider.select((user) => user.valueOrNull?.linkedElderId),
  );

  // Sin id todavía: el documento del familiar no ha cargado. Un stream vacío
  // deja el provider en carga en vez de afirmar que no hay mayor.
  if (elderId == null) return const Stream<UserModel?>.empty();

  return ref.watch(authRepositoryProvider).streamUser(elderId);
});
