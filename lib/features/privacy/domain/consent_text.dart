import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/models/user_model.dart';

/// Versión del texto que lee el mayor. Se guarda con su respuesta
/// (`textVersion`): si el texto cambia de forma que afecte a lo que se
/// consiente, se sube este número.
const int kConsentTextVersion = 1;

class ConsentSection {
  const ConsentSection(this.title, this.body);

  final String title;
  final String body;
}

/// Lo que se le dice al mayor antes de que decida (ADR-0030).
///
/// Un solo consentimiento para dos cosas, explicadas **por separado**: el
/// análisis (resumen y cómo se ha sentido) y la memoria (lo que el asistente
/// recuerda de él). Lo que ve el familiar se dice aquí y se ajusta después en
/// Ajustes (ADR-0031).
class ConsentText {
  const ConsentText({
    required this.isLinked,
    required this.companionName,
    required this.retentionPhrase,
    required this.gracePeriodDays,
  });

  factory ConsentText.forUser(UserModel user) {
    final contact = user.emergencyContact;
    final settings = user.effectiveConversationSettings;
    return ConsentText(
      isLinked: user.linkedCompanionId != null,
      // El documento del mayor no guarda el nombre de su familiar, pero la
      // vinculación sí se lo copia como contacto de emergencia.
      companionName: contact?.source == EmergencyContactSource.companion
          ? contact!.name
          : null,
      retentionPhrase: settings.retentionPhrase,
      gracePeriodDays: settings.gracePeriodDays,
    );
  }

  final bool isLinked;
  final String? companionName;
  final String retentionPhrase;
  final int gracePeriodDays;

  static const String question =
      '¿Quieres que guarde un resumen de nuestras conversaciones?';

  String get _companion =>
      companionName == null ? 'Tu familiar' : 'Tu familiar, $companionName,';

  ConsentSection get _analysis => const ConsentSection(
        'Qué guardo',
        'Al terminar cada conversación guardo un resumen breve y cómo te has '
            'sentido. Nunca guardo lo que dices palabra por palabra.',
      );

  ConsentSection get _memory => const ConsentSection(
        'Qué recuerdo',
        'Apunto cosas que me cuentes, como el nombre de tu familia o lo que te '
            'gusta, para no tener que preguntártelas otra vez. No apunto nada '
            'sobre tu salud.',
      );

  ConsentSection get _whoSees => isLinked
      ? ConsentSection(
          'Quién lo ve',
          '$_companion podrá ver cómo te encuentras y un resumen de lo que '
              'hablamos. Puedes cambiar lo que ve cuando quieras, en Ajustes.',
        )
      : const ConsentSection(
          'Quién lo ve',
          'Solo tú. Podrás verlo en «Mi semana».',
        );

  /// Versión corta, para la pantalla de la pregunta.
  List<ConsentSection> get summary => [
        _analysis,
        _memory,
        _whoSees,
        const ConsentSection(
          'Si cambias de idea',
          'Puedes quitarlo cuando quieras, en Ajustes.',
        ),
      ];

  /// Versión completa, para "Saber más" y para Ajustes.
  List<ConsentSection> get details => [
        _analysis,
        _memory,
        const ConsentSection(
          'Cómo lo hago',
          'Para hacer el resumen, lo que hablamos se envía a los servidores de '
              'Google, que lo analizan y no lo guardan. Mientras hablamos también '
              'se envía, como ahora, para poder contestarte.',
        ),
        _whoSees,
        if (isLinked)
          const ConsentSection(
            'En «Mi semana»',
            'Tú también puedes ver cómo te has sentido estos días, y lo mismo '
                'que ve tu familiar.',
          ),
        ConsentSection(
          'Cuánto tiempo',
          'Cada resumen se guarda $retentionPhrase y después se borra solo. '
              '${isLinked ? 'Ese plazo lo elige tu familiar, entre uno y seis '
                  'meses.' : 'Puedes cambiar ese plazo en Ajustes.'}',
        ),
        ConsentSection(
          'Si cambias de idea',
          'Puedes dejar de guardarlo cuando quieras, en Ajustes. Desde ese '
              'momento no guardo nada nuevo${isLinked ? ' y tu familiar deja de '
                  'verlo' : ''}. Lo que ya estaba guardado se borra al cabo de '
              '$gracePeriodDays días; si vuelves a activarlo antes, lo recuperas.',
        ),
        const ConsentSection(
          'Importante',
          'Esto no es una alarma. Si necesitas ayuda, usa el botón de '
              'emergencia.',
        ),
      ];

  /// Texto para leer en voz alta con el botón "Escuchar".
  static String spoken(List<ConsentSection> sections, {bool withQuestion = true}) {
    final body = sections.map((s) => '${s.title}. ${s.body}').join(' ');
    return withQuestion ? '$question $body' : body;
  }
}
