import 'package:quiet_companion/core/config/preference_scales.dart';
import 'package:quiet_companion/core/models/companion_sharing.dart';
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
  // Accesibilidad local del mayor (ADR-0013, CU-05/RF-5): las mismas tres
  // magnitudes que el familiar mueve con deslizadores, aquí como escalas de
  // peldaños con nombre. Se derivan de `preferenceScales` en vez de
  // escribirse a mano para que añadir un ajuste siga siendo un solo sitio.
  //
  // Visibles para TODO mayor, vinculado o independiente. La alternativa
  // (limitarlas al independiente, que es la letra de CU-05) dejaba sin
  // ninguna fila —y por tanto sin botón de ajustes, `home_screen.dart:57`— al
  // mayor vinculado cuyo contacto de emergencia fija el familiar. Que dos
  // personas puedan tocar el mismo valor no necesita arbitraje: a diferencia
  // del contacto de emergencia, aquí no hay autoridad que proteger, y gana la
  // última escritura.
  for (final scale in preferenceScales)
    SettingsRow(
      title: scale.title,
      value: (user) => scale.labelFor(user.preferences),
      visible: (user) => true,
      route: scale.route,
    ),
  // El consentimiento sobre las conversaciones (ADR-0030). Visible para todo
  // mayor, vinculado o no: es suyo, y retirarlo tiene que ser tan fácil como
  // darlo. También sirve a quien dijo "Ahora no" y cambia de idea.
  SettingsRow(
    title: 'Guardar mis conversaciones',
    value: (user) => user.hasConversationConsent ? 'Sí' : 'No',
    visible: (user) => true,
    route: '/settings/conversations',
  ),
  // Lo decide solo el mayor, y solo tiene sentido si hay familiar y algo que
  // ver (ADR-0031).
  SettingsRow(
    title: 'Qué ve mi familiar',
    value: (user) => (user.companionSharing ?? CompanionSharing.none).label,
    visible: (user) =>
        user.linkedCompanionId != null && user.hasConversationConsent,
    route: '/settings/companion-sharing',
  ),
  // Los plazos los fija el propio mayor solo en modo independiente; en modo
  // vinculado los gestiona su familiar desde el panel (ADR-0034, ADR-0007).
  SettingsRow(
    title: 'Cuándo termina una conversación',
    value: (user) =>
        'Tras ${user.effectiveConversationSettings.inactivityLabel} en silencio',
    visible: _independentWithConsent,
    route: '/settings/conversation-wait',
  ),
  SettingsRow(
    title: 'Cuánto tiempo se guardan',
    value: (user) => user.effectiveConversationSettings.retentionLabel,
    visible: _independentWithConsent,
    route: '/settings/conversation-retention',
  ),
];

bool _independentWithConsent(UserModel user) =>
    user.autonomy == AutonomyStatus.independent && user.hasConversationConsent;

/// Filas visibles para [user]. La usan HomeScreen (botón visible si hay ≥ 1
/// fila) y SettingsScreen (qué renderizar) — la misma función en ambos sitios.
List<SettingsRow> visibleSettingsRows(UserModel user) =>
    settingsRows.where((row) => row.visible(user)).toList();
