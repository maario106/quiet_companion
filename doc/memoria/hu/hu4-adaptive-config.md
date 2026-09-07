# HU-4 — Configuración Adaptativa

- **Estado:** Completada en la **ruta remota** (familiar → mayor); la **ruta local** del mayor independiente
  está **sin implementar** para volumen/velocidad/tamaño (ver §5.1).
- **Ámbito:** Implementado (dashboard remoto + propagación). Autoconfiguración local del mayor: no
  implementada.
- **Requisitos cubiertos:** RF-6 (propagación remota, completo); RF-5 (configuración de parámetros —
  **parcial**: solo el camino del familiar). Materializa ADR-0013 (configuración explícita, no por IA).
- **Casos de uso:** CU-06 (ajuste remoto por el familiar) — implementado; CU-05 (ajuste local por el mayor
  independiente) — **no implementado**.
- **Evidencia (commits):** `104eeca` (dashboard, controlador y estado), `96cfd57` (Milestones 1 y 2:
  `currentUserProvider`, `ttsServiceProvider`, escalado de fuente), `c117166` (estabilización, DI, router),
  `708d71a` (edición del nombre del mayor desde el dashboard), `895c921` (fix del test `refreshElderData`).
- **Evidencia (código):** `lib/features/dashboard/domain/{dashboard_controller,dashboard_state}.dart`,
  `lib/features/dashboard/presentation/dashboard_screen.dart`, `lib/core/providers/current_user_provider.dart`,
  `lib/core/services/tts_service.dart` (`ttsServiceProvider`), `lib/features/conversation/presentation/
  home_screen.dart` (escalado por `textSizeMultiplier`), `lib/core/models/user_preferences.dart`.
- **Evidencia (fuentes documentales):** `INFO.md` (registro de sesión de HU-4, §1-10), `hu4-plan.md`
  (Milestones 1-3), `doc/pdfs/Solución Propuesta - Historias de Usuario.pdf` (HU-4, criterios), TFG cap. 4
  (RF-5, RF-6, CU-05, CU-06). Decisiones: ADR-0009, ADR-0010, ADR-0013.

---

## 1. Qué entregó la HU

HU-4 permite que las preferencias de accesibilidad del mayor (volumen de voz, velocidad de habla y tamaño de
texto) se ajusten desde fuera de su dispositivo y **se apliquen en caliente**. El familiar abre su panel,
mueve un deslizador y, al soltarlo, el cambio se persiste en la nube y el móvil del mayor lo recibe en menos
de un segundo: la letra crece o se reduce en pantalla y la siguiente locución suena con el volumen y la
velocidad nuevos, sin que el mayor toque nada ni reinicie la app (`INFO.md` §1).

Es la HU que ejercita toda la columna vertebral reactiva del sistema: el bucle
**dashboard → Firestore → `currentUserProvider` → (TtsService | HomeScreen)**.

---

## 2. Criterios de aceptación (PDF Solución, HU-4)

| # | Criterio de aceptación | Estado | Evidencia |
|---|---|---|---|
| CA-1 | Si el mayor es independiente, accede a una pantalla de ajustes simplificada **en su propio dispositivo** (botones grandes / sliders gruesos) para volumen, voz y tamaño. | **No cumplido** | `settings_rows.dart` tiene una única fila (contacto de emergencia); no hay UI local para volumen/velocidad/tamaño (§5.1). |
| CA-2 | Si hay un familiar vinculado, accede a los mismos ajustes desde su interfaz remota, y los cambios se aplican automáticamente en el móvil del mayor en su próxima interacción. | **Cumplido** | `dashboard_screen.dart` (deslizadores) → `dashboard_controller.dart` → `currentUserProvider` → `ttsServiceProvider` / `home_screen.dart`. Verificado en 2 dispositivos (`INFO.md` §6). |

---

## 3. Trazabilidad

| Artefacto | Contenido | Estado |
|---|---|---|
| RF-5 | Configurar volumen, velocidad y tamaño; acceso según modo (independiente → propio dispositivo; vinculado → familiar). | **Parcial**: solo el camino del familiar. El del mayor independiente no existe. |
| RF-6 | Propagación remota en tiempo real, sin reinicio ni intervención del mayor. | Implementado. |
| CU-05 | Ajustar preferencias (modo independiente). | **No implementado.** |
| CU-06 | Ajustar preferencias (modo remoto, familiar). | Implementado, con rollback ante error (flujo alternativo 4a). |

---

## 4. Implementación real

### 4.1 Camino de escritura del dashboard (CU-06)
Los deslizadores del familiar escriben en `onChangeEnd` (una sola escritura por gesto; `onChanged` solo
mueve el valor visual local) con **actualización optimista y rollback honesto** ante fallo de `saveUser`
(ADR-0010). `_SettingSlider` reconcilia el valor visual en `didUpdateWidget` cuando no se está arrastrando,
para absorber tanto el rollback como un cambio externo (`INFO.md` §2-3).

### 4.2 Propagación por *single source of truth* (RF-6)
`currentUserProvider` (`StreamProvider<UserModel?>` sobre `users/{uid}`) es el único punto de escucha del
documento del mayor (ADR-0009). Cuando Firestore emite el cambio de preferencias, Riverpod reconstruye solo
a sus observadores. No hay *polling* ni reinicio.

### 4.3 TTS reactivo a las preferencias
`ttsServiceProvider` usa `ref.listen(currentUserProvider, ...)` para aplicar `volume` y `speechRate` al
motor TTS en cuanto cambian (`INFO.md` §2.2). `ChatController` no sabe nada de preferencias: recibe el
servicio por DI. **Limitación documentada:** `flutter_tts` no permite cambiar volumen/velocidad de una frase
ya en curso en Android; los cambios surten efecto en la **siguiente** locución (`INFO.md` §4). No es un bug.

### 4.4 Escalado de tipografía en caliente
`HomeScreen` lee `textSizeMultiplier` de `currentUserProvider` y multiplica cada tamaño de fuente
(`AppTheme.font* * textScale`), de modo que la letra del mayor cambia en tiempo real al mover el deslizador
del familiar (`INFO.md` §2.3). El mismo patrón se aplica en `SettingsScreen`.

### 4.5 Edición del nombre del mayor (extensión, `708d71a`)
El dashboard incorpora `_ElderNameCard`: el familiar ve y corrige el nombre que Gemini aprendió por voz.
`DashboardController.updateElderName` usa el mismo patrón optimista + rollback que las preferencias
(`INFO.md` §10). El mayor nunca teclea su nombre (decisión de diseño *voice-first*).

---

## 5. Desviaciones y retrabajo

### 5.1 La autoconfiguración del mayor independiente (CA-1 / CU-05) no está implementada
La especificación describe dos caminos de configuración; solo el remoto (familiar) existe. Un mayor
**independiente** no dispone hoy de ninguna pantalla para cambiar su volumen, velocidad o tamaño de texto:
`settings_rows.dart` contiene una sola fila (contacto de emergencia). El diseño pedía además **botones
grandes de incremento/decremento** ("más/menos"), no deslizadores, por accesibilidad (ADR-0013, hu3 §5.2) —
el dashboard del familiar sí usa deslizadores porque es UI de familiar, no del mayor.
> **UNRESOLVED — requiere decisión del autor:** ¿se implementa la pantalla local de ajustes del mayor
> independiente (nuevas filas *más/menos* en `settings_rows.dart` + subpantallas), cerrando CU-05, o se
> documenta como diferido? La arquitectura declarativa de las filas hace que añadirlo sea de bajo coste.

### 5.2 El bucle de revisión del Milestone 2.5 (deuda de DI descubierta a mitad)
HU-4 no fue lineal: al auditar el Milestone 2, una revisión de arquitectura destapó **dos violaciones
preexistentes** que se corrigieron a mitad del hito — `GeminiService`/`SpeechService` se instanciaban dentro
del provider del `ChatController` (antipatrón de DI), y `dashboard_controller.dart` importaba de
`features/onboarding` (acoplamiento horizontal). Ambas se resolvieron migrando a providers y leyendo
`linkedElderId` desde `currentUserProvider` (`hu4-plan.md` §2.5, `INFO.md` §8.3-8.4). Es evidencia de proceso.

### 5.3 Limitación de `flutter_tts` (aplicación en la siguiente locución)
Ver §4.3: aceptada y documentada, no es defecto.

### 5.4 Bug del test `refreshElderData` (fase 4)
`DashboardController(fakeRepo, null)` no pasaba el `elderId` al controlador, así que `getUser(_elderId!)`
reventaba en el `!` y el catch dejaba estado `error`. Corregido pasando el id correcto (`895c921`,
`pending.md` §2.1). Nota registrada: si `getUser` devuelve null con un `elderId` válido (mayor borrado), el
controlador deja `loaded` sin datos, no `error` — nadie lo exige aún.

---

## 6. Deuda técnica y cuestiones abiertas

- **CU-05 sin implementar** — ver §5.1 (bloquea el criterio CA-1 de HU-4).
- **Ruta `'users'` hardcodeada** en `current_user_provider.dart` en lugar de `FirestorePaths` (`pending.md` §7).
- **Tests diferidos:** `GeminiService`, `ChatController`, `DashboardController.updateElderName` — esperar a
  que se asiente el perfil de contexto (`test.md`, `pending.md` §7).
- **Perfil de contexto del mayor** (aprendizaje progresivo, `hu4-plan.md` §D) — trabajo futuro; ver
  `scope.md` (tabla 3).

---

## 7. Verificación

- `test/features/dashboard/dashboard_controller_test.dart` — *happy path* (una sola llamada a `saveUser`,
  update optimista antes del `await`), rollback ante error (revierte `linkedElder` + fija `errorMessage`),
  no-op cuando no hay elder vinculado (`test.md` §2).
- `test/core/config/router_redirect_test.dart` — el dashboard lee `linkedElderId` de `currentUserProvider`
  (no de `companionAuthControllerProvider`), confirmando el desacoplamiento del §5.2.
- **Verificación manual** (`INFO.md` §6): dos dispositivos; mover el deslizador de tamaño → la letra del
  mayor cambia en ~1 s; velocidad al mínimo → la voz suena más lenta; sin wifi → el deslizador vuelve atrás
  con banner de error (rollback).
