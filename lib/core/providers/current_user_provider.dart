import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/constants/firestore_paths.dart';
import 'package:quiet_companion/core/models/user_model.dart';

// Stream del usuario autenticado en Firebase. Emite el [User] actual o null
// cuando no hay sesión iniciada. Es la base para [currentUserProvider].
final firebaseAuthUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Single Source of Truth del documento del usuario logueado en Firestore.
// Escucha [firebaseAuthUserProvider] y, cuando hay un uid, se suscribe en
// tiempo real a `users/{uid}` mapeándolo a [UserModel]. Si no hay sesión o el
// documento aún no existe, emite null en lugar de lanzar un error.
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authUser = ref.watch(firebaseAuthUserProvider).valueOrNull;

  if (authUser == null) {
    return Stream<UserModel?>.value(null);
  }

  final uid = authUser.uid;
  return FirebaseFirestore.instance
      .collection(FirestorePaths.usersCollection)
      .doc(uid)
      .snapshots()
      .map((snap) => snap.exists && snap.data() != null
          ? UserModel.fromMap(uid, snap.data()!)
          : null);
});
