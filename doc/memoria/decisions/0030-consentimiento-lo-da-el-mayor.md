# ADR-0030 — Consentimiento: lo da el propio mayor, con un gesto explícito, una sola vez y al empezar; el familiar no puede darlo por él

- **Estado:** Propuesta — pendiente de confirmación del autor (ver `UNRESOLVED` al final)
- **Fecha:** 2026-09-26
- **Ámbito:** Privacidad del tratamiento conversacional (RNF-10), requisito previo de HU-5 y HU-6. Responde
  a la cuestión abierta de ADR-0016.
- **Decisores:** Autor del TFG.
- **Evidencia:** ADR-0016 (`UNRESOLVED`: alcance del *opt-in*, quién consiente, recogida y revocación); TFG
  cap. 4, RNF-10 (*"consentimiento explícito (opt-in) desactivado por defecto, y será controlable por el mayor
  o por el familiar gestor"*); RGPD arts. 4.11, 7, 9.1, 9.2.a y 17.1.b, considerando 32; conversación de diseño
  con el autor del 2026-09-26. Commits: pendientes.
- **Relacionada con:** ADR-0016, ADR-0029 (qué se analiza), ADR-0031 (qué ve el familiar), ADR-0034
  (plazos), ADR-0007 (autonomía como configuración), ADR-0013 (configuración explícita, nunca inferida).

---

## Contexto

ADR-0016 dejó tres preguntas sin cerrar: si el *opt-in* cubre el envío de la transcripción al análisis, quién
consiente y cómo se recoge y se retira. Al retomarlas, el autor planteó dos más:

1. ¿Basta con **un aviso**, o hace falta **una casilla**?
2. En el modo vinculado, ¿puede consentir **el familiar**, avisando al mayor al elegir ese modo? El propio
   autor expresó la duda de que eso fuera **paternalista**.

El marco que decide:

- **Un aviso no es consentimiento.** El consentimiento es una *"manifestación de voluntad libre, específica,
  informada e inequívoca […] ya sea mediante una declaración o una clara acción afirmativa"* (art. 4.11). El
  silencio, las casillas premarcadas o la inacción no lo son (considerando 32).
- **El análisis toca categorías especiales.** Inferir el estado de ánimo y registrar molestias físicas puede
  revelar datos de salud (art. 9.1). Para esta app, la base realista es el **consentimiento explícito** (art.
  9.2.a).
- **Hay que poder demostrarlo** (art. 7.1), y retirarlo tiene que ser tan fácil como darlo (art. 7.3).
- **El titular de los datos es el mayor.** En esta app, "vinculado" o "dependiente" significa *"le ayudan con
  la tecnología"*, no una medida de apoyo jurídica. Vincularse no convierte al familiar en representante
  legal del mayor.

## Decisión

1. **Hace falta un gesto explícito; un aviso no basta.** No tiene por qué ser una casilla: una pantalla
   propia, con una pregunta clara y dos botones grandes (**"Sí, quiero"** / **"Ahora no"**), es una acción
   afirmativa inequívoca. Además cumple las reglas de interacción del mayor, que una casilla de 24 px
   incumpliría (área mínima de 80 × 80, RNF-2).
2. **Consiente siempre el mayor, en su dispositivo.** El familiar no puede concederlo, ni desde su panel ni en
   nombre del mayor.
3. **Se pregunta una vez, al empezar**, la primera vez que el mayor llega a su pantalla principal:
   - **mayor independiente:** justo después de elegir el modo;
   - **mayor vinculado:** justo después de completarse la vinculación. Es el momento que el autor señaló, y
     tiene una ventaja: suele ser **presencial**, porque el familiar lee el código en la pantalla del mayor.
     El familiar puede explicarlo en persona. **Acompaña; no decide.** Esa es la respuesta a la preocupación
     por el paternalismo;
   - **mayores que ya usaban la app** antes de esta función: una vez, en el siguiente arranque.

   Se implementa como un paso del enrutador: un mayor ya dado de alta cuyo `conversationConsent` no existe
   (nunca ha respondido) va a `/consent`. "Ahora no" también se registra, para no volver a preguntar.
4. **Qué se le dice** (texto versionado, en lenguaje llano, con un botón "Escuchar" que lo lee en voz alta, y
   un enlace "Saber más" a una pantalla con el detalle, como propuso el autor):
   - que se guarda **un resumen breve** de cada conversación y **cómo se ha sentido**, nunca lo que dice
     palabra por palabra;
   - que, para hacerlo, lo hablado **se envía a Google para analizarse y no se guarda**;
   - que el asistente **recordará** cosas que le cuente;
   - si está vinculado, **qué verá su familiar**, por su nombre. Por defecto, el nivel completo (ADR-0031),
     que puede cambiar;
   - **cuánto tiempo** se guarda (ADR-0034);
   - que puede **quitarlo cuando quiera** en Ajustes, y que entonces **se borra todo**.
5. **Un solo consentimiento** para el análisis y la memoria, que benefician al propio mayor. La finalidad de
   informar al familiar tiene su propio control, el nivel de ADR-0031, que el mayor puede poner en "Nada".
6. **Registro:** `conversationConsent: { granted, answeredAt, textVersion }` en el documento del mayor. Lo
   escribe una callable, `setConversationConsent`, con la hora del servidor como prueba del consentimiento. Las
   reglas impiden que ningún cliente lo escriba directamente, tampoco el propio mayor: la regla del dueño pasa
   a excluir ese campo.
7. **Retirada:** en Ajustes, fila "Guardar mis conversaciones", con la misma facilidad con que se dio (un toque
   y una confirmación). Retirarlo **detiene el análisis y borra todo lo guardado** (`conversations`,
   `conversationContents` y `memory`). Lo hace la misma callable, porque el cliente no puede borrar lo que
   escribió el servidor.
8. **Desactivado por defecto** (RNF-10): nada se analiza ni se guarda hasta el "Sí".
9. **El familiar ve el estado, no lo cambia.** Su panel muestra "Sin activar", con una indicación para
   hablarlo con el mayor en persona, o "Activado desde el …".

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Aviso informativo, sin acción** | No es consentimiento (art. 4.11, considerando 32), e insuficiente para datos del art. 9. |
| **Casilla de verificación** | Válida jurídicamente, pero pequeña para esta población e incumple el área táctil mínima. Un botón grande con la pregunta es la misma acción afirmativa. |
| **Que consienta el familiar en modo vinculado** (propuesta inicial del autor) | El familiar no es representante legal, así que el consentimiento sería inválido. Además es paternalista, que es justo lo que preocupaba al autor. |
| **Consentimiento por voz, a través del asistente** | Un "sí" transcrito por el reconocedor e interpretado por un LLM es ambiguo y difícil de demostrar (art. 7.1). |
| **Preguntar en el onboarding, antes de elegir modo** | Todavía no se sabe si habrá familiar ni quién será. La pregunta sería abstracta y recargaría el primer contacto. |
| **Solicitud remota: el familiar la pide y el mayor confirma en su móvil** | Respetuosa y viable, pero añade estado y reglas. Se aplaza: la vinculación ya ofrece un momento presencial natural. Queda como trabajo futuro. |
| **Un consentimiento por finalidad** (análisis, memoria, familiar) | Más específico, pero son tres preguntas para el mayor. La granularidad que importa, qué ve el familiar, la cubre ADR-0031. |
| **Conservar los datos tras la retirada hasta que caduquen** | Retirado el consentimiento, no queda base jurídica para seguir conservando datos del art. 9 (art. 17.1.b). Y el mayor no entendería que "apagar" no borre. |

## Justificación

La pregunta del autor —¿aviso o casilla?— tiene una respuesta jurídica que no depende del diseño: hace falta
una acción. El diseño solo decide **qué** acción, y para esta población es un botón grande en una pantalla con
una sola pregunta. La segunda pregunta, que consienta el familiar, se resuelve separando dos papeles que la
propuesta inicial mezclaba: **ayudar a decidir** (el familiar, en persona, en el momento de la vinculación) y
**decidir** (el mayor, con su dedo, en su pantalla). Así se conserva lo que la idea tenía de útil —el momento
y la presencia del familiar— sin su problema de fondo.

## Consecuencias

- **Positiva:** cierra la cuestión abierta de ADR-0016, una vez confirmada.
- **Positiva:** la autonomía del mayor queda en el diseño y no en la buena voluntad del familiar.
- **Coste asumido:** algunos mayores vinculados dirán "Ahora no", y el panel de su familiar quedará sin datos
  de conversación. El valor del producto para la familia depende de la voluntad del mayor. Es lo que se
  pretende.
- **Coste:** un caso nuevo en el enrutador (`router_redirect_test.dart`), una pantalla accesible nueva con su
  pantalla de detalle, y una callable más.
- **Límite:** un único consentimiento para análisis y memoria es defendible, porque ambos sirven al mayor,
  pero un revisor estricto podría pedir separarlos.
- **Límite:** esto es un diseño conforme a los principios del RGPD, no un dictamen jurídico. Un despliegue
  real con personas mayores y datos del art. 9 requeriría una evaluación de impacto (EIPD, art. 35). Queda
  anotada como trabajo futuro.

## Verificación

Criterio de cierre:

- Router: un mayor dado de alta sin `conversationConsent` va a `/consent`; con cualquier respuesta, a
  `/home`.
- Reglas, contra el emulador: ni el mayor ni el familiar pueden escribir `conversationConsent` desde el
  cliente.
- Callable: conceder escribe la hora del servidor y `textVersion`; retirar borra las tres colecciones.
- `closeConversation` sin consentimiento → `failed-precondition` (ADR-0029).
- Manual: vincular un mayor nuevo con el familiar al lado → la pantalla aparece tras la vinculación, se lee en
  voz alta y "Ahora no" no vuelve a preguntar.

> **UNRESOLVED — requiere confirmación del autor:**
> 1. ¿El momento de la pregunta es tras elegir modo (independiente) y tras vincular (vinculado)?
> 2. ¿Retirar el consentimiento borra todo lo guardado?
> 3. ¿Un solo consentimiento para análisis y memoria, con el nivel del familiar como control aparte?
>
> Con las tres confirmadas, este ADR pasa a *Aceptada* y ADR-0016 queda cerrado.
