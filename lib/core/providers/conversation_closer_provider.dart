import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/config/functions_config.dart';
import 'package:quiet_companion/core/services/cloud_conversation_closer.dart';
import 'package:quiet_companion/core/services/conversation_closer.dart';

/// Dónde van las conversaciones al cerrarse (ADR-0028, ADR-0029).
final conversationCloserProvider = Provider<ConversationCloser>((ref) {
  return CloudConversationCloser(
    FirebaseFunctions.instanceFor(region: kFunctionsRegion),
  );
});
