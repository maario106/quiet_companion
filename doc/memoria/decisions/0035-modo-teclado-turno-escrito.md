# ADR-0035 — Modo teclado: el turno escrito sigue el camino del hablado y su respuesta se enseña sin leerla

- **Estado:** Aceptada — implementada el 2026-10-06 en la rama `feat/modo-teclado`, sin compilar ni verificar en
  dispositivo
- **Fecha:** 2026-10-06
- **Ámbito:** HU-2 (conversación por voz) y accesibilidad del mayor (HU-3). Cierra `pending.md` §2.3 (el botón
  "¿Teclado?" inerte) y la fila "Modo de entrada por teclado" de `scope.md`.
- **Decisores:** Autor del TFG.
- **Evidencia:** petición del autor del 2026-10-06 (*"implementar la opción de escribir por teclado en la
  aplicación"*); `pending.md` §2.3 (*"un botón que no responde es peor que un botón ausente"*);
  `home_screen.dart` en `ab55d2d` (`_KeyboardButton` con `onPressed: () {}` y un `TextEditingController`
  declarado sin uso); `chat_controller.dart` (`sendMessage` ya era independiente del reconocedor).
  Implementación: `features/conversation/domain/chat_state.dart`, `chat_controller.dart`,
  `presentation/home_screen.dart`; tests en `test/features/conversation/` y dobles movidos a `test/helpers/`.
  Commits: SHA pendiente.
- **Relacionada con:** ADR-0022 (escucha por turnos), ADR-0023 (ciclo de vida del `ChatController`), ADR-0028
  (frontera de la conversación), ADR-0029 (análisis al cierre), ADR-0013 y ADR-0021 (accesibilidad
  configurada).

---

## Contexto

La voz es el canal principal del mayor, pero hay momentos en que no quiere o no puede hablar: una sala de
espera, de noche con alguien durmiendo, ronquera o una dificultad del habla, o un reconocedor que falla. Este
último caso no es teórico: la escucha por turnos (ADR-0022) ha necesitado dos arreglos y sigue siendo la pieza
sin verificar del recorrido de una conversación.

El botón "¿Teclado?" está en la fila inferior de Inicio desde el rediseño de la pantalla (`INFO.md`), pero no
hace nada. El controlador ya separa la entrada de la conversación: `sendMessage(text)` no sabe de dónde viene
el texto, y `_submit` es solo el camino de la voz. Un turno escrito no necesita un recorrido nuevo.

Quedan tres preguntas:

1. ¿Un turno escrito cuenta igual que uno hablado para el análisis, la memoria y el mínimo de tres turnos?
2. ¿La respuesta a un turno escrito se lee en voz alta?
3. ¿Dónde vive el modo y cuánto dura?

## Decisión

1. **Un solo camino.** El turno escrito entra por `sendMessage`, como el hablado: la misma sesión de Gemini,
   el mismo búfer en memoria, la misma frontera de conversación. Cuenta para el mínimo de tres turnos y llega a
   `closeConversation` al cierre. El turno no lleva marca de canal: el análisis trata de lo que dice el mayor,
   no de cómo lo dice. El texto sigue la regla de ADR-0028 y ADR-0029: vive en memoria y solo sale del teléfono
   en el cierre. El borrador del campo tampoco se guarda en ningún sitio.
2. **La respuesta a un turno escrito se enseña y no se lee sola.** La salida sigue a la entrada. Un botón
   "Escuchar" la lee cuando el mayor lo pide y, mientras suena, se convierte en "Parar". El turno hablado no
   cambia: su respuesta se sigue leyendo.
3. **El modo vive en `ChatState.inputMode`** (voz de partida) y no en el widget. Así sobrevive a ir a Ajustes
   o a Emergencia y volver, y el controlador puede actuar al cambiarlo: pasar al teclado con el micrófono
   abierto **descarta** lo que se estaba oyendo en vez de enviarlo. No se guarda entre arranques: cada vez que
   se abre la app empieza con la voz.
4. **Cómo se usa en Inicio:**
   - "¿Teclado?" cambia el micrófono por un campo de texto y un botón "Enviar" de 80 × 80. El campo toma el
     foco al aparecer, así que el teclado del sistema se abre sin otro toque. El mismo botón de la fila pasa a
     decir "¿Hablar?" para volver.
   - Solo se puede enviar si no hay otro turno esperando respuesta. El predicado está en un solo sitio
     (`ChatState.acceptsTypedTurn`) y lo usan la pantalla y el controlador. Con la voz de la app sonando sí se
     puede: el turno nuevo la calla.
   - Al enviar, el campo se vacía y el teclado del sistema se cierra para que la respuesta se lea a pantalla
     completa. Si el turno falla, el texto vuelve al campo y no hay que escribirlo otra vez.
   - Con el teclado del sistema abierto se apartan "Escuchar" y "Mi semana". La fila de emergencia y ajustes
     se queda.
   - Letra a `fontMedium × textSizeMultiplier` (24 sp de base) y toques de al menos 80 px. Sin texto, "Enviar"
     se ve apagado: no es un botón que no responde.
5. **Orden de los turnos (`_epoch`).** Una voz cortada termina tarde, cuando ya ha empezado otra cosa. Cada
   turno, escucha o lectura toma un número, y la vuelta a reposo tras hablar solo se aplica si lo que la lanzó
   sigue siendo lo último. Sin esto, una respuesta cortada por un turno escrito devolvía la pantalla a reposo
   con el turno nuevo en vuelo, y eso permitía un segundo envío simultáneo a la misma sesión del modelo.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Leer siempre la respuesta, también la de un turno escrito** | Una sola regla y menos código, pero contradice el motivo más común para escribir: estar donde no se quiere que la app hable. A quien escribe porque oye mal tampoco le aporta. Quien quiera oírla tiene "Escuchar". |
| **No leer nunca en modo teclado, sin "Escuchar"** | Deja fuera al mayor con baja visión que escribe por una dificultad del habla y necesita oír la respuesta. |
| **Una pantalla aparte para escribir** | Otra navegación que aprender, y la respuesta lejos de donde se escribe. Inicio ya tiene el sitio. |
| **Guardar el modo como preferencia en Firestore** | `UserPreferences` es solo accesibilidad configurada (ADR-0013, ADR-0021), y el modo depende del momento más que de la persona. Si en las pruebas con usuarios alguien escribe siempre, se puede añadir como fila de Ajustes. |
| **Marcar en el búfer si cada turno fue hablado o escrito** | No le aporta nada al análisis y obligaría a cambiar `ClosedConversation`, la callable y sus tests. |
| **Bloquear el envío mientras suena la voz** | Más sencillo, sin `_epoch`, pero el mayor vería un "Enviar" apagado sin saber por qué. |
| **Enviar lo oído al pasar al teclado con el micrófono abierto** | Mandaría un texto que el mayor no ha confirmado y que quizá ni ha visto. |

## Justificación

El coste de añadir el canal es casi solo de presentación, porque la conversación ya no dependía del
reconocedor. Lo que de verdad había que decidir era si la app habla cuando el mayor no habla. La respuesta es
que no, salvo que lo pida. Así el modo teclado sirve para lo que se pide: conversar sin hacer ruido y sin
depender del micrófono.

## Consecuencias

- **Positiva:** desaparece el último botón inerte de Inicio, y hay una forma de conversar cuando la voz falla o
  no se quiere usar.
- **Positiva:** el análisis y la memoria reciben las conversaciones escritas sin tocar el servidor.
- **Coste:** el teclado del sistema ocupa media pantalla, y con letra grande queda poco sitio para la
  respuesta mientras se escribe. Por eso se apartan "Escuchar" y "Mi semana".
- **Coste:** el modo se pierde al reiniciar la app.
- **Neutra:** la instrucción de sistema de Gemini sigue diciendo que las respuestas *"van a ser leídas por
  voz"*. Pedir respuestas breves sirve igual para los dos modos.

## Verificación

- `chat_controller_test.dart`, grupo *modo teclado (ADR-0035)*: el turno escrito no se lee, cuenta para el
  análisis, un fallo devuelve `false`, no hay segundo envío con un turno en vuelo, escribir con la voz sonando
  la calla sin pisar el turno, "Escuchar" y "Parar", y pasar al teclado con el micrófono abierto descarta la
  escucha.
- `home_screen_test.dart`: el cambio de modo, "Enviar" apagado sin texto, el envío vacía el campo y enseña la
  respuesta sin leerla, un fallo devuelve el texto al campo, y "Escuchar" lee.
- Manual en el móvil:
  1. "¿Teclado?" abre el teclado. Escribir *"Hola, me llamo …"* y pulsar "Enviar": el teclado se cierra, sale
     "Pensando..." y la respuesta aparece sin oírse.
  2. "Escuchar" la lee y el botón pasa a "Parar". "Parar" la corta.
  3. Con el micrófono escuchando, pulsar "¿Teclado?": el micrófono se cierra y no se envía nada.
  4. Tres turnos escritos y salir con el botón de inicio del móvil: aparece un documento en `conversations`
     con `elderTurns: 3` y `status: analyzed` (con consentimiento).
  5. Con la letra en "La más grande", escribir con el teclado abierto: nada se desborda (sin franjas amarillas
     y negras).
  6. En modo avión, enviar: sale el mensaje de error y el texto vuelve al campo.
