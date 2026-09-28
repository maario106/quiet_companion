import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quiet_companion/core/constants/firestore_paths.dart';
import 'package:quiet_companion/core/models/conversation_record.dart';
import 'package:quiet_companion/core/models/elder_memory.dart';

/// Lectura de las conversaciones analizadas de un mayor. Solo lectura: las
/// escribe `closeConversation` (ADR-0029).
///
/// En `core/` porque la leen dos *features* que no pueden acoplarse: el panel
/// del familiar y "Mi semana" del mayor (ADR-0033). Qué puede leer cada uno lo
/// deciden las reglas (ADR-0031); quien llama no debe pedir lo que su nivel no
/// le permite, o el stream acabará en error de permisos.
class ConversationRepository {
  const ConversationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _sub(String elderId, String name) =>
      _firestore
          .collection(FirestorePaths.usersCollection)
          .doc(elderId)
          .collection(name);

  /// Conversaciones terminadas desde [since], de la más reciente a la más
  /// antigua.
  Stream<List<ConversationRecord>> watchRecords(
      String elderId, DateTime since) {
    return _sub(elderId, FirestorePaths.conversationsCollection)
        .where('endedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('endedAt', descending: true)
        .snapshots()
        .map((snap) => [
              for (final doc in snap.docs)
                if (ConversationRecord.fromMapOrNull(doc.id, doc.data())
                    case final record?)
                  record,
            ]);
  }

  /// Lo que el asistente recuerda del mayor. null si aún no hay nada.
  Stream<ElderMemory?> watchMemory(String elderId) {
    return _sub(elderId, FirestorePaths.memoryCollection)
        .doc(FirestorePaths.memoryProfileDoc)
        .snapshots()
        .map((snap) => ElderMemory.fromMapOrNull(snap.data()));
  }

  /// Temas y resúmenes desde [since], por id de conversación.
  Stream<Map<String, ConversationContent>> watchContents(
      String elderId, DateTime since) {
    return _sub(elderId, FirestorePaths.conversationContentsCollection)
        .where('endedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .snapshots()
        .map((snap) => {
              for (final doc in snap.docs)
                if (ConversationContent.fromMapOrNull(doc.id, doc.data())
                    case final content?)
                  content.id: content,
            });
  }
}
