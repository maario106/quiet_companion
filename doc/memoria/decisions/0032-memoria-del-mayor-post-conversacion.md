# ADR-0032 — La memoria del mayor se extrae al cerrar cada conversación, vive en un documento aparte y se inyecta al empezar la siguiente

- **Estado:** Aceptada — implementada el 2026-09-26, pendiente de verificación en dispositivo
- **Fecha:** 2026-09-26
- **Ámbito:** HU-5 (RF-7, memoria conversacional). Descarta el camino principal del plan de HU-4 §D
  (`guardarContexto` en tiempo real) y convierte su extensión opcional §D.6 en el camino principal.
- **Decisores:** Autor del TFG.
- **Evidencia:** `doc/plan/archive/hu4-plan.md` §D; `lib/core/services/gemini_service.dart`
  (`startSession`, `guardarNombre`, `systemInstruction`); `lib/features/conversation/domain/chat_controller.dart`;
  `lib/features/onboarding/data/auth_repository.dart` (`saveUser` reescribe el documento entero); ADR-0023
  (*"startSession borra el hilo de la conversación"*); TFG cap. 4, RF-7 (*"datos básicos del usuario […] y un
  resumen del contexto reciente de conversaciones previas"*). Implementación: `functions/conversation.js` (prompt v2, `normalizeMemoryChanges`, `applyMemoryChanges`,
  `pushRecentSummary`), `functions/index.js`, `core/models/elder_memory.dart`,
  `core/repositories/conversation_repository.dart`, `core/providers/conversation_providers.dart`
  (`elderMemoryProvider`), `gemini_service.dart` (`memoryContext`, `startSession(history:)`), `chat_controller.dart`,
  `dashboard/presentation/wellbeing_section.dart`. Commits: fase 7 de `doc/plan/ACTIVE.md`, SHA pendiente.
- **Relacionada con:** ADR-0002 (el "RAG parcial" que anunciaba), ADR-0023, ADR-0027, ADR-0028, ADR-0029,
  ADR-0030, ADR-0031.

---

## Contexto

La API de Gemini no recuerda nada entre llamadas. El `ChatSession` de `google_generative_ai` es una lista de
mensajes en la memoria del teléfono que se reenvía entera en cada turno. Desaparece al cerrarse la app, y
también cada vez que se llama a `startSession`, cosa que hoy ocurre al aprender el nombre. Cualquier
"conciencia de contexto" entre conversaciones tiene que guardarse fuera y volver a entregarse al modelo.

El plan de HU-4 §D lo resolvía en tiempo real: una función `guardarContexto(clave, valor)` que Gemini llamaría
a mitad de conversación, escribiendo en un mapa `context` dentro de `users/{uid}`. Ofrecía como extensión
opcional un barrido posterior (§D.6), si el modo en tiempo real se dejaba cosas.

Con ADR-0028 y ADR-0029 ya hay, al final de cada conversación, una llamada que lee la transcripción entera.

## Decisión

1. **La memoria se extrae en el cierre, en la misma llamada de ADR-0029** (versión 2 del prompt). El modelo
   recibe el perfil actual y la transcripción, y devuelve **cambios**, no un perfil nuevo:
   `{ upsert: { clave: valor }, remove: [clave] }`. La Function los aplica con un **tope de 30 datos**: las
   altas que lo superen se descartan y se registra que se descartaron.
2. **Vive en un documento aparte**, `users/{elderId}/memory/profile`:

   ```
   facts:     { "nieto": "Pablo, 8 años", "ciudad": "Sevilla", … }
   recent:    [ { endedAt, summary } ]     ← las 3 últimas conversaciones analizadas
   updatedAt
   ```

   Lo escribe solo la Function. Lo lee el mayor (para inyectarlo) y el familiar con nivel `full` (ADR-0031).
3. **Qué no entra:**
   - detalles de salud (art. 9 RGPD; el asistente ya remite esos temas a la familia o al médico);
   - datos de terceros más allá del nombre y la relación ("nieto Pablo");
   - lo que el mayor pide olvidar ("eso no lo recuerdes"), que se trata como `remove`.
4. **Se inyecta al empezar cada conversación** (ADR-0028). `startSession` recibe el nombre y la memoria y
   añade al `systemInstruction` un bloque *"Lo que sabes de {nombre}"* con los datos, y *"De vuestras últimas
   conversaciones"* con los resúmenes recientes. Instrucciones: usarlo con naturalidad, no recitarlo, no decir
   que se tienen notas. Si la memoria está vacía, el bloque se omite (como ya preveía el plan, §D.2).
5. **El controlador recibe la memoria sin reconstruirse.** Un `elderMemoryProvider` (en `core/providers/`)
   escucha el documento, y el provider del chat se la entrega con `ref.listen`, siguiendo la regla de ADR-0023.
   Una actualización de la memoria **nunca** reinicia una sesión en curso: se usa en la siguiente.
6. **`guardarNombre` se queda en tiempo real.** El nombre sí hace falta en la misma conversación, para que el
   asistente deje de preguntarlo.
7. **Resembrar sin perder el hilo.** Cuando `startSession` se llama a mitad de conversación (cambio de
   nombre), recibe el historial de la conversación en curso (`startChat(history: …)`). Resuelve el coste que
   ADR-0023 dejó anotado.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **`guardarContexto` en tiempo real** (plan HU-4 §D.2–D.4) | La memoria solo se usa en la conversación siguiente, así que guardarla en vivo no aporta nada. En cambio, cuesta una segunda ida y vuelta en el turno en que se llama (como hoy `guardarNombre`), escribe en mitad de la conversación y depende de que el modelo decida llamar a la función. |
| **Mapa `context` dentro de `users/{uid}`** (plan HU-4 §D.1) | El `set()` completo del panel lo borraría o lo sobrescribiría con una copia vieja (ADR-0027), las reglas denegarían esa escritura del familiar, y cada dato aprendido se emitiría a los dos dispositivos. |
| **Inyectar solo los resúmenes de las últimas *N* conversaciones** | Memoria episódica y repetitiva. Los datos estables (nombres, ciudad) se diluyen entre anécdotas. |
| **Que el modelo reescriba el perfil entero en cada cierre** | Puede perder datos sin que nadie lo note. Una lista de cambios explícitos se puede auditar. |
| **Memoria sin tope** | El `systemInstruction` viaja en **cada** turno: su tamaño se paga siempre y diluye las instrucciones. |
| ***Context caching* de Gemini** | Es una optimización de coste para prefijos largos que se repiten, no memoria. Un perfil de 30 líneas no la necesita. |
| **RAG con *embeddings* y búsqueda vectorial** | Infraestructura nueva desproporcionada para unos treinta datos. |

## Justificación

La pregunta que decide es **cuándo se usa** la memoria, no cuándo se aprende. Se usa al empezar una
conversación, así que basta con aprenderla al terminar la anterior. Aprenderla ahí además es gratis, porque la
llamada de ADR-0029 ya lee la transcripción, y no añade latencia a lo único que el mayor percibe: la
respuesta en vivo.

## Consecuencias

- **Positiva:** RF-7 queda cubierto sin añadir latencia a la conversación.
- **Positiva:** se materializa el "RAG parcial" que anunciaba ADR-0002.
- **Por diseño:** la memoria va una conversación por detrás. Lo que se cuenta ahora se recuerda a partir de
  la siguiente.
- **Coste:** si el análisis falla o Android mata la app antes del cierre, lo dicho en esa conversación no se
  aprende.
- **Riesgo:** los datos extraídos pueden estar mal ("Pablo" transcrito como "Paulo"). El familiar con nivel
  `full` los ve en el panel. Que pueda corregirlos queda como trabajo futuro.
- **Privacidad:** la memoria existe mientras el consentimiento esté activo y se borra al retirarlo
  (ADR-0030).

## Verificación

Criterio de cierre:

- `node --test` sobre la aplicación de cambios: alta, modificación, borrado, respeto del tope y rechazo de
  claves vacías.
- Test de `GeminiService`: el bloque de memoria aparece en el `systemInstruction` si hay datos y se omite si
  no los hay.
- Manual: decir "vivo en Granada" en una conversación, dejar que se cierre, y en la siguiente comprobar que el
  asistente lo sabe sin preguntarlo.

## Implementación (2026-09-26)

- El esquema estructurado no admite objetos con claves libres, así que los cambios de memoria viajan como
  lista de pares `{key, value}` y el servidor los convierte en mapa. Las claves se sanean (minúsculas, sin
  símbolos, 30 caracteres) y se aceptan como mucho 10 cambios por conversación.
- La memoria solo se inyecta con el consentimiento vigente. Si llega o cambia el consentimiento sin
  conversación en curso, la siguiente empieza con la sesión al día; con conversación en curso, se espera.
- Al resembrar por un cambio de nombre, el turno que lo aprendió se apunta **antes** de resembrar, para que la
  sesión nueva lo incluya.
