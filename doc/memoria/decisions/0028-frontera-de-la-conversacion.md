# ADR-0028 — Una conversación termina tras un silencio largo o al salir de la app, y es la unidad de todo lo que se guarda

- **Estado:** Aceptada — pendiente de implementación
- **Fecha:** 2026-09-26
- **Ámbito:** Conversación (HU-2). Requisito previo de HU-5 (memoria, RF-7) y HU-6 (ánimo, RF-8).
- **Decisores:** Autor del TFG.
- **Evidencia:** `lib/features/conversation/domain/chat_controller.dart` (la sesión de Gemini se siembra solo
  en el constructor y al cambiar el nombre; no existe la noción de conversación),
  `lib/core/providers/intentional_background_exit_provider.dart` (*"Consumidor previsto: el disparador de fin
  de sesión de pending.md §4 […] Hoy nadie lo lee"*), `pending.md` §4, ADR-0015 (disparador: `paused` +
  inactividad). Commits: pendientes.
- **Relacionada con:** ADR-0022 (turno de escucha), ADR-0023 (el controlador sobrevive a los cambios del
  documento), ADR-0029 (análisis al cierre), ADR-0032 (memoria), ADR-0034 (plazos configurables), ADR-0030
  (consentimiento).

---

## Contexto

Hoy la app no sabe qué es "una conversación". Hay una sesión de Gemini que vive lo que vive el
`ChatController`: si el mayor deja el móvil encendido en la mesilla, la misma sesión puede abarcar la charla de
la mañana y la de la noche, con el historial creciendo sin límite. Como el `ChatSession` reenvía el historial
completo en cada turno, también crece sin límite lo que cuesta cada turno.

HU-5 y HU-6 cuelgan todo de esa unidad: el resumen, el ánimo, lo que se aprende y lo que ve el familiar son
*por conversación*. Elegirla mal estropea todo lo que va detrás:

- **Demasiado corta:** resúmenes fragmentados, ánimo calculado sobre dos frases, más llamadas de análisis.
- **Demasiado larga:** mezcla estados de ánimo de momentos distintos y el análisis no llega nunca, porque la
  conversación no termina.

## Decisión

1. **Una conversación empieza** con el primer turno del mayor tras el arranque de la app o tras el cierre de
   la anterior, y **termina** con lo primero que ocurra de estas dos cosas:
   - **Inactividad** (`endReason: 'inactivity'`): *N* minutos sin turnos, con *N* = 5 por defecto,
     configurable (ADR-0034). Se cuenta desde que **termina de hablar el asistente**, no desde que habló el
     mayor: si no, una respuesta larga se come la ventana.
   - **Salida a segundo plano** (`endReason: 'background'`): `AppLifecycleState.paused`, **salvo** que
     `intentionalBackgroundExitProvider` esté activo, que es exactamente la salida al marcador de emergencia.
     En ese caso la conversación sigue; si al volver ya ha pasado el plazo de inactividad, se cierra entonces.
2. **Al cerrarse**, el controlador:
   - envía los turnos acumulados a `closeConversation` (ADR-0029), si hay consentimiento (ADR-0030). El envío
     no bloquea nada: el mayor no espera ni ve nada;
   - vacía el búfer;
   - deja que la **siguiente** conversación arranque con una sesión de Gemini **nueva**, sembrada con la
     memoria actualizada (ADR-0032). La sesión se crea en el primer turno de la conversación siguiente, no en
     el cierre, para que le dé tiempo a llegar a la memoria que acaba de escribir el análisis.

   Conversación y sesión del modelo pasan a coincidir.
3. **Umbral mínimo.** Si el mayor ha hablado menos de **3 turnos**, se envía solo la actividad (inicio, fin,
   número de turnos), **sin texto**. Una conversación de "hola, adiós" no tiene ánimo que medir, ensuciaría la
   tendencia y no justifica sacar texto del dispositivo.
4. **El búfer vive en memoria**, en el `ChatController`: una lista de turnos `(rol, texto, hora)`. Nunca en
   disco. Funciona porque, desde ADR-0023, el controlador ya no muere cuando cambia el documento del mayor.
5. **Solo se acumulan turnos completos.** Las respuestas de error ("Upss, ha habido un problema con la
   conexión") no son conversación y sesgarían el análisis hacia lo negativo.
6. **No hay botón de "terminar conversación".**

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Botón explícito de "terminar"** | Una decisión más para el mayor, y la gente no "termina" una charla con quien le acompaña. El botón no se pulsaría y las conversaciones no se cerrarían nunca. |
| **Una conversación por apertura de la app** (cerrar solo al salir) | El caso de uso real incluye el móvil fijo en un soporte, siempre abierto. La conversación no terminaría nunca. |
| **Solo inactividad, sin ciclo de vida** | Si Android mata la app en segundo plano, se pierde la conversación sin haberlo intentado siquiera. |
| **Un margen al pasar a segundo plano** (cerrar tras, p. ej., 60 s fuera) | Más amable con un cambio de app momentáneo, pero Android puede congelar o matar el proceso durante el margen, y el envío no llegaría a empezar. Se prefiere iniciar el envío mientras el proceso sigue vivo. |
| **Guardar el búfer en disco para sobrevivir a la muerte del proceso** | Deja la transcripción cruda en reposo en el dispositivo, justo lo que ADR-0015 prohibió, y añade una dependencia. Se acepta perder esa conversación. |
| **Una conversación por día natural** | Agregar sería trivial, pero mezcla momentos y emociones distintos en un solo análisis. |
| **Analizar cada turno** | Ver ADR-0029: latencia en cada turno, ruido y *N* llamadas. |

## Justificación

La frontera se elige para que el análisis tenga sentido y el mayor no note nada. La inactividad capta el final
natural de una charla sin pedir un gesto. El ciclo de vida capta el caso en que el sistema puede matar la app,
y es el último momento en que el envío tiene opciones de salir. El umbral de turnos es minimización de datos:
si no se va a analizar, el texto no sale del móvil.

Que la sesión del modelo coincida con la conversación arregla además, de paso, el crecimiento del historial
(y de su coste) en una app que puede estar abierta días enteros.

## Consecuencias

- **Positiva:** una unidad clara para el análisis, el panel y "Mi semana".
- **Positiva:** el coste por turno queda acotado. Cada conversación empieza con historial vacío más la
  memoria, no con el de toda la semana.
- **Positiva:** `intentionalBackgroundExitProvider` tiene por fin el consumidor para el que se creó.
- **Coste:** si Android mata la app antes de completar la llamada, esa conversación se pierde (aceptado ya en
  ADR-0015).
- **Coste:** un cambio de app de pocos segundos parte una conversación en dos.
- **Coste:** tras el cierre, el modelo pierde el hilo literal de lo hablado. Lo compensa, en parte, la memoria
  (resúmenes recientes, ADR-0032).

## Verificación

Criterio de cierre. Automático, `ChatController` con dobles (`FakeGeminiService`, un temporizador inyectable,
sin red):

- el temporizador vence → se envía una vez, con los turnos y `endReason: 'inactivity'`;
- `paused` sin salida intencional → se envía con `endReason: 'background'`;
- `paused` con `intentionalBackgroundExitProvider` activo → no se envía;
- menos de 3 turnos del mayor → se envía sin texto;
- las respuestas de error no entran en el búfer;
- tras el cierre, el siguiente turno siembra una sesión nueva.

Manual, contra el emulador: hablar tres turnos y esperar *N* minutos → aparece el documento en
`conversations`; hablar y pulsar el botón de inicio de Android → aparece; hablar, abrir el marcador de
emergencia y volver → no aparece y la conversación sigue.
