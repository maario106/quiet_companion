# HU-1 — Selección de Autonomía (Onboarding y Vinculación)

- **Estado:** Completada (estabilizada; con desviaciones registradas en §5–§6).
- **Ámbito:** Implementado.
- **Requisitos cubiertos:** RF-1 (Selección Inicial de Modo de Uso), RF-2 (Generación y Consumo de Código de Vinculación). Toca RNF-9 (aislamiento de identidades) — **cumplido solo en parte**, ver §5.2.
- **Casos de uso:** CU-01, CU-02, CU-03.
- **Evidencia (commits):** `5555d83` (inicio del onboarding), `104eeca` (onboarding dual, controladores, router, primera vinculación por `WriteBatch`), `96cfd57` (Milestone 1 y 2: `currentUserProvider`, `FirestorePaths`), `c117166` (estabilización: navegación, DI, router, UI), `47fd26c` (promoción de `authRepositoryProvider` a `core/`; vinculación migrada a `runTransaction`), `e68b451` (teléfono del familiar + desnormalización del contacto al vincular), `2ebf10f` (tests de vinculación y de redirección del router), `895c921` (fix `refreshElderData`).
- **Evidencia (código):** `lib/features/onboarding/presentation/{splash_screen,onboarding_screen,enter_pairing_code_screen,companion_auth_choice_screen,companion_login_screen,companion_register_screen}.dart`, `lib/features/onboarding/domain/{elder_auth_controller,elder_auth_state,companion_auth_controller,companion_auth_state}.dart`, `lib/features/onboarding/data/auth_repository.dart`, `lib/core/config/app_router.dart`, `lib/core/models/user_model.dart`, `lib/core/constants/firestore_paths.dart`, `lib/core/providers/current_user_provider.dart`, `lib/core/widgets/sign_out_button.dart`.
- **Evidencia (fuentes documentales):** `INFO.md §8` (auditoría de navegación), `INFO.md §9.4` (bug de re-login del familiar), TFG `03-Metodologia-y-Planificacion.tex` tab:hu1, TFG `04-Analisis-y-Especificacion-del-Sistema.tex` (RF-1, RF-2, CU-01–03, tab:trazabilidad).

---

## 1. Qué entregó la HU

HU-1 resuelve el primer arranque de la aplicación y la constitución de los dos perfiles de mayor
del sistema. En el primer lanzamiento, un usuario mayor elige entre gestionar la aplicación por sí
mismo (**Mayor Independiente**) o delegar su configuración en un familiar (**Mayor Vinculado**). En el
segundo caso, el dispositivo del mayor genera un código corto de 4 caracteres que un familiar introduce
desde su propio dispositivo para completar el emparejamiento. La identidad del mayor se ancla a un
usuario anónimo de Firebase Auth ligado al dispositivo; la del familiar, a correo y contraseña.

La HU es la base sobre la que se apoyan todas las demás: el atributo `autonomy` que se fija aquí
gobierna qué interfaz ve el mayor (chat completo con ajustes vs. Modo Ultra-Simple bloqueado) y la
relación de vinculación es la que autoriza al familiar a leer y escribir las preferencias del mayor
(HU-4).

---

## 2. Criterios de aceptación (tab:hu1)

| # | Criterio de aceptación | Estado | Evidencia |
|---|---|---|---|
| CA-1 | La primera pantalla muestra dos opciones claras («Usar por mi cuenta» / «Vincular con un familiar»). | **Cumplido** | `onboarding_screen.dart:59-72` — dos `_ModeButton`: `'Usar por mi cuenta'` y `'Vincular con mi familiar'`. |
| CA-2 | Si elige «Usar por mi cuenta», se habilita un botón de «Ajustes» en su pantalla principal. | **Cumplido con matiz** | `elder_auth_controller.dart:46` fija `autonomy = independent`; `home_screen.dart:57-58,213-223` muestra el botón de ajustes cuando `visibleSettingsRows(user)` no está vacío. Matiz: la pantalla de ajustes solo contiene hoy la fila de contacto de emergencia (§5.4). |
| CA-3 | Si elige «Vincular», se genera un código corto en pantalla y la interfaz principal se bloquea hasta que el familiar se conecte. | **Cumplido** | `elder_auth_controller.dart:63-79,117-123` genera el código de 4 caracteres; `onboarding_screen.dart:79-89` lo muestra a `fontSize: 72`; el mayor permanece en el onboarding (no se enruta a `/home`) mientras `linkCode != null`; el desbloqueo es reactivo vía `currentUserProvider` (§4.5). |

---

## 3. Trazabilidad

| Artefacto | Contenido | Estado de implementación |
|---|---|---|
| RF-1 | Selección Inicial de Modo de Uso → perfil con `role = elder`, `autonomy ∈ {independent, dependent}`. | Implementado. |
| RF-2 | Generación (mayor) y consumo (familiar) de código de 4 caracteres; vinculación bidireccional **atómica**. | Implementado; atomicidad vía `runTransaction`. Nomenclatura de campos divergente respecto a la especificación (§5.1). |
| CU-01 | Seleccionar modo de uso. | Implementado. |
| CU-02 | Generar código de vinculación. | Implementado; sin reintento explícito ante colisión de código (§6). |
| CU-03 | Introducir código de vinculación. | Implementado en cliente; ejecución server-side (RNF-9) **no cumplida** (§5.2). |

---

## 4. Implementación real

### 4.1 Arranque e identidad anónima
`ElderAuthController` (`elder_auth_controller.dart:18-38`) reacciona a `authStateChanges()` (expuesto por
`AuthRepository.authStateUid()`): si no hay usuario Firebase, dispara `signInAnonymously()`; si lo hay,
hace una **lectura puntual** del documento (`getUser`) para poblar el estado inicial y delega el flujo
en tiempo real a `currentUserProvider`. Este diseño (una sola suscripción al documento, en `core/`) es
resultado del retrabajo de estabilización descrito en §5.3.

La identidad anónima del mayor es deliberada y **no admite logout**: cerrar sesión generaría un UID nuevo
en el siguiente arranque y se perdería el perfil. Por eso `SignOutButton` solo se monta en pantallas del
familiar (`INFO.md §8.1`), nunca en `HomeScreen`.

### 4.2 Selección de modo (CU-01)
`OnboardingScreen` (`ConsumerWidget`) presenta las dos opciones y un acceso secundario `'Soy el
acompañante' → /companion/choice` (`onboarding_screen.dart:74-77`). `selectIndependentMode()` fija
`autonomy = independent` y limpia `linkCode`; `selectLinkedMode()` fija `autonomy = dependent` y genera
el código. Ambos persisten con `AuthRepository.saveUser` (escritura sobre el **propio** documento del
mayor, permitida por las reglas de seguridad).

### 4.3 Generación de código (CU-02)
`_genCode()` (`elder_auth_controller.dart:117-123`) genera 4 caracteres del alfabeto
`ABCDEFGHJKLMNPQRSTUVWXYZ23456789` — **excluye O, 0, I, 1** por legibilidad para el mayor, decisión
coherente con los criterios de accesibilidad de HU-3. El código se muestra a gran tamaño con
`letterSpacing: 16` (`onboarding_screen.dart:82-87`).

### 4.4 Consumo del código y vinculación (CU-03)
El familiar introduce el código en `EnterPairingCodeScreen` (campo de 4 caracteres, mayúsculas forzadas,
validación de longitud). `AuthRepository.linkCompanionToElder` (`auth_repository.dart:100-164`):

1. **Query** por `linkCode == code` y `role == elder` (las transacciones de cliente no admiten queries,
   por eso la búsqueda va fuera y el código se **revalida dentro** de la transacción leyendo el documento).
2. `runTransaction` que lee el doc del mayor y del familiar, y en una sola operación:
   - Mayor: `linkedCompanionId = companionId`, `autonomy = dependent`, `linkCode = FieldValue.delete()` (código de un solo uso).
   - Familiar: `linkedElderId = elderRef.id`, `autonomy = linked`.
   - **Desnormaliza** el contacto de emergencia: si el familiar tiene teléfono y el mayor no eligió antes un contacto manual, se copia `{name, phone, source: companion}` al doc del mayor (para que el mayor nunca tenga que leer el documento del familiar). Precedencia manual > companion.

La migración de `WriteBatch` (original, `104eeca`) a `runTransaction` (`47fd26c`, `e68b451`) fue necesaria
precisamente porque la desnormalización exige **leer** el doc del mayor antes de escribir, y un batch no lee.

**Estado final (2026-09-06, `8be3fa9` / `4cbd57f`).** Ese algoritmo sigue siendo el mismo, pero **ya no se
ejecuta en el cliente**: vive en la Cloud Function callable `validateAndLink` (`functions/index.js`), con la
precedencia del contacto extraída a `functions/pairing.js` como función pura. `linkCompanionToElder` quedó
reducida a llamar a la callable y traducir sus errores, y el identificador del familiar dejó de ser un
parámetro —el servidor lo toma de `request.auth.uid`—. Se añadieron dos comprobaciones que el cliente no
podía hacer sobre sí mismo: que quien vincula tiene `role == "companion"`, y el consumo del código dentro de
la misma transacción que lo valida. Ver §5.2 y ADR-0024.

### 4.5 Navegación y desbloqueo reactivo
`RouterNotifier.redirect` (`app_router.dart:64-109`) decide la ruta del mayor a partir de
`currentUserProvider` (dato en vivo, con prioridad) y del estado del controlador como *fallback*. El
mayor se considera "onboarded" si `autonomy == independent`, o si `autonomy == dependent && linkCode == null`.
En consecuencia, cuando el familiar completa la vinculación (borra `linkCode` en Firestore), el stream de
`currentUserProvider` emite el documento actualizado, el router recalcula y **redirige al mayor a `/home`
automáticamente**, sin que el mayor pulse nada (`INFO.md §8.5`).

---

## 5. Desviaciones y retrabajo

### 5.1 `linkedPartnerId` (especificado) vs. `linkedCompanionId` / `linkedElderId` (real)
La especificación (RF-2), `CLAUDE.md` y `test.md` describen un único campo `linkedPartnerId` en ambos
perfiles. El código real usa **dos campos asimétricos**: `linkedCompanionId` en el documento del mayor y
`linkedElderId` en el del familiar (`user_model.dart:13-14`, `auth_repository.dart:146-151`). Los tests
vigentes ya asumen la nomenclatura real (hoy, `functions/pairing.test.js` y los casos de reglas; el antiguo
`auth_repository_pairing_test.dart` se borró al migrar la vinculación al servidor, `4cbd57f`). **Acción:** la documentación
normativa (`CLAUDE.md`, RF-2) debe actualizarse a la nomenclatura de dos campos, o dejar constancia de la
divergencia en la memoria. No es un defecto funcional, sino de trazabilidad.

### 5.2 La vinculación fue client-side y contradecía las reglas de seguridad (RNF-9) — RESUELTO
Éste fue el hallazgo más relevante de la HU. Se documenta el diagnóstico tal como se hizo y, al final, cómo
se cerró:

- `firestore.rules` permite `update` sobre `users/{userId}` **solo al propietario** (`isOwner(userId)`),
  y declara la colección `/pairings/{code}` como *"written and validated server-side only"*
  (`allow read, write: if false`). Es decir, las reglas **codifican la arquitectura pretendida**:
  emparejamiento mediado por servidor de confianza, sin escrituras cross-user desde el cliente.
- Sin embargo, `linkCompanionToElder` ejecuta un `runTransaction` **de cliente** que escribe en el
  documento del **mayor** desde la sesión del **familiar** (`transaction.update(elderRef, ...)`). Bajo las
  reglas desplegadas, esa escritura sería **denegada** (`request.auth.uid != elderId`).
- El propio código lo reconoce: `auth_repository.dart:99` — `// TODO: Considerar sustituir esta función por
  una cloud function más segura.`

> ~~**UNRESOLVED — requiere decisión del autor:** reglas de seguridad y código de vinculación están
> mutuamente inconsistentes.~~ **RESUELTO el 2026-09-06.**

**Cómo se cerró.** La respuesta a la disyuntiva planteada arriba resultó ser **(b)**: las reglas describían
un diseño no implementado. Se reescribieron para modelar el código real (ADR-0025) y, al hacerlo, apareció
un coste que este diagnóstico no había visto: **las reglas de Firestore no ven las cláusulas `where` de una
consulta**, así que mientras la búsqueda del mayor por `linkCode` viviera en el cliente, `/users` tenía que
ser **enumerable por cualquier sesión autenticada**. El problema no era solo la escritura cruzada denegada;
era una lectura que obligaba a dejar abierto el directorio de usuarios.

Con eso medido, la migración dejó de ser opcional: la vinculación pasó a la callable `validateAndLink`
(ADR-0024, `8be3fa9`), el cliente dejó de consultar `/users` y las reglas pudieron cerrar `allow list`
(`b5093f0`). **RNF-9 se cumple.** El ADR que este apartado pedía existe: es el ADR-0024, y supera al
ADR-0008.

### 5.3 Eliminación de la duplicación de streams (`ElderAuthController`)
Originalmente `ElderAuthController` mantenía su propia suscripción a Firestore (`_userSubscription`) en
paralelo a `currentUserProvider` — dos escuchas al mismo documento y una violación de responsabilidad
única. En la sesión de estabilización (`c117166`, `INFO.md §8.5`) se eliminó esa suscripción: el controlador
pasó a una lectura puntual en `_init()` y el router pasó a leer de `currentUserProvider` con prioridad. El
método `checkPairingStatus()` y el botón "Continuar" sobreviven como **camino redundante** (el desbloqueo ya
ocurre solo vía router); están marcados para eliminación futura (`elder_auth_controller.dart:95-96` TODO).

### 5.4 Auditoría de navegación (M4/M5)
La navegación era el punto débil declarado del proyecto. En `INFO.md §8.2` se documentan las correcciones:
botones muertos eliminados del `AppBar` de `HomeScreen`; `AppBar` con `context.pop()` añadido a
`CompanionAuthChoiceScreen`; y `SignOutButton` como válvula de escape en `EnterPairingCodeScreen` (el router
fuerza esa pantalla al familiar no vinculado, que de otro modo quedaría atrapado si se equivocó de cuenta).

### 5.5 Bug de re-login del familiar
`INFO.md §9.4` (`c117166`): un familiar ya vinculado era enviado a `/companion/pairing` en vez de a
`/dashboard` al reiniciar. Dos causas: `signIn()` nunca promovía el estado a `linked` aunque
`linkedElderId` fuese no nulo, y `CompanionAuthController` carecía de `_init()` para rehidratar el arranque
en frío. Ambas corregidas (`companion_auth_controller.dart:15-49`).

---

## 6. Deuda técnica y cuestiones abiertas

- ~~**RNF-9 sin cumplir / reglas contra código**~~ — **cerrado el 2026-09-06** (ADR-0024/0025/0026); ver §5.2.
- **CU-02, colisión de código:** la especificación pide reintentar si el código generado ya está en uso.
  `_genCode()` no comprueba unicidad; con un espacio de 31⁴ ≈ 923 000 combinaciones y la escala de pruebas
  el riesgo es despreciable, pero el criterio no está implementado literalmente.
  > **UNRESOLVED — requiere decisión del autor:** ¿se documenta como riesgo asumido o se implementa la
  > comprobación de unicidad?
- **`checkPairingStatus()` redundante** — pendiente de eliminar junto al botón "Continuar" (§5.3).
- **Nombre del mayor fuera del onboarding:** por decisión de diseño (`INFO.md §10`) el mayor nunca escribe
  su nombre; Gemini lo aprende por *function calling* durante la conversación. No es deuda, es una
  desviación deliberada del onboarding clásico, registrada aquí por completitud.
- **`AutonomyStatus` tiene cuatro valores** (`independent, dependent, linked, none`) mientras RF-1 solo
  menciona `{independent, dependent}`. `linked` se usa para el familiar y `none` como estado sin asignar.
  Divergencia menor de modelado; conviene documentarla en el capítulo de diseño.

---

## 7. Verificación

- `functions/pairing.test.js` (10 casos, sin emulador) — precedencia del contacto de emergencia
  (manual > companion, y sin teléfono no se escribe nada) y normalización del código tecleado. Sustituye al
  antiguo `auth_repository_pairing_test.dart`, que probaba un **espejo** en Dart de una lógica que hoy
  ejecuta Node: mantenerlo habría sido verificar una copia que ya no corre nadie (`4cbd57f`).
- `firestore-tests/rules.test.js` (29 casos contra el emulador) — grupo «la vinculación ya no se hace desde
  el cliente»: un familiar autenticado no puede escribir el documento de un mayor ni con código libre, y
  `/users` no se puede enumerar (ADR-0026).
- `test/core/config/router_redirect_test.dart` — cubre las reglas de redirección de elder y companion,
  incluyendo el desbloqueo por `linkCode == null` y la prioridad de `currentUserProvider`.
- `test/core/models/user_model_test.dart` — `fromMap`/`toMap`/`copyWith` con el patrón centinela `_unset`,
  incluidos los campos nullables de vinculación.
- **Verificación manual pendiente:** el camino real de la transacción de vinculación —ya del lado del
  servidor— se comprueba con el recorrido extremo a extremo contra el emulador documentado en
  `firestore-tests/README.md`, cuyo paso «meter el código en el panel del familiar» es el que ejercita la
  callable. Pendiente de ejecutar completo con dos dispositivos.
