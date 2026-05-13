# HU-4 Adaptive Configuration — Session Notes
_Fecha: 2026-04-28. Milestones 1 y 2 completados._

---

## 1. ¿Qué hace HU-4?

El familiar abre su teléfono, entra al panel de control y mueve unos deslizadores para ajustar el volumen de la voz, la velocidad del habla y el tamaño del texto del mayor. En cuanto suelta el deslizador, esos cambios se guardan en la nube y el móvil del mayor los recibe automáticamente en menos de un segundo: la letra crece o se reduce en pantalla, y la siguiente vez que la app le habla lo hace con el volumen y la velocidad nuevos. No hace falta que el mayor toque nada ni que reinicie la aplicación.

---

## 2. Arquitectura del flujo

```
[Companion — DashboardScreen]
        |
        | usuario suelta el deslizador (onChangeEnd)
        v
[DashboardController.updateElderPreferences()]
  lib/features/dashboard/domain/dashboard_controller.dart
        |
        | optimistic update local → _repository.saveUser(updatedElder)
        v
[Firestore: users/{elderId}.preferences]
        |
        | snapshot en tiempo real (Firestore SDK)
        v
[currentUserProvider  —  StreamProvider<UserModel?>]
  lib/core/providers/current_user_provider.dart
        |
        +-----------------------------------------------+
        |                                               |
        v                                               v
[ttsServiceProvider — Provider<TtsService>]   [HomeScreen — ConsumerStatefulWidget]
  lib/core/services/tts_service.dart           lib/features/conversation/presentation/home_screen.dart
        |                                               |
        | ref.listen → applyPreferences()              | ref.watch → textScale
        v                                               v
[flutter_tts: próxima locución]              [fontSize = AppTheme.fontHuge * textScale]
```

**Nota sobre rollback:** si `saveUser` lanza error, `DashboardController` revierte
`state.linkedElder` al snapshot previo. `_SettingSlider` detecta el cambio externo
en `didUpdateWidget` (solo cuando `!_isDragging`) y actualiza el slider visual.

---

## 3. Archivos modificados / creados

| Archivo | Cambio | Por qué |
|---------|--------|---------|
| `lib/features/dashboard/presentation/dashboard_screen.dart` | `_SettingSlider` convertido a `StatefulWidget`; callbacks migrados de `onChanged` a `onChangeEnd`; `didUpdateWidget` para reconciliar rollback | Milestone 1.1 — evitar una escritura a Firestore por cada pixel del deslizador |
| `lib/features/dashboard/domain/dashboard_controller.dart` | Se guarda `previousElder` antes del update optimista; el catch revierte `linkedElder` además de mostrar el error | Milestone 1.2 — rollback honesto: la UI no debe mostrar un valor que no llegó a persistir |
| `lib/core/providers/current_user_provider.dart` | NUEVO. `firebaseAuthUserProvider` (auth stream) + `currentUserProvider` (Firestore stream mapeado a `UserModel?`) | Milestone 2.1 — Single Source of Truth que cualquier widget puede escuchar sin abrir su propio stream |
| `lib/core/services/tts_service.dart` | Nuevo `ttsServiceProvider`; `ref.listen(currentUserProvider)` aplica preferencias en caliente; `ref.onDispose` llama a `stop()` | Milestone 2.2 — TTS reacciona a cambios de Firestore sin que `ChatController` sepa nada de preferencias |
| `lib/features/conversation/domain/chat_controller.dart` | `TtsService()` directo reemplazado por `ref.watch(ttsServiceProvider)` | Milestone 2.2 — ChatController recibe el servicio por DI en lugar de instanciarlo él mismo |
| `lib/features/conversation/presentation/home_screen.dart` | Se añade `ref.watch(currentUserProvider)` para leer `textSizeMultiplier`; `AppTheme.fontHuge/Large/fontButton` multiplicados por `textScale` | Milestone 2.3 — la letra del mayor cambia en tiempo real cuando el familiar mueve el deslizador |

---

## 4. Conceptos clave para alguien nuevo

**Riverpod `StreamProvider`**
Un `StreamProvider` envuelve un `Stream` de Dart (p. ej. un snapshot de Firestore) y lo expone a cualquier widget mediante `ref.watch`. Cuando el stream emite un dato nuevo, Riverpod reconstruye solo los widgets que lo observan. La alternativa — que cada controlador abra su propio stream — viola el Principio de Responsabilidad Única y duplica escuchas a Firestore.

**`currentUserProvider` como Single Source of Truth**
Es el único lugar donde se lee el documento `users/{uid}` de Firestore en tiempo real. Tanto `TtsService` (que necesita volumen y velocidad) como `HomeScreen` (que necesita `textSizeMultiplier`) escuchan este mismo provider. Si mañana se añade una tercera pantalla que necesite las preferencias, simplemente hace `ref.watch(currentUserProvider)` sin abrir otra conexión.

**`onChangeEnd` vs `onChanged` en un `Slider`**
`onChanged` se dispara decenas de veces por segundo mientras el usuario arrastra; usar ese callback para escribir en Firestore saturaría la red y agotaría el límite de escrituras gratuitas. `onChangeEnd` se dispara una única vez al soltar el dedo, que es cuando de verdad queremos persistir el valor. Se mantiene `onChanged` solo para actualizar la variable local `_localValue` (visual inmediato).

**Optimistic update con rollback**
"Optimista" significa que la UI muestra el nuevo valor antes de saber si Firestore lo aceptó — esto hace que la app se sienta rápida. Si la escritura falla (sin red, por ejemplo), el controlador revierte `state.linkedElder` al snapshot que guardó antes de intentarlo, y el slider vuelve al valor anterior. Así el familiar siempre ve el estado real, no un valor fantasma.

**Por qué las preferencias de TTS se aplican en la *próxima* locución**
`flutter_tts` no permite cambiar volumen o velocidad de una frase que ya está siendo reproducida en Android. El provider aplica los cambios en cuanto los recibe, pero si el mayor está oyendo una respuesta en ese momento, los cambios surtirán efecto a partir de la siguiente. Esto no es un bug; está documentado en un comentario de `tts_service.dart:20`.

---

## 5. Deuda técnica conocida (no resuelta aún)

- ~~**Duplicación de stream de usuario**~~ — **RESUELTA** en sesión 2026-05-11. Ver sección 8.

- ~~**Campo `_userSubscription` declarado `late`**~~ — **RESUELTA** junto con el punto anterior.

- ~~**`withOpacity` deprecado** en `home_screen.dart`~~ — **RESUELTA** en sesión 2026-05-11 (`.withValues(alpha: 0.1)`).

- ~~**`print` en producción** en `home_screen.dart`~~ — **RESUELTA** en sesión 2026-05-11.

- ~~**`GeminiService` y `SpeechService` instanciados directamente**~~ — **RESUELTA** en sesión 2026-05-11. Ver sección 8, B.1.

- ~~**Saludo hardcodeado a `'¡Hola!'`**~~ — **PARCIALMENTE RESUELTA** en sesión 2026-05-12. `UserModel` ya tiene campo `name`; el AppBar muestra `"Hola, [name]"`. Pendiente: pantalla/flujo para que el mayor introduzca su nombre en el onboarding.

- **Ruta de Firestore `'users'` hardcodeada** en `current_user_provider.dart` — debería ser una constante compartida con `auth_repository.dart`. Riesgo de desincronización si se renombra la colección.

---

## 6. Cómo probar mañana en 30 segundos

1. Arranca la app en el dispositivo/emulador del **mayor** (`flutter run`). Asegúrate de que tiene sesión iniciada y está en `HomeScreen`.
2. Arranca la app en el dispositivo/emulador del **familiar**. Inicia sesión y verifica que el panel muestra los deslizadores del mayor vinculado.
3. En el panel del familiar, arrastra el deslizador **Tamaño del texto** a la derecha y suéltalo.
4. Observa el móvil del mayor: el título y el subtítulo deben aumentar de tamaño en aproximadamente 1 segundo, sin reiniciar la app.
5. Arrastra el deslizador **Velocidad del habla** al mínimo y suéltalo.
6. En el móvil del mayor, pulsa el micrófono, di algo y espera la respuesta de voz: debe sonar más lenta.
7. Para probar el rollback: desactiva el wifi del familiar, mueve un deslizador y suéltalo → el slider debe volver al valor anterior y aparecer un mensaje de error.

---

## 7. Próximo paso

~~Milestone 3 — eliminar duplicación de streams antes de auto-login~~ — **completado** en sesión 2026-05-11.

**Siguiente:** escritura de tests unitarios e integración para HU-1 → HU-4. El código está estabilizado y no se esperan más cambios en estas áreas.

---

## 8. Sesión 2026-05-11 — Estabilización pre-tests (HU-1 → HU-4)

### Objetivo
Cerrar toda la deuda técnica y los gaps de navegación antes de escribir los tests, para que los tests no tengan que rehacerse.

---

### 8.1 `core/widgets/SignOutButton` — creación y corrección

**Creado:** `lib/core/widgets/sign_out_button.dart` — `ConsumerWidget` que llama a `ref.read(authRepositoryProvider).signOut()`. El router reacciona al evento de Firebase Auth y redirige; el widget no navega explícitamente.

**Añadido `signOut()` a `AuthRepository`** (`lib/features/onboarding/data/auth_repository.dart`):
```dart
Future<void> signOut() async => await _auth.signOut();
```

**Ubicación correcta:** solo en `DashboardScreen` (familiar) y `EnterPairingCodeScreen` (válvula de escape si el familiar se equivoca de cuenta). **No** en `HomeScreen` (el mayor no cierra sesión — su identidad es anónima y ligada al dispositivo).

**Bug detectado y corregido:** al pulsar el botón no pasaba nada. Dos causas raíz:
1. `RouterNotifier` no escuchaba `firebaseAuthUserProvider` → GoRouter nunca reevaluaba los redirects tras el signOut.
2. `CompanionAuthController` no reseteaba su estado en memoria → el router seguía viendo `status: linked` y devolvía al familiar al `/dashboard`.

**Fix:**
- Nuevo método `signOut()` en `CompanionAuthController` que resetea el estado a `const CompanionAuthState()`.
- Nuevo listener en `RouterNotifier` sobre `firebaseAuthUserProvider`: cuando la sesión de Firebase cae a null, llama a `companionAuthController.signOut()` y a `notifyListeners()`.

---

### 8.2 Auditoría de navegación

Flujos auditados y corregidos:

| Pantalla | Problema | Solución |
|---|---|---|
| `home_screen.dart` | Dos botones de AppBar (`home`, `person`) sin acción — dead UI | Eliminados; AppBar queda mínimo con `automaticallyImplyLeading: false` |
| `companion_auth_choice_screen.dart` | Sin AppBar → botón de retroceso invisible pese a estar en la pila (`context.push`) | Añadido AppBar con `context.pop()` |
| `enter_pairing_code_screen.dart` | Sin salida: el router fuerza esta pantalla hasta que el familiar vincule; si se equivocó de cuenta, quedaba atrapado | Añadido AppBar con `SignOutButton` en `actions` |
| `home_screen.dart` (deuda) | `withOpacity` deprecado + `print()` en producción | `.withValues(alpha: 0.1)` + eliminado el `print` |

Flujos de navegación resultantes (bloqueados y estables):
- **Mayor:** `splash → onboarding → home` (sin retroceso desde home — correcto)
- **Familiar:** `splash → onboarding ←pop→ companion/choice ←go→ login/register → pairing (escape: sign out) → dashboard (escape: sign out)`

---

### 8.3 HU-4 cleanup — B.1: GeminiService + SpeechService como providers

**Problema:** `chatControllerProvider` instanciaba `GeminiService()` y `SpeechService()` directamente dentro del closure del provider — antipatrón de DI.

**Solución:**
- `lib/core/services/gemini_service.dart`: añadido `geminiServiceProvider = Provider<GeminiService>(...)`. Eliminado `print()` del catch.
- `lib/core/services/speech_service.dart`: añadido `speechServiceProvider = Provider<SpeechService>(...)`. Eliminados los callbacks `onStatus`/`onError` con `print()` de `initiate()`.
- `lib/features/conversation/domain/chat_controller.dart`: `chatControllerProvider` usa `ref.watch` para los tres servicios.

---

### 8.4 HU-4 cleanup — B.2: Romper acoplamiento horizontal dashboard → onboarding

**Problema:** `dashboard_controller.dart` importaba `companionAuthControllerProvider` de `features/onboarding` — violación de la regla "no acoplamiento horizontal entre features".

**Solución:** `dashboardControllerProvider` ahora lee `linkedElderId` de `currentUserProvider` (en `core/providers/`). Cuando el stream aún no ha emitido (`elderId == null`), el controller permanece en estado `loading` en lugar de disparar un error, ya que el dashboard solo es accesible para familiares vinculados.

---

### 8.5 HU-4 cleanup — B.3: Eliminar `_userSubscription` de `ElderAuthController`

**Problema:** `ElderAuthController` mantenía un `StreamSubscription<UserModel?>` a Firestore (`_userSubscription`) mientras `currentUserProvider` ya escuchaba el mismo documento. Dos escuchas al mismo doc; el router usaba los datos del controlador en lugar de `currentUserProvider`.

**Solución (tres archivos):**

`lib/features/onboarding/domain/elder_auth_controller.dart`:
- `_userSubscription` y su campo `StreamSubscription<UserModel?>?` eliminados.
- `_init()` reemplaza el `streamUser().listen(...)` por un único `await _authRepository.getUser(uid)` para poblar el estado inicial. Los datos en tiempo real fluyen a través de `currentUserProvider`.

`lib/core/config/app_router.dart`:
- `RouterNotifier` añade un listener a `currentUserProvider` que actualiza `_elderUser: UserModel?`.
- `redirect()` lee autonomía y linkCode de `(_elderUser?.role == UserRole.elder ? _elderUser : _elderState.user)` — `currentUserProvider` tiene prioridad; el estado del controlador actúa de fallback durante el hueco entre arranque y primera emisión del stream.
- **Efecto observable:** cuando el familiar vincula al mayor (borra `linkCode` en Firestore), el router del mayor redirige a `/home` automáticamente sin que el mayor tenga que pulsar "Continuar".

**Nota sobre `checkPairingStatus()`:** el método sigue existiendo en el controlador (el botón "Continuar" lo llama), pero ya es redundante — el redirect ocurre solo vía `currentUserProvider`. Se puede eliminar en una iteración posterior junto con el botón.

---

### 8.6 Estado del codebase tras la sesión

- `flutter analyze` sobre todos los archivos tocados: **0 warnings**.
- Deuda técnica de la sesión anterior: **completamente resuelta**.
- Acoplamiento horizontal restante conocido: `SignOutButton` importa `authRepositoryProvider` de `features/onboarding/data` — aceptado por consenso; mover `authRepositoryProvider` a `core/` sería la solución limpia a futuro.
- **Siguiente acción:** escritura de tests unitarios e integración para HU-1 → HU-4.

---

## 9. Sesión 2026-05-12 — UI HomeScreen + bug companion re-login

### Objetivo
Mejorar la UI de `HomeScreen` para el mayor, añadir el campo `name` a `UserModel`, y corregir el bug por el que un familiar ya vinculado era enviado de nuevo a la pantalla de código al re-iniciar sesión.

---

### 9.1 Paleta de color elder — opciones cálidas

Se evaluaron 4 alternativas al teal original (`elderPrimary`) basadas en psicología del color para usuarios mayores (los tonos cálidos se perciben mejor por el amarillamiento del cristalino con la edad):

| Opción | Nombre | Color | Sombra (30% opacidad) |
|--------|--------|-------|-----------------------|
| 1 | Terracota | `Color(0xFFC0533A)` | `Color(0x4DC0533A)` |
| 2 | Canela | `Color(0xFFA0522D)` | `Color(0x4DA0522D)` |
| 3 | Siena Tostado | `Color(0xFFBF6040)` | `Color(0x4DBF6040)` |
| 4 | Marrón Ámbar | `Color(0xFF8B5A2B)` | `Color(0x4D8B5A2B)` |

Patrón: para derivar la sombra de cualquier color primario, sustituir `FF` por `4D` manteniendo los 6 dígitos RGB.

**Nota:** `app_theme.dart` tiene actualmente `Color(0xD90429)` — valor inválido (7 dígitos hex, sin prefijo alpha). Debe ser reemplazado por una de las opciones anteriores antes de compilar.

---

### 9.2 `UserModel` — campo `name`

**Archivo:** `lib/core/models/user_model.dart`

Añadido campo `String? name` opcional (null por defecto). Actualizado en `copyWith` (con patrón `_unset`), `toMap` y `fromMap`. Los documentos Firestore existentes sin el campo leen `null` sin necesidad de migración.

El campo está listo; el flujo de onboarding para que el mayor introduzca su nombre queda fuera del alcance de esta sesión.

---

### 9.3 `HomeScreen` — rediseño de layout

**Archivo:** `lib/features/conversation/presentation/home_screen.dart`

Cambios aplicados:

| Elemento | Antes | Después |
|----------|-------|---------|
| Saludo `"¡Hola!"` | Texto gigante en el cuerpo (siempre visible) | Movido al `AppBar`: `"Hola, [name]"` o `"Hola"` si `name == null` |
| Etiqueta de estado | Siempre visible encima del texto | Solo visible en estados activos (`listening`, `thinking`, `talking`, `error`); en `initial` el espacio queda libre para el texto de respuesta |
| Área de texto | `Expanded` compartido con la etiqueta de estado | `Expanded` completo para el texto; más espacio disponible automáticamente |
| Auto-scroll | No existía | `ScrollController` + `ref.listen<ChatState>` → `animateTo(maxScrollExtent)` con `postFrameCallback` cada vez que `responseAI` cambia durante `talking` |
| Botón teclado | `OutlinedButton` grande sobre el micrófono | `_KeyboardButton` compacto (icono + label `"¿Teclado?"`) centrado entre los botones de acción inferiores |
| Botón ajustes | En fila inferior derecha, siempre visible | Envuelto en `Visibility(maintainSize: true)` — invisible para mayores con `autonomy == dependent`, mantiene el layout estable |

Estructura del layout resultante (de arriba a abajo):
```
AppBar ("Hola, [name]")
[etiqueta de estado — solo si no es initial]
Expanded → SingleChildScrollView (texto respuesta/escucha)
Micrófono (botón principal)
Row: [Emergencia] [¿Teclado?] [Ajustes / invisible]
```

**Accesibilidad:** `_KeyboardButton` tiene `ConstrainedBox(minWidth: 80, minHeight: 80)` para cumplir el mínimo de toque WCAG 2.2.

---

### 9.4 Bug: familiar vinculado redirigido a pantalla de código al re-login

**Síntoma:** un familiar que ya tenía un mayor vinculado, al volver a abrir la app o iniciar sesión de nuevo, era enviado a `/companion/pairing` en lugar de `/dashboard`.

**Causa raíz (dos bugs independientes):**

**Bug 1 — `signIn()` nunca promovía a `linked`**
`companion_auth_controller.dart:20` — el status siempre se fijaba a `authenticated` aunque `getUser()` devolviera un `linkedElderId` no nulo. El router solo enruta a `/dashboard` cuando `status == CompanionAuthStatus.linked` (router línea 73), así que el familiar siempre caía en `/companion/pairing`.

**Bug 2 — Sin rehydratación en arranque en frío**
`CompanionAuthController` no tenía `_init()`. Al reiniciar la app, Firebase Auth conserva la sesión activa (`FirebaseAuth.currentUser` es no nulo de forma síncrona), pero el controlador arrancaba con `status = idle` sin leer Firestore. El familiar veía la pantalla de login en lugar de ir directo al dashboard.

**Archivos modificados:**

`lib/features/onboarding/data/auth_repository.dart`
- Añadido helper síncrono `String? currentUid() => _auth.currentUser?.uid`.

`lib/features/onboarding/domain/companion_auth_controller.dart`
- Constructor llama a `_init()`.
- `_init()` lee `currentUid()` → `getUser()` → establece `status = linked | authenticated` según `linkedElderId`.
- `signIn()` ahora asigna `status` condicionalmente: `linkedElderId != null ? linked : authenticated`.

```dart
// _init() — cubre el arranque en frío
Future<void> _init() async {
  final uid = _authRepository.currentUid();
  if (uid == null) return;
  final userData = await _authRepository.getUser(uid);
  if (userData == null || userData.role != UserRole.companion) return;
  state = state.copyWith(
    status: userData.linkedElderId != null
        ? CompanionAuthStatus.linked
        : CompanionAuthStatus.authenticated,
    companionId: uid,
    linkedElderId: userData.linkedElderId,
  );
}

// signIn() — cubre el re-login explícito
state = state.copyWith(
  status: userData?.linkedElderId != null
      ? CompanionAuthStatus.linked
      : CompanionAuthStatus.authenticated,
  ...
);
```

`flutter analyze` sobre los archivos tocados: **0 warnings**.

---

### 9.5 Herramienta auxiliar de desarrollo — borrado masivo de usuarios Firebase

Durante el desarrollo se acumulan cuentas anónimas en Firebase Authentication (una por cada vez que se reinstala la app). No hay UI de borrado masivo en la consola de Firebase.

**Solución:** script Node.js local (`~/firebase-cleanup/delete-test-users.js`) usando Firebase Admin SDK. Lista todos los usuarios con `listUsers(1000)` paginado y los elimina con `deleteUsers(uids)`. Requiere descargar un `serviceAccountKey.json` desde Project Settings → Service accounts (no commitear a git).

```js
const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });

async function deleteAllUsers(token) {
  const { users, pageToken } = await admin.auth().listUsers(1000, token);
  const uids = users.map(u => u.uid);
  if (uids.length) {
    const r = await admin.auth().deleteUsers(uids);
    console.log(`Deleted ${r.successCount}, failed ${r.failureCount}`);
  }
  if (pageToken) await deleteAllUsers(pageToken);
}
deleteAllUsers().then(() => process.exit());
```

**Nota sobre identidad del mayor:** Firebase Anonymous Auth persiste entre lanzamientos en producción (el usuario real nunca reinstala). El problema de múltiples cuentas es exclusivo del entorno de desarrollo. No se requieren cambios en la arquitectura de auth.

---

### 9.6 Estado del codebase tras la sesión

- `flutter analyze` sobre todos los archivos tocados: **0 warnings**.
- Bug de re-login del familiar: **resuelto**.
- `UserModel.name`: campo listo, falta el flujo de onboarding para introducirlo.
- `elderPrimary` en `app_theme.dart`: **pendiente de que el usuario elija una de las 4 opciones cálidas** y actualice también la sombra (`0x4D` + mismos RGB).
- **Siguiente acción:** escritura de tests unitarios e integración para HU-1 → HU-4 (pendiente de que `elderPrimary` quede fijado para no invalidar snapshots visuales).

---

## 10. Sesión 2026-05-13 — Nombre del mayor aprendido por Gemini

### Objetivo
Eliminar cualquier entrada de texto para el nombre del mayor. En lugar de pedirlo en el onboarding, Gemini lo aprende durante la conversación mediante function calling. El familiar puede verlo y sobreescribirlo desde el dashboard.

---

### 10.1 Decisión de diseño

El mayor nunca escribe su nombre. Dos caminos según el rol:

- **Mayor independiente y mayor vinculado:** Gemini pregunta el nombre de forma natural en la primera conversación y llama a `guardarNombre` cuando lo confirma. Esto se aplica a ambos tipos de mayor.
- **Familiar:** puede ver y editar el nombre del mayor desde el dashboard en cualquier momento (p. ej. para corregirlo si Gemini lo transcribió mal).

La razón: el onboarding del mayor es táctil/por voz; añadir un `TextField` rompería la experiencia voice-first y supondría una barrera para usuarios mayores con dificultad para escribir.

---

### 10.2 Arquitectura del flujo

```
[HomeScreen — mayor habla]
        |
        | sendMessage(texto)
        v
[GeminiService.sendMessage()]
  lib/core/services/gemini_service.dart
        |
        | modelo detecta nombre → FunctionCall("guardarNombre", {nombre: "Carmen"})
        | GeminiService envía FunctionResponse automáticamente
        | devuelve GeminiResponse(text: "...", nombreToSave: "Carmen")
        v
[ChatController.sendMessage()]
  lib/features/conversation/domain/chat_controller.dart
        |
        | nombreToSave != null →
        |   authRepository.updateName(uid, nombre)   → Firestore users/{uid}.name
        |   geminiService.startSession(nombre)        → refresca sesión (no vuelve a preguntar)
        v
[currentUserProvider — StreamProvider]
  lib/core/providers/current_user_provider.dart
        |
        | stream emite UserModel con name actualizado
        +---------------------------+
        |                           |
        v                           v
[HomeScreen AppBar]          [DashboardScreen _ElderNameCard]
  "Hola, Carmen"               muestra nombre actualizado en tiempo real
```

**Sobreescritura por el familiar:**
```
[DashboardScreen — _ElderNameCard (inline edit)]
        |
        | familiar pulsa editar → escribe nombre → pulsa guardar
        v
[DashboardController.updateElderName(nombre)]
  lib/features/dashboard/domain/dashboard_controller.dart
        |
        | authRepository.updateName(elderId, nombre)
        v
[Firestore users/{elderId}.name]
        |
        | currentUserProvider emite cambio → HomeScreen se actualiza
```

---

### 10.3 Archivos modificados

| Archivo | Cambio |
|---------|--------|
| `lib/core/services/gemini_service.dart` | Añadido `Tool` con `FunctionDeclaration guardarNombre(nombre: string)`. Nuevo tipo `GeminiResponse` con `text` y `nombreToSave`. `startSession(String? elderName)` adapta el system prompt según si el nombre ya es conocido o no. `sendMessage` intercepta `FunctionCall`, envía `FunctionResponse` automáticamente y devuelve `GeminiResponse`. |
| `lib/features/onboarding/data/auth_repository.dart` | Añadido `updateName(String uid, String name)` — `Firestore.update({'name': name})`. |
| `lib/features/conversation/domain/chat_controller.dart` | `chatControllerProvider` recibe `elderName` de `currentUserProvider` y llama a `startSession`. En `sendMessage`, si `nombreToSave != null`: persiste nombre + refresca sesión. |
| `lib/features/dashboard/domain/dashboard_controller.dart` | Añadido `updateElderName(String name)` con patrón optimista + rollback (igual que `updateElderPreferences`). |
| `lib/features/dashboard/presentation/dashboard_screen.dart` | Nuevo widget `_ElderNameCard`: muestra nombre actual (o placeholder "Sin nombre (lo aprende por voz)"), botón de edición inline (80×80 touch target), `didUpdateWidget` para sincronizar con cambios en tiempo real desde Firestore. |

---

### 10.4 Detalles de implementación notables

**`startSession` se llama dos veces al aprender el nombre**
Cuando `guardarNombre` se dispara, el controlador persiste el nombre en Firestore y luego llama a `startSession(nombre)` de forma inmediata. Esto evita que el modelo vuelva a preguntar el nombre durante la misma sesión antes de que `currentUserProvider` emita el cambio y reconstruya el provider. El `StreamProvider` disparará igualmente una reconstrucción completa del controlador con el nombre ya correcto.

**`FunctionResponse` automático dentro de `GeminiService`**
El método `sendMessage` envía la respuesta de la función al modelo internamente antes de devolver el control al controlador. Así el modelo puede componer un mensaje de confirmación natural ("¡Encantado de conocerte, Carmen!") sin que el controlador tenga que gestionar ese segundo turno.

**`_ElderNameCard.didUpdateWidget`**
Sincroniza el `TextEditingController` interno cuando Firestore empuja un nombre nuevo (p. ej. Gemini lo guarda mientras el familiar tiene el campo de edición abierto). Solo aplica si `!_isEditing` para no pisar texto que el familiar esté escribiendo.

---

### 10.5 Estado del codebase tras la sesión

- `flutter analyze` sobre todos los archivos tocados: **0 warnings**.
- El mayor ya nunca necesita escribir su nombre en ningún punto del flujo.
- Deuda técnica del saludo hardcodeado `'¡Hola!'`: **resuelta**.
- **Siguiente acción:** escritura de tests unitarios e integración para HU-1 → HU-4.
