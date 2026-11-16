import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:quiet_companion/core/config/functions_config.dart';

/// Conexión a los emuladores: `flutter run --dart-define=USE_EMULATOR=true`.
/// En un móvil por USB hace falta `adb reverse` de los puertos 9099, 8080 y 5001.

const bool _requested = bool.fromEnvironment('USE_EMULATOR');

/// Anfitrión donde escuchan los emuladores, visto desde el dispositivo.
const String _host = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '127.0.0.1',
);

/// Puertos declarados en `firebase.json`. Si se cambian allí, aquí también.
const int _authPort = 9099;
const int _firestorePort = 8080;
const int _functionsPort = 5001;

/// Si esta ejecución habla con los emuladores.
bool get useEmulator => _requested && !kReleaseMode;

/// Redirige Auth, Firestore y Functions a los emuladores; antes de la primera
/// operación. En release con la bandera puesta falla a propósito.
Future<void> connectToEmulators() async {
  if (_requested && kReleaseMode) {
    throw StateError(
      'USE_EMULATOR=true en un build de release. Los emuladores solo existen '
      'en la máquina de desarrollo: recompila sin esa bandera.',
    );
  }
  if (!useEmulator) return;

  await FirebaseAuth.instance.useAuthEmulator(_host, _authPort);
  FirebaseFirestore.instance.useFirestoreEmulator(_host, _firestorePort);
  // instanceFor cachea por (app, región): se redirige la misma instancia.
  FirebaseFunctions.instanceFor(region: kFunctionsRegion)
      .useFunctionsEmulator(_host, _functionsPort);

  debugPrint('[EMU] Auth, Firestore y Functions apuntando a $_host.');
}
