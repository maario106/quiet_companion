import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/conversation_record.dart';
import 'package:quiet_companion/core/repositories/conversation_repository.dart';

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository(FirebaseFirestore.instance);
});

/// Ventana que leen el panel y "Mi semana": el mes reciente. La semana se
/// calcula dentro; el resto sirve a la lista de conversaciones del panel.
const Duration kConversationWindow = Duration(days: 30);

/// Conversaciones del mayor [elderId] en la ventana, en vivo. Para el propio
/// mayor, su uid; para el familiar, el `linkedElderId`.
final conversationRecordsProvider = StreamProvider.autoDispose
    .family<List<ConversationRecord>, String>((ref, elderId) {
  final since = DateTime.now().subtract(kConversationWindow);
  return ref.watch(conversationRepositoryProvider).watchRecords(elderId, since);
});

/// Temas y resúmenes del mayor [elderId] en la ventana. Solo debe pedirlo
/// quien tenga acceso al nivel `full` (ADR-0031).
final conversationContentsProvider = StreamProvider.autoDispose
    .family<Map<String, ConversationContent>, String>((ref, elderId) {
  final since = DateTime.now().subtract(kConversationWindow);
  return ref
      .watch(conversationRepositoryProvider)
      .watchContents(elderId, since);
});
