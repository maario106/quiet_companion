import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True si en esta sesión no se pudo guardar la respuesta al consentimiento.
/// Solo en memoria: en el siguiente arranque se vuelve a preguntar.
final consentPromptDeferredProvider = StateProvider<bool>((ref) => false);
