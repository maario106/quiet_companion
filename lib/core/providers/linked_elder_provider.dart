import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';

/// El mayor vinculado, en vivo, visto desde el familiar. Solo se reconstruye
/// si cambia el linkedElderId.
final linkedElderProvider = StreamProvider<UserModel?>((ref) {
  final elderId = ref.watch(
    currentUserProvider.select((user) => user.valueOrNull?.linkedElderId),
  );

  // Sin id, el documento del familiar aún no ha cargado: se queda en carga.
  if (elderId == null) return const Stream<UserModel?>.empty();

  return ref.watch(authRepositoryProvider).streamUser(elderId);
});
