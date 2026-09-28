import 'package:quiet_companion/core/models/user_model.dart';

/// Rutas del familiar antes de estar vinculado: se dejan pasar aunque el
/// dispositivo tenga sesión anónima de mayor.
const Set<String> companionEntryPaths = {
  '/companion/choice',
  '/companion/register',
  '/companion/login',
};

/// Decisión de redirección de la app, como función pura.
///
/// Vive fuera de `RouterNotifier` para que el test pruebe **esta** lógica y no
/// una copia: antes, `router_redirect_test.dart` reimplementaba las
/// condiciones a mano, y cualquier cambio del enrutador podía dejar el test en
/// verde probando una versión antigua.
///
/// [elderUser] es el documento del mayor ya resuelto (el dato en vivo o, en el
/// hueco antes de que llegue, el del controlador). Si no es de rol mayor, se
/// ignora.
///
/// [consentPromptDeferred] es true si en esta sesión no se pudo guardar la
/// respuesta a la pregunta del consentimiento (sin red o sin la callable
/// desplegada): se deja pasar al mayor y se le vuelve a preguntar en el
/// siguiente arranque, en vez de encerrarlo en esa pantalla.
String? routeRedirect({
  required bool elderCheckingAuth,
  required bool companionLinked,
  required bool companionAuthenticated,
  required UserModel? elderUser,
  required bool elderAuthenticated,
  required bool consentPromptDeferred,
  required String location,
}) {
  // La app está arrancando (login anónimo del mayor): se espera.
  if (elderCheckingAuth) return null;

  // --- FAMILIAR ---
  // Vinculado: su sitio es el panel y sus subpantallas (ADR-0033).
  if (companionLinked) {
    return location.startsWith('/dashboard') ? null : '/dashboard';
  }
  // Con sesión pero sin vincular: pantalla del código.
  if (companionAuthenticated) {
    return location == '/companion/pairing' ? null : '/companion/pairing';
  }

  // --- MAYOR ---
  if (companionEntryPaths.contains(location)) return null;

  final elder = elderUser?.role == UserRole.elder ? elderUser : null;
  final autonomy = elder?.autonomy;
  final isFullyOnboarded = autonomy == AutonomyStatus.independent ||
      (autonomy == AutonomyStatus.dependent && elder?.linkCode == null);

  if (elderAuthenticated && isFullyOnboarded) {
    // Una sola vez, al terminar de elegir modo o de vincularse: la pregunta
    // del consentimiento (ADR-0030). "Ahora no" también cuenta como respuesta.
    final mustAskConsent =
        elder?.conversationConsent == null && !consentPromptDeferred;
    if (mustAskConsent) {
      return location.startsWith('/consent') ? null : '/consent';
    }
    final isEntryScreen = location == '/splash' ||
        location == '/onboarding' ||
        location.startsWith('/consent');
    return isEntryScreen ? '/home' : null;
  }

  // Arranque limpio: onboarding.
  if (location == '/onboarding') return null;
  return '/onboarding';
}
