import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/constants/firestore_paths.dart';
import 'package:quiet_companion/core/models/user_model.dart';

final firebaseAuthUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Documento users/{uid} en vivo; null sin sesión o sin documento.
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
