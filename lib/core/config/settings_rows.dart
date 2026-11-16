import 'package:quiet_companion/core/config/preference_scales.dart';
import 'package:quiet_companion/core/config/tts_voices.dart';
import 'package:quiet_companion/core/models/companion_sharing.dart';
import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/models/user_model.dart';

/// Entrada de ajustes: una fila o un grupo de filas.
sealed class SettingsEntry {
  const SettingsEntry();

  String get title;

  /// Texto bajo el título.
  String subtitleFor(UserModel user);

  bool isVisibleFor(UserModel user);

  /// Subpantalla a la que navega la entrada.
  String get route;
}

/// Fila de ajustes del mayor con su propio predicado de visibilidad.
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

  /// La pantalla se muestra si al menos una fila es visible.
  final bool Function(UserModel user) visible;

  /// Subpantalla donde se edita el ajuste.
  @override
  final String route;

  @override
  String subtitleFor(UserModel user) => value(user);

  @override
  bool isVisibleFor(UserModel user) => visible(user);
}

/// Varias filas detrás de una entrada del menú, para que quepa sin desplazarse.
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

  /// Resumen de lo que hay dentro, solo con las filas visibles.
  final String Function(UserModel user) description;

  final List<SettingsRow> rows;

  @override
  String get route => '/settings/group/$slug';

  @override
  String subtitleFor(UserModel user) => description(user);

  /// Visible si lo es alguna de sus filas.
  @override
  bool isVisibleFor(UserModel user) => rows.any((row) => row.visible(user));

  List<SettingsRow> visibleRows(UserModel user) =>
      rows.where((row) => row.visible(user)).toList();
}

// Escalas de accesibilidad, visibles para todo mayor. Si el familiar toca el
// mismo valor, gana la última escritura.
SettingsRow _scaleRow(PreferenceScale scale) => SettingsRow(
      title: scale.title,
      value: (user) => scale.labelFor(user.preferences),
      visible: (user) => true,
      route: scale.route,
    );

/// Menú de Ajustes. Vive en core/ porque lo usan conversation y settings.
final List<SettingsEntry> settingsMenu = [
  // Primero, porque el contacto de emergencia es lo que urge.
  SettingsGroup(
    slug: 'personal',
    title: 'Mis datos',
    // Si falta el contacto, se ve desde el menú sin entrar en el grupo.
    description: (user) => !_emergencyContactRow.visible(user)
        ? 'Cómo entras en la aplicación'
        : user.emergencyContact == null
            ? 'Falta tu contacto de emergencia'
            : 'Tu contacto de emergencia y tu cuenta',
    rows: [
      _emergencyContactRow,
      // Guardar con Google la cuenta anónima o cerrar sesión; lo resuelve su pantalla.
      SettingsRow(
        title: 'Mi cuenta',
        value: (user) => 'Cómo entras en la aplicación',
        visible: (user) => true,
        route: '/settings/account',
      ),
    ],
  ),
  _scaleRow(textSizeScale),
  SettingsGroup(
    slug: 'talk',
    title: 'Cómo hablamos',
    description: (user) =>
        'La voz, el volumen, la velocidad y cuánto te espero',
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
    description: (user) => 'Qué se guarda de lo que hablamos',
    rows: [
      // Visible para todo mayor: retirar el consentimiento es tan fácil como darlo.
      SettingsRow(
        title: 'Guardar mis conversaciones',
        value: (user) => user.hasConversationConsent ? 'Sí' : 'No',
        visible: (user) => true,
        route: '/settings/conversations',
      ),
      // Solo si hay familiar; lo decide el mayor.
      SettingsRow(
        title: 'Qué ve mi familiar',
        value: (user) =>
            (user.companionSharing ?? CompanionSharing.none).label,
        visible: (user) =>
            user.linkedCompanionId != null && user.hasConversationConsent,
        route: '/settings/companion-sharing',
      ),
      // Solo en modo independiente; en vinculado los fija el familiar.
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

/// Fuera de la lista porque la descripción de «Mis datos» pregunta por ella.
final SettingsRow _emergencyContactRow = SettingsRow(
  title: 'Contacto de emergencia',
  value: (user) => user.emergencyContact?.name ?? 'Sin configurar',
  // Oculta cuando el contacto viene impuesto por la vinculación.
  visible: (user) =>
      user.emergencyContact?.source != EmergencyContactSource.companion,
  route: '/settings/emergency-contact',
);

bool _independentWithConsent(UserModel user) =>
    user.autonomy == AutonomyStatus.independent && user.hasConversationConsent;

/// Entradas del menú de Ajustes visibles para [user].
List<SettingsEntry> visibleSettingsEntries(UserModel user) =>
    settingsMenu.where((entry) => entry.isVisibleFor(user)).toList();

/// Filas visibles para [user], también las de dentro de grupos.
List<SettingsRow> visibleSettingsRows(UserModel user) => [
      for (final entry in settingsMenu)
        ...switch (entry) {
          SettingsRow row => [row],
          SettingsGroup group => group.rows,
        },
    ].where((row) => row.visible(user)).toList();

/// Grupo del segmento `:id` de la ruta; null si el slug no existe.
SettingsGroup? settingsGroupBySlug(String? slug) {
  for (final entry in settingsMenu) {
    if (entry is SettingsGroup && entry.slug == slug) return entry;
  }
  return null;
}
