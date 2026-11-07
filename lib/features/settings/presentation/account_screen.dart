import 'package:firebase_auth/firebase_auth.dart' show AuthCredential;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';
import 'package:quiet_companion/core/providers/current_user_provider.dart';
import 'package:quiet_companion/core/repositories/auth_repository.dart';
import 'package:quiet_companion/core/theme/app_theme.dart';
import 'package:quiet_companion/core/widgets/elder_button.dart';
import 'package:quiet_companion/core/widgets/elder_screen_title.dart';

/// "Mi cuenta": cómo entra el mayor en la aplicación.
///
/// Sin registrarse, la cuenta es la de esta instalación: aquí se guarda con
/// Google sin cambiar de uid, y no se ofrece cerrar sesión, porque cerrarla
/// sería perderlo todo. Con Google, se puede cerrar y volver a entrar.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _busy = false;
  String? _error;

  /// La cuenta de Google elegida ya tenía la suya: se pregunta antes de
  /// entrar con ella, porque lo de esta sesión se quedaría sin cuenta.
  AuthCredential? _accountInUse;

  /// Cerrar sesión pide un segundo toque, en la misma pantalla.
  bool _confirmingSignOut = false;

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) setState(() => _busy = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure;
      });
    }
  }

  Future<void> _saveWithGoogle() => _run(() async {
        final result = await ref.read(authRepositoryProvider).linkWithGoogle();
        // Vinculada: la sesión lo cuenta sola (`authAccountProvider`).
        if (result case GoogleAccountInUse(:final credential)) {
          if (mounted) setState(() => _accountInUse = credential);
        }
      }, 'No se ha podido guardar con Google. '
          'Comprueba la conexión e inténtalo otra vez.');

  /// Si la cuenta resulta ser la de un familiar, el repositorio cierra la
  /// sesión y el enrutador lleva a la bienvenida: el mayor ya sabía que lo de
  /// este móvil se perdía.
  Future<void> _enterWithAccountInUse(AuthCredential credential) => _run(
        () async {
          await ref
              .read(authRepositoryProvider)
              .signInWithGoogleCredential(credential);
          if (mounted) setState(() => _accountInUse = null);
        },
        'No se ha podido entrar con esa cuenta. Inténtalo otra vez.',
      );

  Future<void> _signOut() => _run(
        () => ref.read(authRepositoryProvider).signOut(),
        'No se ha podido cerrar la sesión. Inténtalo otra vez.',
      );

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final account = ref.watch(authAccountProvider).valueOrNull;

    if (user == null || account == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final textScale = user.preferences.textSizeMultiplier;
    final bodyStyle = TextStyle(
      fontSize: AppTheme.fontMedium * textScale,
      color: AppTheme.elderTextPrimary,
    );
    final inUse = _accountInUse;

    final List<Widget> content;
    if (account.isAnonymous && inUse != null) {
      content = [
        Text(
          'Esa cuenta de Google ya tiene sus propios datos en la aplicación. '
          'Si entras con ella, verás los suyos, y lo de este móvil se perderá.',
          style: bodyStyle,
        ),
        const SizedBox(height: 32),
        ElderButton(
          label: 'Entrar con esa cuenta',
          textScale: textScale,
          onPressed: _busy ? null : () => _enterWithAccountInUse(inUse),
        ),
        const SizedBox(height: 24),
        ElderButton(
          label: 'No, seguir así',
          textScale: textScale,
          secondary: true,
          onPressed: _busy ? null : () => setState(() => _accountInUse = null),
        ),
      ];
    } else if (account.isAnonymous) {
      content = [
        Text(
          'Has entrado sin registrarte. Si borras la aplicación o cambias de '
          'móvil, se pierde todo lo que guarda sobre ti.',
          style: bodyStyle,
        ),
        const SizedBox(height: 16),
        Text(
          'Con tu cuenta de Google lo conservas, y puedes volver a entrar '
          'desde otro móvil.',
          style: bodyStyle,
        ),
        const SizedBox(height: 32),
        ElderButton(
          label: 'Guardar con Google',
          textScale: textScale,
          onPressed: _busy ? null : _saveWithGoogle,
        ),
      ];
    } else if (_confirmingSignOut) {
      content = [
        Text(
          '¿Seguro? Para volver a entrar, elige otra vez tu cuenta de Google.',
          style: bodyStyle,
        ),
        const SizedBox(height: 32),
        ElderButton(
          label: 'Sí, cerrar sesión',
          textScale: textScale,
          onPressed: _busy ? null : _signOut,
        ),
        const SizedBox(height: 24),
        ElderButton(
          label: 'No',
          textScale: textScale,
          secondary: true,
          onPressed:
              _busy ? null : () => setState(() => _confirmingSignOut = false),
        ),
      ];
    } else {
      content = [
        Text(
          account.email == null
              ? 'Entras con tu cuenta de Google.'
              : 'Entras con tu cuenta de Google: ${account.email}',
          style: bodyStyle,
        ),
        const SizedBox(height: 32),
        ElderButton(
          label: 'Cerrar sesión',
          textScale: textScale,
          secondary: true,
          onPressed:
              _busy ? null : () => setState(() => _confirmingSignOut = true),
        ),
      ];
    }

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
                  ElderScreenTitle('Mi cuenta', textScale: textScale),
                  const SizedBox(height: 24),
                  ...content,
                  if (_error != null) ...[
                    const SizedBox(height: 24),
                    // Texto fijo, no SnackBar: un aviso que se va solo es un
                    // aviso que el mayor no llega a leer.
                    Text(
                      _error!,
                      style: TextStyle(
                        fontSize: AppTheme.fontButton * textScale,
                        color: AppTheme.emergency112,
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
    );
  }
}
