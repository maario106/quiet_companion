import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/config/functions_config.dart';
import 'package:quiet_companion/core/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    functions: FirebaseFunctions.instanceFor(region: kFunctionsRegion),
  );
});

/// Cómo ha entrado el usuario: anónimo o con Google.
final authAccountProvider = StreamProvider<AuthAccount?>((ref) {
  return ref.watch(authRepositoryProvider).accountChanges();
});
