import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/core/widgets/elder_screen_title.dart';

/// Alta / edición del contacto de emergencia por el mayor cuyo contacto no
/// viene impuesto por la vinculación. Única entrada: la fila "Contacto de
/// emergencia" de la pantalla de ajustes. Vive en features/emergency/ porque
/// su lógica (E.164, rechazo del 112, semántica de source) es de emergencia;
/// settings solo enruta hacia aquí.
///
/// Dos fases en la misma pantalla (sin diálogos): edición → confirmación con
/// el número en grande. Un dígito mal en un contacto de emergencia es un
/// fallo silencioso hasta el peor momento posible.
class EmergencyContactSetupScreen extends ConsumerStatefulWidget {
  const EmergencyContactSetupScreen({super.key});

  @override
  ConsumerState<EmergencyContactSetupScreen> createState() =>
      _EmergencyContactSetupScreenState();
}

class _EmergencyContactSetupScreenState
    extends ConsumerState<EmergencyContactSetupScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();

  // Estado de vista puro: fase de confirmación y error de guardado.
  bool _confirming = false;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    // Precarga el contacto vigente: quien entra a cambiarlo tiene que ver qué
    // hay guardado, no un formulario vacío que parece decir que no hay nada.
    final current = ref.read(currentUserProvider).valueOrNull?.emergencyContact;
    if (current != null) {
      // El campo solo admite los 9 dígitos nacionales; el +34 es un prefijo fijo.
      final digits = current.phone.replaceAll(RegExp(r'\D'), '');
      _phoneController.text =
          digits.startsWith('34') && digits.length == 11 ? digits.substring(2) : digits;
      if (current.name != EmergencyContact.defaultName) {
        _nameController.text = current.name;
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String get _rawPhone => _phoneController.text.trim();

  String? get _normalizedPhone =>
      EmergencyContact.normalizeSpanishPhone(_rawPhone);

  /// Mensaje de validación en vivo. null = sin error (vacío o válido).
  String? get _phoneError {
    if (_rawPhone.isEmpty) return null;
    final digits = _rawPhone.replaceAll(RegExp(r'\D'), '');
    if (EmergencyContact.emergencyNumbers.contains(digits)) {
      return 'Los números de emergencia como el 112 no se pueden guardar '
          'aquí: ya tienen su propio botón en la pantalla de emergencia.';
    }
    if (_normalizedPhone == null) {
      return 'Escribe los 9 números del teléfono. '
          'Debe empezar por 6, 7, 8 o 9.';
    }
    return null;
  }

  /// Número en grande para la confirmación: +34 600 123 456.
  String get _formattedPhone {
    final digits = _rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 9) return '+34 $digits';
    return '+34 ${digits.substring(0, 3)} ${digits.substring(3, 6)} '
        '${digits.substring(6)}';
  }

  String get _contactName {
    final name = _nameController.text.trim();
    return name.isEmpty ? EmergencyContact.defaultName : name;
  }

  Future<void> _save() async {
    final phone = _normalizedPhone;
    final uid = ref.read(currentUserProvider).valueOrNull?.id;
    if (phone == null || uid == null) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      // Nunca se escribe a Firestore desde la pantalla: siempre vía repositorio.
      await ref.read(authRepositoryProvider).updateEmergencyContact(
            uid,
            EmergencyContact(
              name: _contactName,
              phone: phone,
              source: EmergencyContactSource.manual,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'No se ha podido guardar. Inténtalo otra vez.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final textScale = user?.preferences.textSizeMultiplier ?? 1.0;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: AppTheme.contentMaxWidth(context)),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.screenPadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElderScreenTitle('Contacto de emergencia',
                      textScale: textScale),
                  const SizedBox(height: 24),
                  _confirming
                      ? _buildConfirmStep(textScale)
                      : _buildEditStep(textScale),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditStep(double textScale) {
    final canContinue = _normalizedPhone != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿A quién llamamos si necesitas ayuda?',
          style: TextStyle(
            fontSize: AppTheme.fontMedium * textScale,
            color: AppTheme.elderTextPrimary,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Su teléfono',
          style: TextStyle(
            fontSize: AppTheme.fontButton * textScale,
            fontWeight: FontWeight.bold,
            color: AppTheme.elderTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          // El mayor teclea solo los 9 dígitos nacionales; el prefijo +34 es
          // fijo y no se teclea: menos superficie de error.
          keyboardType: TextInputType.phone,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(9),
          ],
          style: TextStyle(
            fontSize: AppTheme.fontLarge * textScale,
            color: AppTheme.elderTextPrimary,
          ),
          decoration: InputDecoration(
            prefixText: '+34 ',
            prefixStyle: TextStyle(
              fontSize: AppTheme.fontLarge * textScale,
              color: AppTheme.elderTextSecondary,
            ),
            border: const OutlineInputBorder(),
            hintText: '600123456',
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (_phoneError != null) ...[
          const SizedBox(height: 12),
          Text(
            _phoneError!,
            style: TextStyle(
              fontSize: AppTheme.fontButton * textScale,
              color: AppTheme.emergency112,
            ),
          ),
        ],
        const SizedBox(height: 32),
        Text(
          'Su nombre (si quieres)',
          style: TextStyle(
            fontSize: AppTheme.fontButton * textScale,
            fontWeight: FontWeight.bold,
            color: AppTheme.elderTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(
            fontSize: AppTheme.fontLarge * textScale,
            color: AppTheme.elderTextPrimary,
          ),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'María',
          ),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed:
              canContinue ? () => setState(() => _confirming = true) : null,
          child: Text(
            'Continuar',
            style: TextStyle(fontSize: AppTheme.fontButton * textScale),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep(double textScale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿Es correcto este teléfono?',
          style: TextStyle(
            fontSize: AppTheme.fontMedium * textScale,
            color: AppTheme.elderTextPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Text(
          _contactName,
          style: TextStyle(
            fontSize: AppTheme.fontMedium * textScale,
            fontWeight: FontWeight.bold,
            color: AppTheme.elderTextPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          _formattedPhone,
          style: TextStyle(
            fontSize: AppTheme.fontHuge * textScale,
            fontWeight: FontWeight.bold,
            color: AppTheme.elderPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        if (_saveError != null) ...[
          const SizedBox(height: 24),
          Text(
            _saveError!,
            style: TextStyle(
              fontSize: AppTheme.fontButton * textScale,
              color: AppTheme.emergency112,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(
            'Sí, guardar',
            style: TextStyle(fontSize: AppTheme.fontButton * textScale),
          ),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed:
              _saving ? null : () => setState(() => _confirming = false),
          child: Text(
            'Volver a escribirlo',
            style: TextStyle(
              fontSize: AppTheme.fontButton * textScale,
              color: AppTheme.elderTextSecondary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
