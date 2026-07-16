import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True mientras la app está en background por una acción deliberada
/// (marcador de emergencia). Consumidor previsto: el disparador de fin de
/// sesión de pending.md §4, para no generar un resumen espurio cuando el
/// mayor sale al marcador. Ver pending.md §3.
///
/// Se pone a true justo antes de `dial()` y a false en
/// `AppLifecycleState.resumed`. Hoy nadie lo lee.
final intentionalBackgroundExitProvider = StateProvider<bool>((ref) => false);
