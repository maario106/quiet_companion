import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Número europeo de emergencias. Siempre disponible en la pantalla de
/// emergencia, tenga o no el mayor un contacto configurado.
const String kEmergencyNumber = '112';

/// Construye el URI `tel:` de forma segura. Función pura, separada para poder
/// testearla sin el plugin. `Uri(scheme:, path:)` escapa caracteres como `#`
/// y `*`; `Uri.parse('tel:$numero')` no, y un `#` en el número truncaría la
/// marcación en silencio.
Uri buildTelUri(String phoneE164) => Uri(scheme: 'tel', path: phoneE164);

/// Borde de plataforma para abrir el marcador del sistema. Hermano de
/// [PermissionService] / [TtsService]. Es una interfaz para que los widget
/// tests inyecten un fake sin tocar el plugin `url_launcher`.
abstract interface class EmergencyCallService {
  /// Abre el marcador del sistema con [phoneE164] premarcado.
  /// Devuelve false si el dispositivo no puede marcar (p. ej. tablet sin SIM,
  /// o `<queries>` mal configurado en el manifest).
  /// No lanza excepciones: el fallo es un caso de uso esperado, no un error.
  Future<bool> dial(String phoneE164);
}

/// Implementación real sobre `url_launcher`. Nunca usa ACTION_CALL / llamada
/// directa: el marcador nativo pide la confirmación del mayor, evita el
/// permiso CALL_PHONE y la SecurityException de Android con números de
/// emergencia.
class UrlLauncherEmergencyCallService implements EmergencyCallService {
  @override
  Future<bool> dial(String phoneE164) async {
    final uri = buildTelUri(phoneE164);
    try {
      if (!await canLaunchUrl(uri)) return false;
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      // La UI no debe ver excepciones de plugin.
      return false;
    }
  }
}

final emergencyCallServiceProvider =
    Provider<EmergencyCallService>((ref) => UrlLauncherEmergencyCallService());
