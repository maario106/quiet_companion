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

- **Duplicación de stream de usuario** — `ElderAuthController` mantiene su propio `_userSubscription` a Firestore además de `currentUserProvider`. Dos escuchas al mismo documento. Hay que eliminar `_userSubscription` del controlador y hacer que el router consuma `currentUserProvider` directamente. Bloqueante antes de Milestone 3.

- **Campo `_userSubscription` declarado `late`** en `elder_auth_controller.dart` — si `_init()` lanzara antes de asignarlo, habría un `LateInitializationError`. Usar `StreamSubscription<...>? _userSubscription` (nullable) es más seguro. No es bloqueante ahora mismo.

- **`withOpacity` deprecado** en `home_screen.dart:156` — pre-existente, no introducido en esta sesión. La alternativa es `AppTheme.primaryColor.withValues(alpha: 0.1)` (Flutter ≥3.27) o `Color.fromRGBO(...)`.

- **`print` en producción** en `home_screen.dart:183` — pre-existente. Debe reemplazarse por un logger o eliminarse antes de publicar.

- **Saludo hardcodeado a `'¡Hola!'`** (`home_screen.dart:46`) — `UserModel` no tiene campo `name` todavía. El TODO está anotado en el código.

- **Ruta de Firestore `'users'` hardcodeada** en `current_user_provider.dart:25` — debería ser una constante compartida con `auth_repository.dart` (que también la hardcodea). Riesgo de desincronización si se renombra la colección.

- **`GeminiService` y `SpeechService` instanciados directamente** dentro del closure de `chatControllerProvider` (`chat_controller.dart:86-87`) — pre-existente, no introducido en esta sesión. Ambas clases deberían exponerse como providers propios para cumplir la regla de DI.

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

Milestone 3 (`PLAN.md`, línea 52) — Auto-login para el mayor — pero **antes** hay que eliminar la duplicación de streams descrita en la sección 5 (punto 1); de lo contrario el router y `currentUserProvider` competirán por el mismo documento Firestore y pueden producir condiciones de carrera durante el redirect.
