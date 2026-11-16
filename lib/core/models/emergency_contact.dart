/// Origen del contacto de emergencia: la vinculación o el propio mayor.
/// Una vinculación nunca sobrescribe un contacto manual.
enum EmergencyContactSource { companion, manual }

/// Contacto de emergencia del mayor; el teléfono siempre en E.164.
class EmergencyContact {
  final String name;
  final String phone;
  final EmergencyContactSource source;

  const EmergencyContact({
    this.name = defaultName,
    required this.phone,
    this.source = EmergencyContactSource.manual,
  });

  /// Nombre por defecto si el mayor no puso ninguno.
  static const String defaultName = 'Mi contacto';

  /// Números de emergencia, que no se aceptan como contacto personal.
  static const Set<String> emergencyNumbers = {
    '112', '061', '062', '080', '085', '091', '092', '016',
  };

  /// null si no hay un teléfono utilizable; sin origen, se asume manual.
  static EmergencyContact? fromMapOrNull(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final phone = map['phone'] as String?;
    if (phone == null || phone.isEmpty) return null;
    final name = map['name'] as String?;
    final source = EmergencyContactSource.values
            .asNameMap()[map['source'] as String?] ??
        EmergencyContactSource.manual;
    return EmergencyContact(
      name: (name == null || name.isEmpty) ? defaultName : name,
      phone: phone,
      source: source,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'source': source.name,
    };
  }

  /// Teléfono español de 9 dígitos a E.164, o null si no es un número
  /// personal válido.
  static String? normalizeSpanishPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (emergencyNumbers.contains(digits)) return null;
    final e164 = '+34$digits';
    if (!RegExp(r'^\+34[6-9]\d{8}$').hasMatch(e164)) return null;
    return e164;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmergencyContact &&
          other.name == name &&
          other.phone == phone &&
          other.source == source;

  @override
  int get hashCode => Object.hash(name, phone, source);
}
