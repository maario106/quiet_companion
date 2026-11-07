import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/config/functions_config.dart';
import 'package:quiet_companion/core/repositories/auth_repository.dart';

/// Declaración promocionada a core/ (deuda de pending.md §7): el provider se
/// consume desde SignOutButton (core/widgets), DashboardController,
/// ChatController y las pantallas de emergencia, además de onboarding.
/// La clase [AuthRepository] permanece en features/onboarding/data.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    functions: FirebaseFunctions.instanceFor(region: kFunctionsRegion),
  );
});

/// Cómo ha entrado quien usa el móvil: anónimo o con Google. Lo lee
/// "Mi cuenta" (`AccountScreen`).
final authAccountProvider = StreamProvider<AuthAccount?>((ref) {
  return ref.watch(authRepositoryProvider).accountChanges();
});
