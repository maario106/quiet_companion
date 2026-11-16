import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/conversation_record.dart';
import 'package:quiet_companion/core/models/elder_memory.dart';
import 'package:quiet_companion/core/repositories/conversation_repository.dart';

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository(FirebaseFirestore.instance);
});

/// Ventana de lectura del panel y de "Mi semana".
const Duration kConversationWindow = Duration(days: 30);

/// Conversaciones del mayor [elderId] en la ventana, en vivo.
final conversationRecordsProvider = StreamProvider.autoDispose
    .family<List<ConversationRecord>, String>((ref, elderId) {
  final since = DateTime.now().subtract(kConversationWindow);
  return ref.watch(conversationRepositoryProvider).watchRecords(elderId, since);
});

/// Temas y resúmenes del mayor [elderId]. Solo con el nivel full.
final conversationContentsProvider = StreamProvider.autoDispose
    .family<Map<String, ConversationContent>, String>((ref, elderId) {
  final since = DateTime.now().subtract(kConversationWindow);
  return ref
      .watch(conversationRepositoryProvider)
      .watchContents(elderId, since);
});

/// Memoria del mayor [elderId]. Solo con el nivel full.
final elderMemoryProvider =
    StreamProvider.autoDispose.family<ElderMemory?, String>((ref, elderId) {
  return ref.watch(conversationRepositoryProvider).watchMemory(elderId);
});
