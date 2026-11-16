import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True mientras la app está en segundo plano por abrir el marcador de emergencia.
final intentionalBackgroundExitProvider = StateProvider<bool>((ref) => false);
