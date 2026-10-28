import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_companion/core/services/emergency_call_service.dart';

// El plugin url_launcher no se testea aquí (exigiría mockear
// UrlLauncherPlatform); se testea la construcción del URI, que es una
// función pura, y para lo demás existe la interfaz EmergencyCallService.
void main() {
  group('buildTelUri', () {
    test('regresión: un # se escapa en vez de truncar la marcación', () {
      // Uri.parse('tel:600#123') interpretaría #123 como fragmento y marcaría
      // solo 600. Uri(scheme:, path:) lo escapa.
      final uri = buildTelUri('600#123');
      expect(uri.toString(), equals('tel:600%23123'));
      expect(uri.fragment, isEmpty);
    });
  });
}
