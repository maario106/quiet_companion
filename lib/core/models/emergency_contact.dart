/// Origen del contacto de emergencia del mayor. Discrimina "lo puso la
/// vinculación" ([companion]) de "lo puso el mayor a mano" ([manual]).
/// Gobierna dos cosas: la precedencia en la escritura (una vinculación nunca
/// sobrescribe un contacto manual) y la visibilidad de la fila de ajustes
/// (solo es editable el contacto que no viene impuesto por la vinculación).
enum EmergencyContactSource { companion, manual }

/// Contacto de emergencia del mayor, desnormalizado en `users/{elderId}`.
/// Inmutable. El teléfono se guarda siempre en E.164 (`+34600123456`):
/// normalizado en escritura, nunca en lectura.
class EmergencyContact {
  final String name;
  final String phone;
  final EmergencyContactSource source;

  const EmergencyContact({
    this.name = defaultName,
    required this.phone,
    this.source = EmergencyContactSource.manual,
  });

  /// Etiqueta por defecto cuando el mayor no introdujo nombre. El nombre
  /// nunca está vacío: se muestra en el botón "Llamar a {name}".
  static const String defaultName = 'Mi contacto';

  /// Números de emergencia españoles que no se aceptan como contacto
  /// personal: ya existe un botón dedicado para llamar a emergencias y
  /// guardarlos aquí duplicaría la acción con etiqueta engañosa.
  static const Set<String> emergencyNumbers = {
    '112', '061', '062', '080', '085', '091', '092', '016',
  };

  /// Lectura defensiva desde Firestore: devuelve null si el mapa no existe o
  /// no contiene un teléfono utilizable. Un contacto a medias es peor que
  /// ninguno. Origen desconocido o ausente → manual (fallback conservador:
  /// no se asume que venga de una vinculación).
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

  /// Normaliza un teléfono español tecleado como 9 dígitos nacionales a
  /// E.164 (`+34600123456`). Devuelve null si no es un número personal
  /// válido: longitud distinta de 9, no empieza por 6-9, o es un número de
  /// emergencia ([emergencyNumbers]). Función pura: es la única fuente de
  /// validación tanto del registro del familiar como del alta manual.
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
