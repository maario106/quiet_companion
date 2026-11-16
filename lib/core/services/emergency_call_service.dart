import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Número europeo de emergencias.
const String kEmergencyNumber = '112';

/// URI tel: seguro; Uri(scheme:, path:) escapa # y *, que truncarían la marcación.
Uri buildTelUri(String phoneE164) => Uri(scheme: 'tel', path: phoneE164);

/// Abre el marcador del sistema; interfaz para inyectar un fake en los tests.
abstract interface class EmergencyCallService {
  /// Abre el marcador con [phoneE164]. Devuelve false si no se puede marcar; no lanza.
  Future<bool> dial(String phoneE164);
}

/// Sobre url_launcher. Abre el marcador, nunca llama directamente.
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
