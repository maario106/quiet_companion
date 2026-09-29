import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/providers/tts_service_provider.dart';
import 'package:quiet_companion/core/services/tts_service.dart';

/// Calla la voz de la app al salir de una pantalla que lee en voz alta.
///
/// El [TtsService] es de toda la app: sin esto, un "Escuchar" largo (el texto
/// del consentimiento, "Mi semana") seguía sonando en la pantalla siguiente, y
/// si el mayor abría el micrófono el reconocedor oía la voz de la app.
class StopSpeakingOnExit extends ConsumerStatefulWidget {
  const StopSpeakingOnExit({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StopSpeakingOnExit> createState() => _StopSpeakingOnExitState();
}

class _StopSpeakingOnExitState extends ConsumerState<StopSpeakingOnExit> {
  // Se guarda al crear: en `dispose` ya no se debe usar `ref`.
  late final TtsService _tts;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsServiceProvider);
  }

  @override
  void dispose() {
    unawaited(_tts.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
