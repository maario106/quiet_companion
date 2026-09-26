import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:quiet_companion/core/config/functions_config.dart';

/// Conexión de la app a la suite de emuladores de Firebase.
///
/// Existe para poder recorrer la app entera —alta del mayor, código,
/// vinculación, panel, ajustes— contra las reglas de seguridad **reales** y
/// datos de mentira, sin tocar el proyecto de producción. Es el único sitio
/// donde se comprueba que reglas, callable y cliente encajan: los tests
/// verifican cada pieza por separado y ninguno los ve hablar entre sí.
///
/// Se activa solo al arrancar así:
///
///     flutter run --dart-define=USE_EMULATOR=true
///
/// Con un móvil por USB hace falta además redirigir los puertos, porque el
/// `127.0.0.1` del teléfono no es el del portátil:
///
///     adb reverse tcp:9099 tcp:9099   # auth
///     adb reverse tcp:8080 tcp:8080   # firestore
///     adb reverse tcp:5001 tcp:5001   # functions
///
/// En un emulador de Android (AVD) no hacen falta: se pasa
/// `--dart-define=EMULATOR_HOST=10.0.2.2`, que es como el AVD ve al anfitrión.

/// Valor crudo de la bandera, antes de comprobar el modo de compilación.
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

/// Redirige Auth, Firestore y Functions a los emuladores.
///
/// Debe llamarse después de `Firebase.initializeApp` y **antes** de la primera
/// lectura o escritura: los SDK fijan el destino en la primera operación.
///
/// Un build de release con la bandera puesta muere aquí a propósito. Apuntaría
/// a un `127.0.0.1` que en el móvil de un mayor no existe, así que la app
/// estaría rota de todas formas — pero de forma silenciosa y difícil de
/// diagnosticar. Mejor que reviente en tu mesa, en el primer arranque.
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
  // Misma instancia y misma región que usan `AuthRepository` y el
  // sintetizador: `instanceFor` cachea por (app, región), así que redirigirla
  // aquí redirige la que ellos reciben.
  FirebaseFunctions.instanceFor(region: kFunctionsRegion)
      .useFunctionsEmulator(_host, _functionsPort);

  debugPrint('[EMU] Auth, Firestore y Functions apuntando a $_host.');
}
