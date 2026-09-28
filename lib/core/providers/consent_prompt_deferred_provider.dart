import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True si en esta sesión el mayor contestó a la pregunta del consentimiento
/// pero la respuesta no se pudo guardar (sin red, o sin la callable
/// desplegada). El enrutador le deja pasar a la pantalla principal y, como no
/// hay nada guardado, se le vuelve a preguntar en el siguiente arranque.
///
/// Solo vive en memoria a propósito: persistirlo en el dispositivo sería un
/// "no" que el servidor no conoce.
final consentPromptDeferredProvider = StateProvider<bool>((ref) => false);
