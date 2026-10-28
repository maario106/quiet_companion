import 'package:quiet_companion/core/config/preference_scales.dart';
import 'package:quiet_companion/core/config/tts_voices.dart';
import 'package:quiet_companion/core/models/companion_sharing.dart';
import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/models/user_model.dart';

/// Una entrada de una pantalla de ajustes: una fila que abre su ajuste, o un
/// grupo que abre otra lista de filas. La pantalla pinta las dos igual.
sealed class SettingsEntry {
  const SettingsEntry();

  String get title;

  /// Texto bajo el título.
  String subtitleFor(UserModel user);

  bool isVisibleFor(UserModel user);

  /// Subpantalla a la que navega la entrada.
  String get route;
}

/// Fila de ajustes del mayor, modelada de forma declarativa: cada fila lleva
/// su propio predicado de visibilidad sobre el [UserModel].
class SettingsRow extends SettingsEntry {
  const SettingsRow({
    required this.title,
    required this.value,
    required this.visible,
    required this.route,
  });

  @override
  final String title;

  /// Valor actual mostrado bajo el título (p. ej. el nombre del contacto).
  final String Function(UserModel user) value;

  /// Predicado de visibilidad por fila, NO por pantalla: la pantalla se
  /// muestra si al menos una fila es visible.
  final bool Function(UserModel user) visible;

  /// Subpantalla a la que navega la fila. Todo ajuste se edita en su propia
  /// subpantalla; nada de edición inline.
  @override
  final String route;

  @override
  String subtitleFor(UserModel user) => value(user);

  @override
  bool isVisibleFor(UserModel user) => visible(user);
}

/// Varias filas detrás de una sola entrada del menú de Ajustes. Existe para
/// que el menú quepa en una pantalla sin desplazarse: con la voz eran hasta
/// diez filas seguidas. Se agrupa por lo que el mayor quiere cambiar ("cómo
/// hablamos", "lo que se guarda"), no por dónde se guarda cada valor.
class SettingsGroup extends SettingsEntry {
  const SettingsGroup({
    required this.slug,
    required this.title,
    required this.description,
    required this.rows,
  });

  /// Identifica el grupo en la ruta, como `PreferenceScale.slug`.
  final String slug;

  @override
  final String title;

  /// Qué hay dentro. Va bajo el título porque un grupo no tiene un valor
  /// propio que enseñar.
  final String description;

  final List<SettingsRow> rows;

  @override
  String get route => '/settings/group/$slug';

  @override
  String subtitleFor(UserModel user) => description;

  /// Visible si lo es alguna de sus filas: un grupo sin filas llevaría a una
  /// pantalla vacía.
  @override
  bool isVisibleFor(UserModel user) => rows.any((row) => row.visible(user));

  List<SettingsRow> visibleRows(UserModel user) =>
      rows.where((row) => row.visible(user)).toList();
}

// Accesibilidad local del mayor (ADR-0013, CU-05/RF-5): las tres magnitudes
// que el familiar mueve con deslizadores, aquí como escalas de peldaños con
// nombre, más la pausa de escucha (ADR-0036).
//
// Visibles para TODO mayor, vinculado o independiente. La alternativa
// (limitarlas al independiente, que es la letra de CU-05) dejaba sin ninguna
// fila —y por tanto sin botón de ajustes en HomeScreen— al mayor
// vinculado cuyo contacto de emergencia fija el familiar. Que dos personas
// puedan tocar el mismo valor no necesita arbitraje: a diferencia del
// contacto de emergencia, aquí no hay autoridad que proteger, y gana la última
// escritura.
SettingsRow _scaleRow(PreferenceScale scale) => SettingsRow(
      title: scale.title,
      value: (user) => scale.labelFor(user.preferences),
      visible: (user) => true,
      route: scale.route,
    );

/// Menú de Ajustes, en orden: lo que urge en una emergencia, lo que se ve,
/// lo que se oye y lo que se guarda. Única fuente de verdad de las filas.
/// Vive en core/ porque la consumen dos features que no pueden acoplarse
/// entre sí: conversation (visibilidad del botón de ajustes de HomeScreen) y
/// settings (render de las listas). Si botón y pantalla calcularan su
/// visibilidad por separado, acabarían divergiendo.
final List<SettingsEntry> settingsMenu = [
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
  _scaleRow(textSizeScale),
  SettingsGroup(
    slug: 'talk',
    title: 'Cómo hablamos',
    description: 'La voz, el volumen, la velocidad y cuánto te espero',
    rows: [
      SettingsRow(
        title: 'Voz',
        value: (user) => ttsVoiceFor(user.preferences).label,
        visible: (user) => true,
        route: '/settings/voice',
      ),
      _scaleRow(volumeScale),
      _scaleRow(speechRateScale),
      _scaleRow(listenPauseScale),
    ],
  ),
  SettingsGroup(
    slug: 'conversations',
    title: 'Mis conversaciones',
    description: 'Qué se guarda de lo que hablamos',
    rows: [
      // El consentimiento sobre las conversaciones (ADR-0030). Visible para
      // todo mayor, vinculado o no: es suyo, y retirarlo tiene que ser tan
      // fácil como darlo. También sirve a quien dijo "Ahora no" y cambia de
      // idea.
      SettingsRow(
        title: 'Guardar mis conversaciones',
        value: (user) => user.hasConversationConsent ? 'Sí' : 'No',
        visible: (user) => true,
        route: '/settings/conversations',
      ),
      // Lo decide solo el mayor, y solo tiene sentido si hay familiar y algo
      // que ver (ADR-0031).
      SettingsRow(
        title: 'Qué ve mi familiar',
        value: (user) =>
            (user.companionSharing ?? CompanionSharing.none).label,
        visible: (user) =>
            user.linkedCompanionId != null && user.hasConversationConsent,
        route: '/settings/companion-sharing',
      ),
      // Los plazos los fija el propio mayor solo en modo independiente; en
      // modo vinculado los gestiona su familiar desde el panel (ADR-0034,
      // ADR-0007).
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
    ],
  ),
];

bool _independentWithConsent(UserModel user) =>
    user.autonomy == AutonomyStatus.independent && user.hasConversationConsent;

/// Entradas del menú de Ajustes visibles para [user].
List<SettingsEntry> visibleSettingsEntries(UserModel user) =>
    settingsMenu.where((entry) => entry.isVisibleFor(user)).toList();

/// Todas las filas visibles para [user], estén en el menú o dentro de un
/// grupo. HomeScreen enseña el botón de ajustes si hay al menos una.
List<SettingsRow> visibleSettingsRows(UserModel user) => [
      for (final entry in settingsMenu)
        ...switch (entry) {
          SettingsRow row => [row],
          SettingsGroup group => group.rows,
        },
    ].where((row) => row.visible(user)).toList();

/// Resuelve el segmento `:id` de la ruta de un grupo. `null` en un slug
/// desconocido, como [preferenceScaleBySlug]: la ruta es tecleable desde un
/// enlace profundo.
SettingsGroup? settingsGroupBySlug(String? slug) {
  for (final entry in settingsMenu) {
    if (entry is SettingsGroup && entry.slug == slug) return entry;
  }
  return null;
}
