# SPEC — Llamada de emergencia (pending.md §3)

_Documento de instrucciones para Claude Code. Proyecto: `com.rosas.quiet_companion`._
_Alcance: cablear el botón de emergencia de `HomeScreen` (`home_screen.dart:199`) a una pantalla de llamada, montar el **shell** de la pantalla de ajustes (`home_screen.dart:213`) con una única fila, y permitir al mayor sin contacto impuesto configurar su contacto de emergencia._

_Al terminar esta tarea, 2 de los 3 botones muertos de `pending.md` §2.3 quedan resueltos. Solo sobrevive el de teclado (`home_screen.dart:203`)._

---

## 0. Reglas de oro para esta tarea

1. **Cero cambios en el flujo de voz.** No tocar `chat_controller.dart`, `gemini_service.dart`, `speech_service.dart` ni `tts_service.dart` salvo para **invocar** métodos públicos ya existentes (`stop()`). Si un método necesario no existe, **preguntar antes de crearlo**.
2. **No se crea repositorio nuevo.** El único documento tocado es `users/{elderId}`, ya cubierto por `auth_repository.dart`.
3. **Nunca `ACTION_CALL` / llamada directa.** Solo `ACTION_DIAL` vía `url_launcher` + esquema `tel:`. Motivo técnico: Android lanza `SecurityException` con números de emergencia (112) si se usa `ACTION_CALL` desde una app no-sistema. Motivo de diseño: la confirmación del mayor en el marcador nativo resuelve la duda legal de PLAN.md §B y evita el permiso `CALL_PHONE`.
4. **Ningún color literal en las pantallas.** Los tokens se añaden a `core/theme/app_theme.dart`.
5. `flutter analyze` debe quedar en 0 issues. La suite debe seguir pasando.

---

## 1. Prerequisito (decisión del dev — NO ejecutar sin confirmación)

`pending.md` §7 registra: _"`SignOutButton` importa `authRepositoryProvider` desde `features/onboarding/data` → promocionar el provider a `core/`"_.

Esta feature añade el **tercer** consumidor de `authRepositoryProvider` fuera de `onboarding/` (junto a `SignOutButton` y `DashboardController`). Recomendación: promocionar **solo la declaración del provider**, dejando la clase `AuthRepository` donde está:

- Crear `lib/core/providers/auth_repository_provider.dart` con la declaración de `authRepositoryProvider`.
- Eliminar la declaración de `features/onboarding/data/auth_repository.dart` (la clase se queda).
- Actualizar imports en todos los consumidores.

**Si el dev no confirma, importar `authRepositoryProvider` desde `features/onboarding/data/auth_repository.dart` como hasta ahora y no tocar nada.** No bloquear la feature por esto.

---

## 2. Ficheros — mapa de la tarea

### Nuevos

```
lib/core/models/emergency_contact.dart
lib/core/services/emergency_call_service.dart
lib/features/settings/presentation/settings_screen.dart
lib/features/emergency/presentation/emergency_screen.dart
lib/features/emergency/presentation/emergency_contact_setup_screen.dart
test/core/services/emergency_call_service_test.dart
test/features/emergency/emergency_screen_test.dart
test/features/settings/settings_screen_test.dart
```

Nota sobre `features/settings/`: contiene **solo `presentation/`**. Es una vista que enruta, no una frontera de modelo — no tiene modelo, ni repositorio, ni estado propio. Los campos que edita viven donde les corresponde (`UserModel`, `UserPreferences`) y se escriben por sus repositorios existentes.

### Modificados

```
lib/core/models/user_model.dart                     → campo emergencyContact
lib/core/theme/app_theme.dart                       → tokens de emergencia
lib/core/config/app_router.dart                     → 2 rutas
lib/features/conversation/presentation/home_screen.dart → cablear botón (línea ~199)
lib/features/onboarding/data/auth_repository.dart   → escritura del contacto (ver §6)
android/app/src/main/AndroidManifest.xml            → bloque <queries>
pubspec.yaml                                        → url_launcher
```

### Explícitamente fuera de alcance

- El botón muerto de **teclado** (`home_screen.dart:203`) — sigue siendo tarea aparte. Es el único que sobrevive a este cambio.
- **Cualquier fila de ajustes cuya feature no exista todavía.** La lista se entrega con **exactamente una fila**. Una pantalla de ajustes con filas muertas es precisamente el problema que INFO.md §8.2 dice que ya se resolvió una vez.
- Ajustes del **companion**: no existen. `settings_screen.dart` es solo del mayor.
- Exponer en UI las preferencias de HU-4 (`UserPreferences`): fuera de alcance, aunque la lista esté preparada para alojarlas.
- `lib/features/emergency/data/`, `lib/features/emergency/domain/`, `lib/features/settings/data/`, `lib/features/settings/domain/` — **no crear**. Si al implementar parece que hacen falta, es señal de sobreingeniería: parar y consultar.

---

## 3. Modelo de datos

### 3.1 `lib/core/models/emergency_contact.dart`

```dart
enum EmergencyContactSource { companion, manual }
```

Clase `EmergencyContact` inmutable con:

| Campo | Tipo | Notas |
|---|---|---|
| `name` | `String` | Se muestra en el botón: "Llamar a María". Si el origen es `manual` y el mayor no introdujo nombre, valor por defecto `'Mi contacto'`. Nunca vacío. |
| `phone` | `String` | **Siempre E.164** (`+34600123456`). Normalizado en escritura, nunca en lectura. |
| `source` | `EmergencyContactSource` | Discrimina "lo puso la vinculación" de "lo puso el mayor". Ver §6. |

Requisitos:
- `fromMap(Map<String, dynamic>)` / `toMap()`, siguiendo el estilo exacto de `user_model.dart` y `user_preferences.dart` (mirar antes de escribir).
- `fromMap` **defensivo**: si falta `phone` o está vacío → devolver `null` desde el llamante en vez de construir un objeto inválido. Un contacto a medias es peor que ninguno.
- `source` desconocido o ausente → `EmergencyContactSource.manual` (fallback conservador: no se asume que venga de una vinculación).
- `operator ==` / `hashCode` (los tests los necesitan).

### 3.2 `lib/core/models/user_model.dart`

Añadir `final EmergencyContact? emergencyContact;`.

**`null` es un estado legal y permanente**, no un error:
- Mayor independiente que aún no ha configurado nada.
- Todos los documentos ya existentes en Firestore.

**No hacer script de migración ni backfill.** El camino null-safe es exactamente el mismo que el del mayor sin configurar, así que la migración es innecesaria por construcción.

**Cuidado con `copyWith`:** con un campo nullable, `copyWith(emergencyContact: null)` es ambiguo entre "no cambies" y "bórralo". Si el `copyWith` actual usa el patrón `?? this.campo`, **no** se puede borrar el contacto con él. Como el borrado no está en alcance, basta con dejar un comentario `// TODO: no permite limpiar el campo (patrón ??). Revisar si se añade "eliminar contacto".` No introducir un sentinel ahora.

**En `toMap()`:** si `emergencyContact == null`, **omitir la clave** en vez de escribir `null`, para no crear el campo en documentos que no lo necesitan.

---

## 4. Servicio de llamada

### 4.1 `lib/core/services/emergency_call_service.dart`

Ubicación justificada: es un borde de plataforma, hermano de `permission_service.dart` / `tts_service.dart`. Seguir su estilo y su patrón de provider.

```dart
abstract interface class EmergencyCallService {
  /// Abre el marcador del sistema con [phoneE164] premarcado.
  /// Devuelve false si el dispositivo no puede marcar (p. ej. tablet sin SIM,
  /// o <queries> mal configurado en el manifest).
  /// No lanza excepciones: el fallo es un caso de uso esperado, no un error.
  Future<bool> dial(String phoneE164);
}
```

Implementación `UrlLauncherEmergencyCallService`:

```dart
final uri = Uri(scheme: 'tel', path: phoneE164);
if (!await canLaunchUrl(uri)) return false;
return launchUrl(uri, mode: LaunchMode.externalApplication);
```

Reglas innegociables:
- **`Uri(scheme:, path:)`, nunca `Uri.parse('tel:$numero')`.** El constructor escapa `#` y `*`; la interpolación no, y un `#` en el número trunca silenciosamente la marcación.
- `LaunchMode.externalApplication` explícito.
- Envolver en `try/catch (PlatformException)` → `return false`. La UI no debe ver excepciones de plugin.
- Constante pública `const kEmergencyNumber = '112';` en este fichero.

Provider:
```dart
final emergencyCallServiceProvider =
    Provider<EmergencyCallService>((ref) => UrlLauncherEmergencyCallService());
```
Debe ser sobreescribible en tests (`ProviderScope(overrides: ...)`).

### 4.2 Flag de salida intencionada

Añadir en `lib/core/providers/` (o donde encaje con el estilo actual):

```dart
/// True mientras la app está en background por una acción deliberada
/// (marcador de emergencia). Consumidor previsto: el disparador de fin de
/// sesión de pending.md §4, para no generar un resumen espurio cuando el
/// mayor sale al marcador. Ver pending.md §3.
final intentionalBackgroundExitProvider = StateProvider<bool>((ref) => false);
```

Se pone a `true` justo antes de `dial()` y a `false` en `AppLifecycleState.resumed`. **Hoy nadie lo lee.** Se añade ahora porque §4 aún no existe y añadirlo después obliga a volver a tocar este código.

---

## 5. Pantallas

### 5.1 Decisión: ruta completa, no `Dialog`

Usar `MaterialPageRoute(fullscreenDialog: true)` (o el equivalente del router, ver §7). **No usar `showDialog`.** Razones:

- `barrierDismissible: true` cierra la pantalla con un toque tembloroso fuera del diálogo, en mitad de una emergencia. `barrierDismissible: false` elimina el problema pero entonces no se usa nada de la semántica de diálogo y solo se pagan sus límites de layout.
- Un diálogo "que ocupa la mayoría de la pantalla" deja un marco de barrera que es superficie de error pura y no aporta nada.
- Accesibilidad: un `Dialog` de Flutter **es** una ruta del Navigator, así que TalkBack lo trataría igual. No es el motivo de la decisión, pero conviene saber que no se pierde nada al descartarlo.

### 5.2 `emergency_screen.dart`

`ConsumerStatefulWidget`.

**Al montar (`initState` → `WidgetsBinding.instance.addPostFrameCallback`):**
1. Parar TTS y STT llamando a los métodos públicos ya existentes de `TtsService` / `SpeechService`. **Esto es obligatorio.** Si no, el marcador nativo compite por el `AudioSession` y el TTS sigue hablando encima; en una emergencia real es inaceptable. Se para al **abrir la pantalla**, no al pulsar marcar: la conversación deja de tener sentido en cuanto se abre esta UI.
2. Anunciar por TTS un texto corto (p. ej. "Elige a quién llamar"). Ojo al orden: parar el TTS anterior y luego hablar, no simultáneo.

**Estado leído:** `currentUserProvider` → `emergencyContact`.

**Layout (de arriba a abajo):**

| Condición | Contenido |
|---|---|
| `emergencyContact != null` | Botón grande `Llamar a {name}` → `dial(contact.phone)` |
| siempre | Botón grande `Llamar al 112` → `dial(kEmergencyNumber)` |
| siempre | Botón pequeño `Cancelar` → `Navigator.pop` |

El caso "mayor acompañado" y "mayor independiente con contacto manual" **renderizan idéntico**. `source` no afecta a esta pantalla; solo a la escritura (§6). No ramificar por `source` aquí.

**Requisitos de accesibilidad (no negociables):**
- Área táctil de los botones grandes ≥ **88dp** de alto (doble del mínimo WCAG), ancho completo menos márgenes.
- **Separación vertical grande** (≥ 32dp) entre "Llamar a {name}" y "Llamar al 112". Son acciones no equivalentes y no revocables: un fallo de puntería no puede convertir una en la otra.
- "Cancelar" en una **zona visualmente distinta** (parte inferior, tamaño y peso claramente menores, sin relleno de color). Nunca adyacente a los botones de llamada.
- `Semantics(button: true, label: ...)` en los tres. La etiqueta del 112 debe decir "Llamar a emergencias, uno uno dos" (que TalkBack no lea "ciento doce").
- `PopScope`: el botón atrás del sistema debe comportarse exactamente igual que "Cancelar", explícitamente. No dejarlo al comportamiento por defecto.
- Sin `AppBar` con back implícito; la única salida es "Cancelar" / atrás.

**Fallo de `dial()` (devuelve `false`):**
- **NO usar `SnackBar`.** Un aviso de 4 segundos que desaparece solo es inútil para esta población y peor aún en una emergencia.
- Mostrar texto **persistente**, grande, dentro de la propia pantalla ("Este dispositivo no puede hacer llamadas") **y** locutarlo por TTS.
- No comprobar `canLaunchUrl` antes de renderizar para ocultar botones: es asíncrono y no distingue "no hay marcador" de "`<queries>` mal configurado". Renderizar siempre, fallar en el tap con feedback claro.

**Antes de `dial()`:** poner `intentionalBackgroundExitProvider` a `true`.

### 5.3 `emergency_contact_setup_screen.dart`

Destinada al mayor **cuyo contacto no viene impuesto por la vinculación**. Es donde se va la mitad del esfuerzo de la feature.

- **Punto de entrada:** es la subpantalla de la única fila de `settings_screen.dart` (§5.4). No es alcanzable de ninguna otra forma.
- **Ubicación:** se queda en `features/emergency/presentation/`, **no** en `features/settings/`. Su lógica (normalización E.164, rechazo del 112, semántica de `source`) es de emergencia; `settings` solo enruta hacia ella.
- **Teclado numérico:** `TextField` con `keyboardType: TextInputType.phone`, fuente grande, `autofocus: true`.
- **Entrada del teléfono:** el mayor teclea **9 dígitos nacionales**; el prefijo `+34` se muestra como `prefixText` fijo y **no se teclea**. Menos superficie de error.
- **Validación** (todas antes de habilitar "Guardar"):
    - Exactamente 9 dígitos, primero en `[6-9]` (móvil o fijo español). Regex final tras normalizar: `^\+34[6-9]\d{8}$`.
    - **Rechazar 112 y cualquier número de emergencia** como contacto personal, con mensaje explícito. Ya hay un botón para eso; guardarlo aquí duplicaría la acción con etiqueta engañosa.
- **Nombre:** campo **opcional**. Tecleado libre es carga alta para esta población y el nombre solo sirve de etiqueta. Si se deja vacío → `'Mi contacto'`. Tensión de diseño conocida y documentada: en la práctica esta pantalla la usará a menudo un familiar ayudando presencialmente.
- **Confirmación antes de guardar:** mostrar el número formateado en grande y pedir confirmación explícita. Un dígito mal en un contacto de emergencia es un fallo silencioso hasta el peor momento posible.
- **Escritura:** normalizar a E.164 → `EmergencyContact(source: manual)` → método del `AuthRepository` (§6.1). No escribir a Firestore directamente desde la pantalla.

### 5.4 `settings_screen.dart` — shell de ajustes

Se entrega el **contenedor**, no una feature de ajustes. Objetivo: fijar ahora el idioma visual y de navegación mientras se tiene la feature delante, para que cada ajuste futuro sea **una fila más y cero refactor** (principio de arquitectura aditiva).

**Estructura:** una lista de filas grandes. Cada fila: `título` + `valor actual` + chevron → navega a una subpantalla. Altura ≥ 88dp, mismo criterio de accesibilidad que §5.2. Sin `Switch` ni edición inline: todo ajuste se edita en su propia subpantalla, con confirmación.

**Visibilidad — declarativa por fila, NO por pantalla.**

Cada fila declara su propio predicado sobre el `UserModel` de `currentUserProvider`. La pantalla se renderiza si **al menos una** fila es visible. Modelar explícitamente, p. ej.:

```dart
class _SettingsRow {
  final String title;
  final String Function(UserModel) value;
  final bool Function(UserModel) visible;
  final String route;
}
```

Predicado de la única fila existente:

```dart
// Fila "Contacto de emergencia"
visible: (user) => user.emergencyContact?.source != EmergencyContactSource.companion
```

Comportamiento resultante:

| Caso | `source` | Fila | Pantalla |
|---|---|---|---|
| Independiente sin configurar | `null` | ✅ | ✅ |
| Independiente con contacto manual | `manual` | ✅ | ✅ |
| Acompañado | `companion` | ❌ | ❌ (0 filas) |
| Independiente-manual que vincula después | `manual` (preservado, §6.2) | ✅ | ✅ |

**Por qué así y no `role == independent`:**

1. **Una sola fuente de verdad.** La fila está oculta *exactamente cuando* el contacto no es editable, porque el predicado deriva del mismo `source` que gobierna la precedencia de §6.2. Un `role`/`companionId` es un segundo criterio que puede divergir del primero.
2. **No hay que arrancarlo después.** El día que se añada la fila de velocidad de habla (`UserPreferences`, HU-4), esa fila **sí** es del mayor acompañado. Un gate a nivel de pantalla habría que deshacerlo; el predicado por fila absorbe el caso sin tocar nada.
3. **Coherencia de producto.** Ocultarle al mayor acompañado toda su configuración de accesibilidad es paternalismo hacia esta población — el mismo criterio por el que se rechazó la accesibilidad adaptativa por IA. Hoy la pantalla desaparece para él porque *casualmente* la única fila no le aplica, no porque se le niegue el acceso a configurarse.

**Valor mostrado en la fila:** el `name` del contacto si existe; si `emergencyContact == null`, un texto de vacío explícito y accionable ("Sin configurar"), nunca la fila en blanco ni deshabilitada.

**No** añadir `AppBar` con acciones, ni buscador, ni agrupación por secciones. Con una fila, es ruido.

### 5.5 `app_theme.dart`

Añadir los tokens necesarios (color de acento del 112, color del botón de contacto, altura mínima de botón de emergencia). El 112 debe ser **visualmente distinto** del botón de contacto, pero comprobar contraste ≥ 7:1 (AAA) contra el fondo y coherencia con `elderPrimary` (Canela `0xFFA0522D`, decisión cerrada en INFO.md §9 — **no tocar**).

---

## 6. Escritura del contacto

### 6.1 Origen `manual`

Añadir a `AuthRepository`:

```dart
Future<void> updateEmergencyContact(String uid, EmergencyContact contact);
```

Un `update` sobre `users/{uid}` con la clave `emergencyContact`. Ruta vía `FirestorePaths` (**nunca** `'users'` hardcodeado — es deuda registrada en INFO §5).

### 6.2 Origen `companion` (desnormalización en la vinculación)

**Antes de tocar nada, localizar dónde ocurre realmente la escritura de la vinculación.** Hay dos posibilidades y cambian el alcance:

- **`WriteBatch` en `auth_repository.dart` (`linkCompanionToElder`)** → cambio solo en cliente.
- **Cloud Function callable `validateAndLink`** → el cambio va en `functions/` (Node.js) y **requiere `firebase deploy --only functions`**. Avisar al dev antes de proceder; puede haber lógica duplicada.

En cualquiera de los dos casos, en el mismo batch/transacción que vincula:
- Escribir en el doc del **mayor**: `emergencyContact = { name: <nombre del familiar>, phone: <teléfono del familiar>, source: 'companion' }`.
- Requiere `phoneNumber` en `UserModel` del familiar, recogido en `companion_register_screen.dart`. Si no existe aún, hay que añadirlo (campo obligatorio en el registro, misma validación E.164 de §5.3).

**Regla de precedencia:** si el mayor ya tiene `emergencyContact` con `source == manual`, **NO sobrescribirlo**. Para esto existe el campo `source`. Requiere leer el doc del mayor dentro de la transacción antes de escribir — si la vinculación es un `WriteBatch` puro (sin lecturas), hay que promoverlo a `runTransaction`. Justificación: sobrescribir en silencio la elección deliberada del mayor es un fallo de producto, no un detalle.

**Limitación aceptada (documentar en la memoria del TFG):** si el familiar cambia su teléfono después de vincular, el mayor conserva el antiguo. La alternativa (`onDocumentUpdated` sobre `users/{companionId}` propagando a los mayores vinculados) son ~20 líneas de Cloud Function y queda **fuera de alcance**. Lo que **no** es opción es que el mayor lea el documento del familiar: sería una lectura cross-user y exigiría abrir las reglas de Firestore. La desnormalización es precisamente lo que evita reglas nuevas y lecturas extra — el mayor solo lee su propio doc, que ya fluye por `currentUserProvider`.

---

## 7. Router

`lib/core/config/app_router.dart` — **seguir el patrón ya existente en el fichero** (no asumir `go_router` ni `Navigator` 1.0; leerlo primero).

Tres rutas:
- `/emergency` → `EmergencyScreen`, presentada como **fullscreen dialog** (`fullscreenDialog: true` en `MaterialPageRoute`, o `MaterialPage(fullscreenDialog: true)` en el `pageBuilder` si es `go_router`).
- `/settings` → `SettingsScreen`, presentación estándar.
- `/settings/emergency-contact` → `EmergencyContactSetupScreen`, presentación estándar. Ruta **anidada bajo `/settings`** aunque el widget viva en `features/emergency/`: la jerarquía de rutas refleja la navegación del usuario, no la del sistema de ficheros.

Ninguna de las tres debe alterar la lógica de redirect existente que fluye por `currentUserProvider`.

---

## 8. Cableado de los botones de `HomeScreen`

`lib/features/conversation/presentation/home_screen.dart`. Esta tarea resuelve **dos** de los tres `onPressed: () {}` de `pending.md` §2.3.

### 8.1 Emergencia (línea ~199)

Sustituir `onPressed: () {}` por la navegación a `/emergency`.

- **El botón se muestra siempre**, también si `emergencyContact == null`: el 112 siempre está disponible, así que la pantalla nunca está vacía. Esto corrige el planteamiento de `pending.md` §3 ("mayor independiente sin familiar vinculado → ocultar el botón"), escrito antes de contemplar el 112. **Actualizar `pending.md` §3 en consecuencia** para que no quede contradiciendo al código.

### 8.2 Ajustes (línea ~213)

Sustituir `onPressed: () {}` por la navegación a `/settings`, envuelto en el **mismo patrón `Visibility`** ya usado en el fichero (mirarlo antes de escribir; no introducir un patrón nuevo).

Predicado: **idéntico al de la visibilidad de la pantalla** (§5.4) — el botón se muestra si hay ≥1 fila visible. **No duplicar la lógica**: extraer el cálculo de filas visibles a una función pura reutilizable (p. ej. `visibleSettingsRows(UserModel)`) e invocarla desde ambos sitios. Si el botón y la pantalla calculan su visibilidad por separado, acabarán divergiendo.

Un botón que abre una pantalla vacía es tan malo como uno que no responde.

### 8.3 Teclado (línea ~203)

**No tocar.** Sigue muerto; tarea aparte.

---

## 9. Android

`android/app/src/main/AndroidManifest.xml` — **solo este fichero**. No tocar `src/debug/` ni `src/profile/` (contienen únicamente el permiso de INTERNET del flavor). No tocar `MainActivity.kt`.

Añadir como **hijo directo de `<manifest>`**, hermano de `<application>` (NO dentro de `<application>`):

```xml
<queries>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="tel" />
    </intent>
</queries>
```

Sin esto, en Android 11+ (API 30) `canLaunchUrl` devuelve **`false` siempre** por el filtrado de visibilidad de paquetes, y el botón parecerá roto en cualquier móvil moderno. Es el fallo más probable de toda esta feature y no se reproduce en emuladores antiguos.

**No añadir el permiso `CALL_PHONE`.** Si aparece en el manifest fusionado, algo se ha hecho mal.

**iOS:** fuera de alcance. Si algún día se contempla, requiere `LSApplicationQueriesSchemes` con `tel` en `Info.plist`, y `tel:` **nunca** funciona en simulador (solo en dispositivo real).

---

## 10. Dependencias

`pubspec.yaml`: añadir `url_launcher` (última estable compatible). Justificación: única forma estándar de abrir el marcador, mantenida por el equipo de Flutter. **No añadir `permission_handler` ni ningún paquete de llamada directa.**

Comprobar que no colisiona con el ecosistema FlutterFire alineado a `firebase_core` 3.x. Si `pub get` reporta conflicto, **parar y avisar** — no "resolver" bajando versiones de Firebase.

---

## 11. Tests

`url_launcher` no es testeable sin mockear `UrlLauncherPlatform`; por eso existe la interfaz `EmergencyCallService`. Los widget tests **nunca** tocan el plugin.

### 11.1 `test/features/emergency/emergency_screen_test.dart`

Fake:
```dart
class FakeEmergencyCallService implements EmergencyCallService {
  final List<String> dialed = [];
  bool result = true;
  @override
  Future<bool> dial(String phone) async { dialed.add(phone); return result; }
}
```
Inyectado con `ProviderScope(overrides: [emergencyCallServiceProvider.overrideWithValue(fake)])`. Seguir el estilo de fakes de la suite existente (mirar `test/features/dashboard/dashboard_controller_test.dart`).

Casos:

| # | Estado de `currentUserProvider` | Aserción |
|---|---|---|
| 1 | contacto con `source: companion` | 3 botones; el de contacto muestra el nombre; tap → `dialed == ['+34600123456']` |
| 2 | contacto con `source: manual` | Render **idéntico** al caso 1 |
| 3 | `emergencyContact == null` | **2 botones**; no existe el de contacto; tap en 112 → `dialed == ['112']` |
| 4 | cualquiera | tap en 112 → `dialed == ['112']` |
| 5 | `result = false` | Aparece texto persistente de error; **no** hay `SnackBar` |
| 6 | cualquiera | tap en "Cancelar" → la ruta se cierra |

Añadir un test de que TTS/STT reciben `stop()` al montar, si los servicios son inyectables por provider. Si no lo son, **no refactorizarlos** para conseguirlo: anotarlo como test diferido en `test.md`.

### 11.2 `test/core/services/emergency_call_service_test.dart`

Solo la construcción del URI (que se puede testear sin plugin):
- `dial('+34600123456')` construye `tel:+34600123456`.
- Un número con `#` no trunca (prueba de regresión de `Uri.parse`).

Si mockear `UrlLauncherPlatform` resulta laborioso, este fichero puede limitarse a lo anterior extrayendo la construcción del `Uri` a una función pura testeable.

### 11.3 `test/features/settings/settings_screen_test.dart`

Todo sobre `currentUserProvider` sobreescrito; sin Firestore.

| # | `emergencyContact` | Aserción |
|---|---|---|
| 1 | `null` | 1 fila visible; muestra el texto de vacío ("Sin configurar") |
| 2 | `source: manual` | 1 fila visible; muestra el `name` del contacto |
| 3 | `source: companion` | **0 filas**; la pantalla no se renderiza (o renderiza su estado vacío, según lo implementado) |
| 4 | `source: manual` | tap en la fila → navega a `/settings/emergency-contact` |

Y un test de `home_screen.dart` (o de la función pura, si se extrae según §8.2): el botón de ajustes **no** está presente con `source: companion`, y **sí** con `null` y con `manual`. Si se extrajo `visibleSettingsRows(UserModel)`, testear esa función directamente es preferible a un widget test.

### 11.4 Validación (unit)

La lógica de validación E.164 y de rechazo del 112 debe vivir en una **función pura estática** testeable sin widget:
- `'600123456'` → `'+34600123456'`
- `'112'` → rechazado
- `'12345'` → rechazado
- `'500123456'` → rechazado (no empieza por 6-9)

### 11.5 Estado previo de la suite

`test/features/dashboard/dashboard_controller_test.dart:191` está **en rojo** (`pending.md` §2.1), pero test está ya commiteado. El error del test son tarea del dev (§2.1), **no de esta feature**. Si al ejecutar `flutter test` ese fallo sigue ahí, es preexistente: reportarlo, no arreglarlo dentro de este cambio.

---

## 12. Criterios de aceptación

- [ ] `flutter analyze` → 0 issues.
- [ ] Todos los tests nuevos pasan; ningún test previamente verde se rompe.
- [ ] Mayor con familiar vinculado: botón → pantalla con 3 botones, el del familiar con su nombre.
- [ ] Mayor independiente sin contacto: botón → pantalla con 112 + Cancelar.
- [ ] Mayor independiente que configura contacto manual: render de `/emergency` idéntico al del mayor acompañado.
- [ ] Botón de ajustes de `HomeScreen`: **oculto** con `source: companion`; **visible** con `null` y con `manual`.
- [ ] La visibilidad del botón de ajustes y la de la pantalla se calculan con **la misma** función pura (no hay lógica duplicada).
- [ ] La lista de ajustes tiene **exactamente una fila**; ninguna fila muerta.
- [ ] Vinculación posterior **no** sobrescribe un contacto `manual`, y la fila de ajustes sigue visible después.
- [ ] `pending.md` §3 actualizado: el botón de emergencia ya no se oculta (§8.1).
- [ ] `pending.md` §2.3 actualizado: quedan 1 de 3 botones muertos.
- [ ] Tap en 112 abre el marcador nativo del sistema con `112` premarcado y **sin llamar**.
- [ ] El manifest fusionado **no** contiene `CALL_PHONE`.
- [ ] Verificado en **dispositivo físico con Android 11+** (el `<queries>` no falla en todos los emuladores).
- [ ] TTS y STT están parados al abrir la pantalla de emergencia.
- [ ] Ningún color literal fuera de `app_theme.dart`.
- [ ] Ningún `'users'` hardcodeado introducido.

---

## 13. Cuándo parar y preguntar

- `pub get` reporta conflicto con el ecosistema Firebase.
- La escritura de la vinculación resulta estar en la Cloud Function `validateAndLink` (§6.2) → implica despliegue.
- `UserModel` del familiar no tiene `phoneNumber` y añadirlo obliga a tocar el flujo de registro más de lo trivial.
- `TtsService` / `SpeechService` no exponen un `stop()` público.
- Aparece la tentación de crear `features/emergency/data|domain/` o `features/settings/data|domain/`.
- Aparece la tentación de añadir una segunda fila a la lista de ajustes.
- `UserModel` no permite derivar el predicado de §5.4 solo desde `emergencyContact?.source` (no debería hacer falta ningún otro campo — si parece que sí, es un error de diseño y hay que consultar antes de introducir `role`/`companionId` en la condición).