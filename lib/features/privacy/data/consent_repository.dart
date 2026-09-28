import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/config/functions_config.dart';
import 'package:quiet_companion/core/constants/firestore_paths.dart';
import 'package:quiet_companion/core/models/companion_sharing.dart';

/// Decisiones del mayor sobre sus conversaciones.
class ConsentRepository {
  const ConsentRepository({
    required FirebaseFunctions functions,
    required FirebaseFirestore firestore,
  })  : _functions = functions,
        _firestore = firestore;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  /// Registra la respuesta a "¿guardo un resumen de nuestras conversaciones?".
  ///
  /// Va por la callable y no por Firestore: la hora del registro la pone el
  /// servidor (es la prueba del consentimiento), y retirarlo obliga a congelar
  /// datos que solo el servidor puede tocar (ADR-0030).
  Future<void> answer({required bool granted, required int textVersion}) async {
    try {
      await _functions
          .httpsCallable(kSetConversationConsentCallable)
          .call<dynamic>(<String, dynamic>{
        'granted': granted,
        'textVersion': textVersion,
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(error.message ?? 'No se ha podido guardar tu respuesta.');
    }
  }

  /// Qué ve el familiar (ADR-0031). Lo escribe el propio mayor sobre su
  /// documento; las reglas impiden que lo haga el familiar.
  Future<void> updateCompanionSharing(
      String uid, CompanionSharing level) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .update({'companionSharing': level.name});
  }

  /// Un plazo de la conversación, escrito por el propio mayor independiente
  /// (ADR-0034). [field] es una clave de `ConversationSettings`.
  Future<void> updateConversationSetting(
      String uid, String field, int value) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .update({'conversationSettings.$field': value});
  }
}

final consentRepositoryProvider = Provider<ConsentRepository>((ref) {
  return ConsentRepository(
    functions: FirebaseFunctions.instanceFor(region: kFunctionsRegion),
    firestore: FirebaseFirestore.instance,
  );
});
