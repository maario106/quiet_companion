import 'package:quiet_companion/core/models/user_model.dart';

/// Rutas del familiar sin vincular; se dejan pasar aunque haya sesión de mayor.
const Set<String> companionEntryPaths = {
  '/companion/choice',
  '/companion/register',
  '/companion/login',
};

/// Decisión de redirección, como función pura. [consentPromptDeferred] deja
/// pasar al mayor si en esta sesión no se pudo guardar su consentimiento.
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

  // Familiar vinculado: el panel y sus subpantallas.
  if (companionLinked) {
    return location.startsWith('/dashboard') ? null : '/dashboard';
  }
  // Con sesión pero sin vincular: pantalla del código.
  if (companionAuthenticated) {
    return location == '/companion/pairing' ? null : '/companion/pairing';
  }

  // Mayor
  if (companionEntryPaths.contains(location)) return null;

  final elder = elderUser?.role == UserRole.elder ? elderUser : null;
  final autonomy = elder?.autonomy;
  final isFullyOnboarded = autonomy == AutonomyStatus.independent ||
      (autonomy == AutonomyStatus.dependent && elder?.linkCode == null);

  if (elderAuthenticated && isFullyOnboarded) {
    // Una sola vez: la pregunta del consentimiento ("Ahora no" también cuenta).
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
