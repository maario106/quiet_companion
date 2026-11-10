import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'elder_auth_state.dart';
import 'package:quiet_companion/core/repositories/auth_repository.dart';
import 'package:quiet_companion/core/models/user_model.dart';
import 'package:quiet_companion/core/providers/auth_repository_provider.dart';

class ElderAuthController extends StateNotifier<AuthState> {
  ElderAuthController(this._authRepository)
      : super(const AuthState(status: AuthStatus.checking)){
    _init();
  }

  final AuthRepository _authRepository;
  StreamSubscription<String?>? _authSubscription;

  void _init() {
    _authSubscription = _authRepository.authStateUid().listen((uid) async {
      if (uid == null) {
        // Un error sin sesión ya está en la bienvenida, y la sesión que se
        // acaba de cerrar es la que lo causó: no se borra el aviso.
        if (state.status == AuthStatus.error && state.user == null) return;
        // Sin sesión, el mayor elige en la bienvenida: con su cuenta de Google
        // o sin registrarse. No se entra en anónimo sin preguntárselo.
        state = const AuthState(status: AuthStatus.nonAuthenticated);
        return;
      }

      // One-time fetch — real-time user data flows through currentUserProvider.
      final existingUser = await _authRepository.getUser(uid);
      // La sesión pudo cambiar mientras llegaba el documento: este ya no vale.
      if (_authRepository.currentUid() != uid) return;
      final user = existingUser ?? UserModel(id: uid, role: UserRole.elder);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    });
  }

  /// "Entrar con Google". Si la cuenta ya existía (otro móvil), el
  /// documento del mayor vuelve tal cual y el enrutador le lleva a su
  /// pantalla. Cerrar el selector sin elegir no es un error.
  Future<void> signInWithGoogle() async {
    state = const AuthState(status: AuthStatus.checking);
    try {
      if (!await _authRepository.signInWithGoogle()) {
        state = const AuthState(status: AuthStatus.nonAuthenticated);
        return;
      }
    } on CompanionAccountException {
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Esa cuenta de Google es la de un familiar. '
            'Elige otra, o entra como acompañante.',
      );
    } catch (error) {
      if (kDebugMode) debugPrint('[AUTH] Google: $error');
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'No se ha podido entrar con Google. '
            'Comprueba la conexión e inténtalo otra vez.',
      );
    }
  }

  /// "Entrar sin registrarme": sesión anónima. La aplicación funciona igual,
  /// pero la cuenta es la de esta instalación; se puede guardar con Google
  /// después, desde "Mi cuenta".
  Future<void> continueWithoutAccount() async {
    state = const AuthState(status: AuthStatus.checking);
    try {
      await _authRepository.signInAnonymously();
    } catch (_) {
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'No se ha podido entrar. '
            'Comprueba la conexión e inténtalo otra vez.',
      );
    }
  }

  /// La flecha atrás de "¿Cómo prefieres usar la aplicación?": el mayor se
  /// equivocó al elegir cómo entrar. Al cerrarse la sesión, [_init] lleva a
  /// la bienvenida; mientras, la rueda de espera impide elegir modo en una
  /// cuenta que se está borrando.
  Future<void> backToAccessChoice() async {
    final previous = state;
    state = const AuthState(status: AuthStatus.checking);
    try {
      await _authRepository.leaveBeforeChoosingMode();
    } catch (_) {
      // La sesión sigue abierta: el mayor vuelve a tener la flecha.
      state = previous;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> selectIndependentMode() async {
    if (state.user == null) return;
    final updatedUser = state.user!.copyWith(
      autonomy: AutonomyStatus.independent,
      linkCode: null,
    );
    state = state.copyWith(user: updatedUser);
    try {
      await _authRepository.saveUser(updatedUser);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> selectLinkedMode() async {
    if (state.user == null) return;
    final code = _genCode();
    final updatedUser = state.user!.copyWith(
      autonomy: AutonomyStatus.dependent,
      linkCode: code,
    );
    state = state.copyWith(user: updatedUser);
    try {
      await _authRepository.saveUser(updatedUser);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> cancelLinkedMode() async {
    if (state.user == null) return;
    final updatedUser = state.user!.copyWith(
      autonomy: AutonomyStatus.none,
      linkCode: null,
    );
    state = state.copyWith(user: updatedUser);
    try {
      await _authRepository.saveUser(updatedUser);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excluye O, 0, I, 1 por accesibilidad visual
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }
}

final elderAuthControllerProvider =
StateNotifierProvider<ElderAuthController, AuthState>((ref) {
  return ElderAuthController(ref.read(authRepositoryProvider));
});
