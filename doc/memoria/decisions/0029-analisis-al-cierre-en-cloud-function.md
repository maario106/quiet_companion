# ADR-0029 — La conversación se analiza una sola vez, al cerrarla, en una Cloud Function que no guarda la transcripción

- **Estado:** Aceptada — pendiente de implementación
- **Fecha:** 2026-09-26
- **Ámbito:** HU-5 (RF-7) y HU-6 (RF-8); RNF-8 y RNF-10.
- **Decisores:** Autor del TFG.
- **Supersede a:** ADR-0015 en cuanto a **dónde** se genera el resumen (el cliente). El principio de ADR-0015
  —nunca persistir la transcripción cruda— se conserva.
- **Evidencia:** ADR-0015; `pending.md` §4 (incluido *"Después (HU-5)"*: clasificación en Function
  `onDocumentCreated`); `doc/plan/archive/hu4-plan.md` §C y §E; `functions/index.js` (codebase gen 2 en
  `europe-west1`, credenciales del entorno para Cloud TTS); TFG cap. 4, RF-8 (*"Positivo, Neutro o
  Negativo"*; entrada: *"transcripción de la conversación finalizada"*). Commits: pendientes.
- **Relacionada con:** ADR-0014 (proxy del LLM), ADR-0016 (salida de la transcripción), ADR-0018 y ADR-0024
  (codebase de Functions), ADR-0025 y ADR-0026 (reglas y su verificación), ADR-0028 (frontera), ADR-0030
  (consentimiento), ADR-0031 (qué ve el familiar), ADR-0032 (memoria), ADR-0034 (plazos).

---

## Contexto

El diseño previo tenía dos piezas. ADR-0015 generaba el resumen **en el cliente**, con una segunda llamada a
Gemini, y persistía solo el resumen. El plan de HU-4 (§E) añadía después una Cloud Function que, al crearse
cada resumen, clasificaba su sentimiento. Revisadas juntas, con HU-5 y HU-6 delante, fallan en cuatro puntos:

1. **Clasificar el resumen es clasificar una paráfrasis.** El resumen lo escribe el modelo para ser breve y
   neutro, y el afecto del mayor se pierde por el camino. RF-8 lo dice bien: la entrada es la transcripción.
2. **Lo que no se guarda solo se puede analizar mientras existe.** Como la transcripción no se persiste, todo
   análisis tiene que hacerse en el cierre. "Guardar parámetros y analizar después" solo sirve sobre lo que se
   guardó, y lo que se guarda ya es el resultado del análisis.
3. **El motivo con el que ADR-0015 descartó el servidor confunde transmitir con almacenar.** *"Exigiría subir
   la transcripción a la nube (contradice no persistirla)"*. Pero la transcripción ya va a Google en cada turno
   (ADR-0002, ADR-0016). Pasarla por una Function del propio proyecto, en su región, que no la escribe, no añade
   destinatario ni almacenamiento.
4. **Un prompt en el cliente viaja en el binario.** Cada ajuste del prompt exige instalar una APK nueva en los
   dispositivos de prueba, justo cuando el prompt más va a cambiar: después de las pruebas con usuarios. Y la
   llamada usaría la clave del `.env` (RNF-8, ADR-0014).

## Decisión

1. **Una callable, `closeConversation`**, en el mismo codebase y la misma región que `synthesizeSpeech` y
   `validateAndLink` (gen 2, `europe-west1`, `maxInstances: 10`). Entrada:
   `{ startedAt, endedAt, endReason, turns?: [{ role, text }] }`; `turns` se omite bajo el umbral de ADR-0028.
   Exige sesión y que quien llama sea un mayor con el consentimiento activo (ADR-0030). Si no lo es, devuelve
   `failed-precondition` y no escribe nada.
2. **Una sola llamada a Gemini** con salida estructurada (`responseMimeType: application/json` más
   `responseSchema` con enumerados) y temperatura baja. De ella salen a la vez el resumen, el sentimiento, las
   señales, los temas y, desde la versión 2 del prompt, los cambios de memoria (ADR-0032). Tratar el texto una
   vez, y no una por dato, es también minimización.
3. **La transcripción no se escribe en ningún sitio**: ni en Firestore ni en los registros. El registro guarda
   longitudes e identificadores, nunca texto, con la misma política que `synthesizeSpeech`. Se descarta al
   terminar la invocación.
4. **Credenciales:** la llamada no usa la clave del cliente. La opción preferente es Vertex AI con las
   credenciales del entorno, igual que Cloud TTS. La alternativa es la clave de AI Studio en Secret Manager
   (`defineSecret`). Se decide al implementar, comprobando que `gemini-2.5-flash` está disponible en la región.
5. **Qué se guarda**, escrito con el Admin SDK en **dos documentos por conversación** (el reparto lo impone
   ADR-0031):

   ```
   users/{elderId}/conversations/{id}           ← nivel "cómo se encuentra"
     startedAt, endedAt, elderTurns, endReason
     status:    'analyzed' | 'too_short' | 'failed'
     sentiment: 'positive' | 'neutral' | 'negative' | null
     signals:   subconjunto de ['loneliness', 'sadness', 'worry',
                                'physical_discomfort', 'confusion', 'risk']
     promptVersion, model
     expireAt                                      ← política TTL de Firestore

   users/{elderId}/conversationContents/{id}    ← nivel "de qué hablamos" (mismo id)
     endedAt, topics (≤ 5), summary, expireAt
   ```

6. **Criterios del análisis** (prompt v1):
   - **El sentimiento es el del mayor.** Se evalúan sus turnos; los del asistente solo dan contexto. El
     asistente es cálido siempre y, si se evalúa el diálogo entero, sale "positivo" casi siempre.
   - **Tres clases**, las de RF-8, literalmente.
   - **Señales de lista cerrada**, y solo cuando las expresa el mayor, no cuando el asistente pregunta por
     ellas. `risk` recoge menciones a hacerse daño o a no querer vivir.
   - **El resumen**: una o dos frases, en tercera persona, sin citas literales, sin diagnósticos y sin detalles
     de salud (como mucho, "mencionó molestias").
   - **El prompt advierte** de que el texto viene de un reconocedor de voz, con errores.
   - **`promptVersion`** distingue los registros producidos por versiones distintas del prompt.
7. **Si Gemini falla**, se escribe igualmente el documento de actividad con `status: 'failed'`: la actividad
   cuenta aunque no haya análisis. **Sin reintentos**, como en el resto del proyecto.
8. **Cada cierre aplica el plazo de conservación vigente**, además del TTL: borra las conversaciones cuyo
   `endedAt` quede fuera del plazo (ADR-0034).

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Resumen en el cliente** (ADR-0015) | El prompt viaja en el binario y la llamada usa la clave del cliente. No mejora la privacidad: el texto va a Google igual. |
| **Resumen en cliente y clasificación en Function sobre el resumen** (plan HU-4 §E) | Clasifica una paráfrasis, hace dos llamadas y divide la lógica entre dos sitios. |
| **Guardar parámetros y analizar más tarde, en lote** | Sin la transcripción no hay nada que analizar después. Guardarla para procesarla más tarde es persistirla. |
| **Trigger `onDocumentCreated` en vez de callable** | Exigiría que el cliente escribiera antes algo en Firestore, y ese algo sería la transcripción en reposo. |
| **Clasificar cada turno en vivo** | Añade latencia a cada respuesta (RNF-7: ≤ 5 s), *N* llamadas, y ruido: una frase triste no hace triste una conversación. |
| **Valencia y activación numéricas** (plan HU-4 §E: `{valence, arousal}`) | Aparentan una precisión que un LLM sin calibrar no tiene y que no se puede validar sin datos etiquetados. RF-8 pide tres clases. |
| **Modelo de emociones de HuggingFace** (plan HU-4 §E) | Un segundo proveedor recibiría el texto (otro encargado del tratamiento), y los modelos en español se entrenan con tuits y reseñas, no con habla transcrita de personas mayores. |
| **Emoción a partir del audio (prosodia)** | Obliga a capturar y enviar audio: más invasivo y otra dependencia. El reconocedor ya descarta el audio. |
| **Persistir la transcripción cruda** | Minimización de datos (RNF-10). Ya lo rechazó ADR-0015 y se mantiene. |

## Justificación

Se pasa de dos llamadas sobre datos distintos (el texto en el cliente, el resumen en el servidor) a una sola
sobre el dato correcto, en el único momento en que existe. Sin alcanzar al canal conversacional en vivo, el
análisis es además la primera llamada a Gemini que sale del cliente (ADR-0014), y la que más va a cambiar: un
prompt en el servidor se corrige con `firebase deploy`, sin APK.

## Consecuencias

- **Positiva:** el prompt se puede iterar tras las pruebas sin publicar la app, y `promptVersion` deja rastro
  de cada cambio.
- **Positiva:** avanza RNF-8 sin tocar el camino conversacional en vivo, que es lo que ADR-0018 no quiso
  arriesgar.
- **Positiva:** un tratamiento del texto por conversación, no uno por dato.
- **Coste declarado:** la transcripción da un salto más (cliente → Function → Gemini). Es la contrapartida
  honesta que pedía ADR-0016, y el texto del consentimiento lo dice (ADR-0030).
- **Límite:** las etiquetas de un LLM no están validadas clínicamente. El panel las presenta como
  orientación, nunca como diagnóstico. `risk` **no** convierte la app en un sistema de alertas: el familiar lo
  ve cuando abre el panel. El prompt del chat en vivo necesita su propia instrucción para situaciones de crisis
  (024 y 112), que es un cambio aparte en `gemini_service.dart`.
- **Coste:** una llamada a Flash por conversación, de unos pocos miles de *tokens*. Despreciable a la escala
  de las pruebas.
- **Coste:** una dependencia nueva en `functions/` (el SDK de Gemini para Node), justificada porque es la
  única forma de llamar a Gemini desde el servidor.
- **Coste:** las reglas y sus tests contra el emulador crecen (ADR-0025, ADR-0026).

## Verificación

Criterio de cierre:

- `node --test` sobre las funciones puras: validación del esquema devuelto por el modelo, recorte de listas y
  cálculo del corte de conservación, igual que `pairing.test.js`.
- Contra el emulador, la callable con una transcripción de prueba escribe los dos documentos con el esquema
  esperado, sin ningún campo de texto crudo.
- Sin consentimiento, devuelve `failed-precondition` y no escribe nada.
- Los registros de la Function no contienen texto de la conversación (comprobación con `grep`).
