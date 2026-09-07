# PENDING — Estado del proyecto y trabajo pendiente

_Fecha: 2026-07-12. Contexto: documentación TFG a mitad; HU-1→4 estabilizadas; retomando features._

---

## 1. Snapshot del estado actual

| Área | Estado |
|---|---|
| HU-1→4 (onboarding, chat de voz, vinculación, config adaptativa) | ✅ Implementadas y estabilizadas |
| `flutter analyze` | ✅ 0 issues en todo el proyecto |
| Suite de tests | ✅ **105 pasan / 0 fallan** (rojo de §2.1 arreglado el 2026-07-16; +45 tests de emergencia/ajustes) |
| Tests en git | 🔶 Suite original commiteada en `2ebf10f` (este doc lo decía al revés — corregido 2026-07-16); siguen sin commit `test.md`, `pending.md` y todo el trabajo de emergencia/ajustes del 2026-07-16 |
| Documentación TFG (`doc/tfg/`) | 🔶 ~50% (en curso, fuera del alcance de este documento) |
| Botones de la fila inferior de `HomeScreen` (emergencia, teclado, ajustes) | 🔶 Emergencia y ajustes cableados (2026-07-16, ver §3); solo queda muerto el de teclado |
| `elderPrimary` | ✅ Fijado a Canela `0xFFA0522D` (decisión de INFO.md §9 cerrada) |
| Secretos (`scripts/serviceAccountKey.json`, `.env`) | ✅ Ignorados por git (verificado) |
| Reglas de seguridad de Firestore | ❓ Sin auditar — probablemente en modo dev. **Verificar antes de cualquier despliegue real** |

---

## 2. Acciones inmediatas (antes de nuevas features)

### 2.1 ✅ Test rojo arreglado (2026-07-16)
`refreshElderData updates state with loaded elder data on success`: el test construía `DashboardController(fakeRepo, null)` — metía al elder en el fake bajo `'elder-refresh'` pero nunca pasaba ese id al controller, así que `getUser(_elderId!)` reventaba en el `!` y el catch ponía `error`. Arreglo: pasar `'elder-refresh'` como `elderId`. De paso, el test hermano se renombró a `sets error state when refreshed without a linked elderId` (su descripción decía "if getUser returns null", pero con elderId nulo `getUser` ni se llega a llamar).

**Nota para el futuro:** si `getUser` devuelve null con un elderId válido (elder borrado), el controller pone `loaded` sin datos, no `error`. Nadie lo exige aún; decidir cuando se toque el dashboard.

### 2.2 Commitear lo pendiente (actualizado 2026-07-16)
La suite original (`test/`, 4 ficheros), el borrado de `widget_test.dart` y el `.gitignore` **ya se commitearon** en `2ebf10f` — lo que decía esta sección estaba desactualizado. Sigue sin commit:
- `test.md`, `pending.md`, `emergency_call_spec.md`, `.claudeignore` (documentación, nunca commiteada).
- Toda la feature de llamada de emergencia + ajustes del 2026-07-16 (lib/, manifest, pubspec, 4 ficheros de test nuevos). Riesgo de pérdida de trabajo mientras no se commitee.

### 2.3 Botones muertos de `HomeScreen` — quedan 1 de 3 (actualizado 2026-07-16)
- ✅ **Emergencia** → cableado a `/emergency` (ver §3). Siempre visible.
- ✅ **Ajustes** → cableado a `/settings`. Visible solo si hay ≥1 fila de ajustes aplicable, calculado con la misma función pura (`visibleSettingsRows`, `core/config/settings_rows.dart`) que usa la propia pantalla.
- ❌ **"¿Teclado?"** (`home_screen.dart`, `_KeyboardButton`) — sigue muerto; tarea aparte (modo de entrada por texto). Para las pruebas con usuarios, un botón que no responde es peor que un botón ausente.

---

## 3. Llamada de emergencia — ✅ IMPLEMENTADA (2026-07-16, según `emergency_call_spec.md`)

Implementación final (corrige parte del diseño esbozado originalmente aquí):

- **Marcador, no llamada directa:** `url_launcher` + `tel:` vía `EmergencyCallService` (`core/services/emergency_call_service.dart`, interfaz + fake en tests). Sin permiso `CALL_PHONE`. `<queries>` con esquema `tel` añadido al manifest (imprescindible en Android 11+).
- **El botón se muestra SIEMPRE** — también sin contacto configurado: la pantalla `/emergency` siempre ofrece el 112, así que nunca está vacía. (Esto sustituye a la opción "ocultar el botón" que se planteó aquí antes de contemplar el 112.)
- **Contacto de emergencia:** `EmergencyContact {name, phone E.164, source: companion|manual}` en `users/{elderId}.emergencyContact`. Desnormalizado al vincular (ahora `runTransaction`, ya no `WriteBatch`: hay que leer el doc del mayor para la precedencia). **Un contacto `manual` nunca se sobrescribe en la vinculación.**
- **Registro del familiar** pide ahora nombre y teléfono (validación E.164 española compartida: `EmergencyContact.normalizeSpanishPhone`). Cuentas de familiar antiguas sin teléfono: la vinculación simplemente no escribe contacto y el mayor puede configurarlo en ajustes.
- **Ajustes del mayor:** shell `/settings` con exactamente una fila ("Contacto de emergencia") → `/settings/emergency-contact`. Visibilidad declarativa por fila (`core/config/settings_rows.dart`), compartida con el botón de `HomeScreen`.
- **Flag `intentionalBackgroundExitProvider`** (`core/providers/`) listo para el disparador de fin de sesión del §4 — hoy nadie lo lee.

**Pendiente de verificación manual:** dispositivo físico con Android 11+ (el `<queries>` no falla en todos los emuladores); comprobar que el 112 queda premarcado sin llamar.

**Limitación aceptada (documentar en la memoria del TFG):** si el familiar cambia su teléfono después de vincular, el mayor conserva el antiguo. La propagación (`onDocumentUpdated` en Cloud Function) queda como trabajo futuro; la desnormalización evita lecturas cross-user y reglas nuevas de Firestore.

---

## 4. Persistencia + resumen de conversaciones — viabilidad: **MEDIA-ALTA** (3-5 sesiones)

Prerequisito de HU-5 (análisis emocional) y de la trazabilidad del §6. Es el siguiente bloque grande natural.

**Diseño recomendado (confirma lo esbozado en PLAN.md §C):**
- Modelo: `users/{elderId}/conversations/{id}` con `{ startedAt, endedAt, summary, messageCount }`. **No persistir transcripciones crudas** — solo el resumen generado por Gemini. Esto además es un argumento fuerte de privacidad/RGPD para la memoria del TFG (minimización de datos con un colectivo vulnerable).
- **Resumen en cliente, no Cloud Function.** La transcripción vive solo en memoria durante la sesión (`List<({String role, String text})>` en `ChatController`); al cerrar sesión de conversación se hace una llamada extra a Gemini con prompt de resumen y se escribe únicamente el resultado. Una Cloud Function exigiría subir la transcripción a la nube (contradice la regla de no persistirla) o pasarla por una callable — infra extra sin beneficio claro a esta escala. Reevaluar solo si el cierre en cliente resulta poco fiable.
- **Disparador de "fin de sesión":** `AppLifecycleState.paused` + timeout de inactividad (p. ej. 10 min sin interacción). Riesgo conocido: si Android mata la app antes de completar la llamada de resumen, esa sesión se pierde — aceptable (se pierde un resumen, no datos del usuario).
- **El prompt de resumen se diseña primero** con el agente `gemini-prompt-architect`, antes de cablear nada (acordado en PLAN.md §C).
- Encaja con el patrón existente: nueva colección en `FirestorePaths`, método en repositorio, cero cambios en el flujo de voz.

**Después (HU-5):** con los resúmenes en Firestore, la clasificación de sentimiento sí es terreno natural de **Cloud Function** (`onDocumentCreated` sobre `conversations/{id}` → Gemini con JSON estricto → escribe `{valence, flags}` en el mismo doc). El plan Blaze ya está activo. El prompt de clasificación también pasa por `gemini-prompt-architect` y por el validador QA.

---

## 5. Dockerización — viabilidad: **BAJA como se planteó; útil en 2 nichos concretos**

Punto de realidad: **no hay servidor que dockerizar**. La app es un APK que se instala en el móvil y el backend es serverless (Firebase Auth/Firestore + Cloud Functions, que se despliegan con `firebase deploy`, no con contenedores). "Dockerizar el proyecto para el despliegue" no aplica en el sentido clásico.

Donde Docker **sí** aporta:

1. **Entorno de build reproducible / CI.** Una imagen con Flutter SDK + Android SDK fijados garantiza que el APK del TFG compila igual en cualquier máquina (buen punto para la memoria: reproducibilidad). Alternativa más simple y recomendada: **GitHub Actions con `subosito/flutter-action`** — mismo resultado sin mantener un Dockerfile propio. Docker solo si el tribunal/tutor valora la entrega de un entorno autocontenido.
2. **Infraestructura auxiliar local:** un `docker-compose.yml` con la **Firebase Emulator Suite** (Auth + Firestore + Functions) para desarrollar y testear sin tocar el proyecto real, y con **n8n** si se adopta el §6. Este es el uso realista de Docker en este proyecto.

**Recomendación:** prioridad baja. Si se hace algo, empezar por CI en GitHub Actions (analyze + test en cada push, ~1 sesión) y dejar el compose de emuladores+n8n para cuando el §6 se active.

---

## 6. n8n para trazabilidad del companion — viabilidad: **MEDIA** (condicionada al §4)

**Idea:** workflows que avisen al familiar sin que tenga que abrir el dashboard. Candidatos concretos:
1. Nueva conversación con flag emocional negativo → mensaje Telegram/email al familiar.
2. Inactividad del mayor > 48 h (sin conversaciones) → alerta.
3. Resumen semanal por email (nº de conversaciones, tendencia de ánimo).

**Realidad técnica:**
- Firestore **no llama webhooks** por sí mismo → se necesita igualmente una Cloud Function mínima que haga POST al webhook de n8n en cada evento. n8n no elimina las Functions; añade una capa encima.
- n8n necesita hosting siempre encendido con URL accesible: self-host en Docker sobre un VPS (~5 €/mes) o n8n cloud (de pago). Es una pieza de infraestructura nueva que mantener y que explicar en la defensa.
- Lo que aporta: conectores visuales (Telegram, Gmail, WhatsApp) sin escribir código de integración, y workflows editables sin redeployar.
- Lo que lo sustituye: una única Cloud Function con FCM (notificación push a la app del familiar) o la API de Telegram directamente — menos piezas, ya cubierto por el plan Blaze, más defendible como arquitectura.

**Recomendación:** no empezar aquí. Depende de que existan datos que notificar (§4 + HU-5). Cuando existan: implementar la notificación crítica (flag emocional) como **Cloud Function + FCM/Telegram directo**, y montar n8n solo como prototipo del resumen semanal si queda tiempo — o dejarlo documentado en el capítulo de trabajo futuro del TFG, donde luce sin coste de mantenimiento.

---

## 7. Deuda técnica registrada (heredada de INFO.md/PLAN.md)

- [ ] Ruta `'users'` hardcodeada en `current_user_provider.dart` → usar `FirestorePaths` (INFO §5).
- [x] ~~`SignOutButton` importa `authRepositoryProvider` desde `features/onboarding/data` → promocionar el provider a `core/`~~ Hecho (2026-07-16): declaración en `core/providers/auth_repository_provider.dart`; la clase `AuthRepository` sigue en `features/onboarding/data`.
- [ ] `checkPairingStatus()` y el botón "Continuar" del mayor son redundantes desde que el redirect fluye por `currentUserProvider` → eliminar ambos (INFO §8.5).
- [ ] Tests diferidos: `GeminiService`, `ChatController`, `DashboardController.updateElderName` (test.md, sección final) — esperar a que se asiente el Context Profile antes de fijarlos.
- [ ] Auditar reglas de seguridad de Firestore (lectura/escritura solo del propio doc + excepción de vinculación) — imprescindible antes de instalar la app a usuarios reales.

---

## 8. Orden de trabajo recomendado

| # | Tarea | Esfuerzo | Bloquea a |
|---|---|---|---|
| 1 | ~~Arreglar test rojo + commitear suite (§2.1, §2.2)~~ ✅ 2026-07-16 | — | — |
| 2 | ~~Botones muertos~~ → solo queda el de teclado (§2.3) | horas | pruebas con usuarios |
| 3 | ~~Llamada de emergencia (§3)~~ ✅ 2026-07-16 (falta verificación en dispositivo) | — | — |
| 4 | Persistencia + resumen de conversaciones (§4) | 3-5 sesiones | HU-5, n8n |
| 5 | HU-5: clasificación emocional + UI en dashboard | 3-5 sesiones | n8n útil |
| 6 | Context Profile del mayor (PLAN.md §D) | 3-4 sesiones | — |
| 7 | Notificaciones al familiar (Function+FCM; n8n opcional) (§6) | 2-3 sesiones | — |
| — | CI GitHub Actions (§5) | 1 sesión | paralelo, cuando convenga |

Los puntos 3 y 4 son independientes entre sí; si las pruebas con usuarios están cerca, priorizar 3 (valor de demo inmediato). Si la prioridad es la memoria del TFG, priorizar 4→5 (es la propuesta de valor central de la app).
