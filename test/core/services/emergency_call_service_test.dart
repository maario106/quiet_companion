import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/services/emergency_call_service.dart';

// El plugin url_launcher no se testea aquí (exigiría mockear
// UrlLauncherPlatform); se testea la construcción del URI, que es una
// función pura, y para lo demás existe la interfaz EmergencyCallService.
void main() {
  group('buildTelUri', () {
    test('número E.164 → tel: con el número intacto', () {
      expect(buildTelUri('+34600123456').toString(),
          equals('tel:+34600123456'));
    });

    test('el 112 se construye tal cual', () {
      expect(buildTelUri(kEmergencyNumber).toString(), equals('tel:112'));
    });

    test('regresión: un # se escapa en vez de truncar la marcación', () {
      // Uri.parse('tel:600#123') interpretaría #123 como fragmento y marcaría
      // solo 600. Uri(scheme:, path:) lo escapa.
      final uri = buildTelUri('600#123');
      expect(uri.toString(), equals('tel:600%23123'));
      expect(uri.fragment, isEmpty);
    });

    test('regresión: un * no rompe el URI', () {
      final uri = buildTelUri('*21#');
      expect(uri.fragment, isEmpty);
      expect(uri.toString(), isNot(contains('#')));
    });
  });
}
