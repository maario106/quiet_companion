# ADR-0018 — El codebase de Cloud Functions nace con una sola callable (síntesis de voz), no con el proxy completo

- **Estado:** Aceptada
- **Fecha:** 2026-07-25
- **Ámbito:** Infraestructura server-side. Primera pieza de Functions realmente desplegable del proyecto.
- **Decisores:** Autor del TFG.
- **Evidencia:** ADR-0014 (*Propuesta*, "aún no implementado"), ausencia de carpeta `functions/` hasta esta
  fecha, `doc/plan/ACTIVE.md` §4 (que asumía un codebase existente), `functions/index.js`.
- **Relacionada con:** ADR-0014 (proxy para la clave del LLM), ADR-0017 (TTS en la nube), ADR-0008
  (emparejamiento en cliente).

---

## Contexto

La especificación del cambio de TTS situaba la nueva callable "en el codebase de Functions existente, misma
unidad de despliegue que el proxy de Gemini". Ese codebase no existía: ADR-0014 lo dejó en estado
*Propuesta*, la clave de Gemini sigue en `.env` del cliente y el emparejamiento se resolvió como transacción
de cliente (ADR-0008). La dependencia `cloud_functions` estaba en `pubspec.yaml` sin un solo uso.

Crear la infraestructura server-side dejó de ser opcional: sin ella no hay síntesis en la nube. La pregunta
real pasó a ser **cuánto** crear en el mismo movimiento, a semanas de las pruebas de usuario y con la
arquitectura a punto de congelarse.

## Decisión

Se crea `functions/` con **una única función**, `synthesizeSpeech`, en **JavaScript** sobre
**firebase-functions v6 (2ª generación)**, Node 22, región **`europe-west1`**.

- **Solo TTS.** La migración del proxy de Gemini (RNF-8, ADR-0014) no entra: sigue pendiente y con su ADR
  abierto.
- **JavaScript, no TypeScript.** Sin paso de compilación entre editar y desplegar.
- **`europe-west1`.** Firestore vive en `eur3`; los usuarios están en España. El SDK cliente apunta por
  defecto a `us-central1`, así que la región se fija explícitamente en `kTtsFunctionsRegion` — un desajuste
  aquí no da error visible, da respaldo permanente al TTS del dispositivo.
- **`maxInstances: 10`** como guardarraíl de coste en un proyecto sin financiación.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Migrar también el proxy de Gemini** (cerrar ADR-0014 de una vez) | Cierra RNF-8, pero toca el camino conversacional en vivo justo antes de las pruebas de usuario, y la especificación de este cambio lo excluía explícitamente. El riesgo de romper HU-2 pesa más que el beneficio de adelantar una migración que no bloquea a nadie. |
| **Llamar a la API de Cloud TTS directamente desde el cliente con una clave** | Elimina el codebase entero, pero mete una segunda credencial en el binario. Es exactamente lo que ADR-0014 declara inaceptable; empeoraría la postura de seguridad para ahorrar una carpeta. |
| **TypeScript** (plantilla por defecto de `firebase init`) | Más defendible en la memoria y mejor tipado en la callable, pero añade `tsc` y una carpeta `lib/` compilada para ~100 líneas de función. Reconsiderable cuando el codebase crezca con el proxy de Gemini. |
| **Región `us-central1`** (por defecto) | Ligeramente más barata en algunos SKU, pero añade un salto transatlántico a cada frase sintetizada. La latencia percibida es el riesgo principal de este cambio (ADR-0017). |

## Justificación

El codebase se crea porque no queda más remedio, y se mantiene mínimo porque cada función añadida antes de
las pruebas de usuario es superficie que puede fallar en la demo. Una sola función también hace que el
primer despliegue del proyecto sea trivial de verificar: si `synthesizeSpeech` responde, la infraestructura
está bien; no hay nada más con lo que confundirse.

## Consecuencias

- **Positiva:** existe por fin una unidad de despliegue server-side; la migración de Gemini (ADR-0014) ya
  solo tiene que añadir un fichero, no montar la infraestructura.
- **Positiva:** el cliente no gana ninguna credencial nueva. La API de Cloud TTS se consume con las
  credenciales por defecto del entorno de Functions (ADC).
- **Negativa:** RNF-8 sigue incumplido — la clave de Gemini continúa en el cliente. Este ADR **no** cierra
  ADR-0014; solo le quita el prerequisito de infraestructura.
- **Negativa / operativa:** aparece un paso manual antes de que la voz funcione (habilitar la API de Cloud
  Text-to-Speech y desplegar). Mientras no se haga, la app funciona igual que antes: respaldo al TTS del
  dispositivo en cada locución.

## Verificación

`firebase deploy --only functions` sobre `quiet-companion-df0af` y una locución real en el chat de voz. Si
la callable no está desplegada o la región no coincide, el síntoma es la voz robótica de siempre, no un
error: la comprobación honesta es el log de la Function, no la ausencia de fallos en la UI.
