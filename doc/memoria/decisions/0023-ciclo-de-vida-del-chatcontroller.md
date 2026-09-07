# ADR-0023 — El documento del mayor no gobierna el ciclo de vida del `ChatController`

- **Estado:** Aceptada
- **Fecha:** 2026-09-07
- **Ámbito:** Conversación (HU-2), topología de providers.
- **Decisores:** Autor del TFG.
- **Evidencia:** `lib/features/conversation/domain/chat_controller.dart`, observación en dispositivo
  (el nombre se guardaba pero la interfaz no lo reflejaba).
- **Relacionada con:** ADR-0009 (`currentUserProvider` como *single source of truth*), ADR-0005 (Riverpod),
  ADR-0022 (escucha por turno).

---

## Contexto

`chatControllerProvider` observaba el `UserModel` completo:

```dart
final currentUser = ref.watch(currentUserProvider).valueOrNull;
```

Un `StateNotifierProvider` se **reconstruye** cuando cambia algo que observa, y reconstruirse significa
destruir el `StateNotifier` anterior y crear uno nuevo con estado de fábrica. Es decir: **cualquier** cambio
en el documento del mayor destruía la conversación en curso.

Y el turno que aprende el nombre cambia el documento. La secuencia era exactamente esta:

1. El mayor dice su nombre; Gemini llama a `guardarNombre`.
2. `updateName` escribe en Firestore.
3. `currentUserProvider` emite **dos veces** — la escritura local optimista y el eco del servidor.
4. El provider reconstruye el controlador (dos veces) y destruye el que estaba a mitad de `sendMessage`.
5. Ese `sendMessage` sigue corriendo sobre un notifier muerto: sus `state = ...` lanzan `StateError`, el
   `catch` intenta asignar `state` otra vez y vuelve a lanzar, y el error sale del turno sin recoger.
6. La pantalla se queda con el controlador nuevo, en estado inicial.

Síntoma observado: **el nombre se guardaba, pero el turno que lo guardó no llegaba nunca a la interfaz.**
La función parecía rota cuando lo roto era el ciclo de vida del objeto que la ejecutaba.

Lo mismo ocurría, sin que nadie lo hubiera notado aún, al mover un ajuste de accesibilidad: cambiar el tamaño
de letra desde la pantalla de ajustes (ADR-0021) tumbaba la conversación del mayor.

## Decisión

**El controlador solo se reconstruye si cambia la identidad del usuario**, no si cambian sus datos:

```dart
final uid = ref.watch(currentUserProvider.select((u) => u.valueOrNull?.id)) ?? ...;
```

Los datos que el controlador necesita se le **entregan en vivo**, sin recrearlo:

- El nombre llega por `ref.listen` → `controller.updateElderName(...)`, que resiembra la sesión de Gemini
  solo si el nombre cambió de verdad (`startSession` borra el hilo de la conversación; hacerlo de más le
  costaría al mayor el contexto de lo que acaba de contar).
- La cabecera de `HomeScreen` lee el nombre de `currentUserProvider` por su cuenta, como siempre.

Además, `sendMessage` comprueba `mounted` después de cada `await`, incluido dentro del `catch`: un notifier
desechado no puede volver a lanzar desde el manejador de errores.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Dejar el `watch` y protegerse solo con `mounted`** | Evita la excepción pero no el daño: el controlador sigue muriendo a mitad del turno y la respuesta del mayor se pierde igual. Trata el síntoma. |
| **`autoDispose` + `keepAlive`** | No es un problema de cuándo se libera, sino de qué lo recrea. Ortogonal. |
| **Que el controlador se suscriba él mismo a Firestore** | Prohibido por la arquitectura del proyecto (ADR-0009: los controladores no abren *streams*; los datos vienen de `currentUserProvider`) y reintroduce la duplicación de suscripción que `CLAUDE.md` §B pide eliminar. |
| **Pasar el nombre por parámetro en cada `sendMessage`** | Empuja al llamante (la UI) a saber algo que es del dominio, y la UI en este proyecto es tonta a propósito. |
| **No resembrar la sesión de Gemini al aprender el nombre** | El modelo seguiría preguntando el nombre que acaba de oír. Es justo el comportamiento que `guardarNombre` existe para evitar. |

## Justificación

`ref.watch` sobre un objeto entero es una dependencia mucho más gruesa de lo que casi nunca se pretende: ata
la vida de lo observado a la vida de todos los campos del observado. En un `StateNotifierProvider`, donde
reconstruir equivale a **perder el estado del usuario**, esa diferencia deja de ser una cuestión de
rendimiento y pasa a ser de corrección.

La regla que queda para el resto del proyecto: **en un provider que guarda estado, `watch` solo lo que, al
cambiar, deba justificar tirar ese estado a la basura.** Todo lo demás entra por `listen`.

## Consecuencias

- **Positiva:** el turno que aprende el nombre termina, se oye y se ve. Los ajustes de accesibilidad ya no
  interrumpen la conversación.
- **Positiva:** una excepción menos que puede escapar sin recoger.
- **Coste:** el nombre llega ahora por dos caminos (el `listen` del provider y `updateElderName` desde
  `sendMessage`). Se hacen idempotentes con el campo `_elderName`, pero son dos sitios que hay que mantener
  de acuerdo.
- **Pendiente:** el mismo patrón `ref.watch(currentUserProvider)` conviene auditarlo en el resto de
  providers con estado antes de las pruebas con usuarios.

## Verificación

`flutter analyze` sin incidencias y la suite existente en verde. **Sin tests nuevos** (misma decisión del
autor registrada en ADR-0021). Verificación **manual en dispositivo, pendiente**:

1. Conversación nueva → decir el nombre → la respuesta de **ese mismo turno** debe oírse y verse, y la
   cabecera debe pasar a "Hola, \<nombre\>".
2. Con una conversación en marcha, cambiar el tamaño de letra desde Ajustes → al volver, la conversación
   debe seguir donde estaba.
