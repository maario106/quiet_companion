import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/models/emergency_contact.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/features/onboarding/domain/companion_auth_controller.dart';
import 'package:quiet_companion/features/onboarding/domain/companion_auth_state.dart';

class CompanionRegisterScreen extends ConsumerStatefulWidget {
  const CompanionRegisterScreen({super.key});

  @override
  ConsumerState<CompanionRegisterScreen> createState() =>
      _CompanionRegisterScreenState();
}

class _CompanionRegisterScreenState
    extends ConsumerState<CompanionRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(companionAuthControllerProvider.notifier).register(
          _emailController.text.trim(),
          _passwordController.text,
          name: _nameController.text.trim(),
          // El validador garantiza que la normalización no devuelve null.
          phoneNumber: EmergencyContact.normalizeSpanishPhone(
            _phoneController.text,
          )!,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CompanionAuthState>(companionAuthControllerProvider,
        (previous, next) {
      if (next.status == CompanionAuthStatus.authenticated) {
        context.go('/companion/pairing');
      }
    });

    final state = ref.watch(companionAuthControllerProvider);
    final isLoading = state.status == CompanionAuthStatus.loading;
    final padding = AppTheme.screenPadding(context);
    final maxWidth = AppTheme.contentMaxWidth(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/companion/choice'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Crear cuenta',
                      style: TextStyle(
                        fontSize: AppTheme.companionFontTitle,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.companionTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      enabled: !isLoading,
                      decoration:
                          const InputDecoration(labelText: 'Tu nombre'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Introduce tu nombre';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enabled: !isLoading,
                      decoration:
                          const InputDecoration(labelText: 'Correo electrónico'),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'Introduce un correo';
                        if (!v.contains('@')) return 'Correo no válido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      enabled: !isLoading,
                      decoration:
                          const InputDecoration(labelText: 'Contraseña'),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Mínimo 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Al vincular, este teléfono se convierte en el contacto
                    // de emergencia del mayor (desnormalizado en su doc).
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: !isLoading,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Tu teléfono',
                        prefixText: '+34 ',
                        helperText:
                            'El mayor podrá llamarte desde su botón de emergencia',
                      ),
                      validator: (value) {
                        final normalized =
                            EmergencyContact.normalizeSpanishPhone(value ?? '');
                        if (normalized == null) {
                          return 'Introduce un teléfono español de 9 dígitos';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Crear cuenta'),
                    ),
                    if (state.status == CompanionAuthStatus.error) ...[
                      const SizedBox(height: 20),
                      Text(
                        state.errorMessage,
                        style: const TextStyle(
                          fontSize: AppTheme.companionFontBody,
                          color: AppTheme.companionError,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
