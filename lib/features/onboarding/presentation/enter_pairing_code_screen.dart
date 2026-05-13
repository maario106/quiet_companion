import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/core/widgets/sign_out_button.dart';
import 'package:quiet_companion/features/onboarding/domain/companion_auth_controller.dart';
import 'package:quiet_companion/features/onboarding/domain/companion_auth_state.dart';

class EnterPairingCodeScreen extends ConsumerStatefulWidget {
  const EnterPairingCodeScreen({super.key});

  @override
  ConsumerState<EnterPairingCodeScreen> createState() =>
      _EnterPairingCodeScreenState();
}

class _EnterPairingCodeScreenState
    extends ConsumerState<EnterPairingCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(companionAuthControllerProvider.notifier)
        .linkWithCode(_codeController.text.trim().toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CompanionAuthState>(companionAuthControllerProvider,
        (previous, next) {
      if (next.status == CompanionAuthStatus.linked) {
        context.go('/dashboard');
      }
    });

    final state = ref.watch(companionAuthControllerProvider);
    final isLoading = state.status == CompanionAuthStatus.loading;
    final padding = AppTheme.screenPadding(context);
    final maxWidth = AppTheme.contentMaxWidth(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: const [SignOutButton()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Introduce el código',
                      style: TextStyle(
                        fontSize: AppTheme.companionFontTitle,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.companionTextPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pídele a tu familiar el código de 4 letras que aparece en su aplicación.',
                      style: TextStyle(
                        fontSize: AppTheme.companionFontBody,
                        color: AppTheme.companionTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    // Code input keeps elder-sized text — it displays elder content
                    TextFormField(
                      controller: _codeController,
                      enabled: !isLoading,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 4,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]')),
                        UpperCaseTextFormatter(),
                      ],
                      style: const TextStyle(
                        fontSize: AppTheme.fontHuge,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 12,
                        color: AppTheme.companionTextPrimary,
                      ),
                      decoration: const InputDecoration(counterText: ''),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.length != 4) return 'El código tiene 4 caracteres';
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
                          : const Text('Vincular'),
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

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
