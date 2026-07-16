import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/models/user_model.dart';

/// Fila de la pantalla de ajustes del mayor, modelada de forma declarativa:
/// cada fila lleva su propio predicado de visibilidad sobre el [UserModel].
/// Añadir un ajuste futuro = añadir una fila aquí, cero refactor.
class SettingsRow {
  const SettingsRow({
    required this.title,
    required this.value,
    required this.visible,
    required this.route,
  });

  final String title;

  /// Valor actual mostrado bajo el título (p. ej. el nombre del contacto).
  final String Function(UserModel user) value;

  /// Predicado de visibilidad por fila, NO por pantalla: la pantalla se
  /// muestra si al menos una fila es visible.
  final bool Function(UserModel user) visible;

  /// Subpantalla a la que navega la fila. Todo ajuste se edita en su propia
  /// subpantalla con confirmación; nada de edición inline.
  final String route;
}

/// Única fuente de verdad de las filas de ajustes. Vive en core/ porque la
/// consumen dos features que no pueden acoplarse entre sí: conversation
/// (visibilidad del botón de ajustes de HomeScreen) y settings (render de la
/// lista). Si botón y pantalla calcularan su visibilidad por separado,
/// acabarían divergiendo.
final List<SettingsRow> settingsRows = [
  SettingsRow(
    title: 'Contacto de emergencia',
    value: (user) => user.emergencyContact?.name ?? 'Sin configurar',
    // Oculta exactamente cuando el contacto no es editable: viene impuesto
    // por la vinculación. Deriva del mismo `source` que gobierna la
    // precedencia de escritura, sin criterios paralelos (role, companionId).
    visible: (user) =>
        user.emergencyContact?.source != EmergencyContactSource.companion,
    route: '/settings/emergency-contact',
  ),
];

/// Filas visibles para [user]. La usan HomeScreen (botón visible si hay ≥ 1
/// fila) y SettingsScreen (qué renderizar) — la misma función en ambos sitios.
List<SettingsRow> visibleSettingsRows(UserModel user) =>
    settingsRows.where((row) => row.visible(user)).toList();
