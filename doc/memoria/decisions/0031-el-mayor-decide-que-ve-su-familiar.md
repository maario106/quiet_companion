# ADR-0031 — El mayor decide qué ve su familiar, y lo hacen cumplir las reglas, no la interfaz

- **Estado:** Aceptada — pendiente de implementación
- **Fecha:** 2026-09-26
- **Ámbito:** HU-6 (RF-8), RNF-10. Lectura, desde el panel del familiar, de lo que produce el análisis.
- **Decisores:** Autor del TFG.
- **Evidencia:** decisión del autor del 2026-09-26 (*"el familiar sí verá el resumen […] es lo más invasivo,
  pero también lo que más valor aporta. Que el propio mayor pueda reajustar lo que su companion ve o no"*);
  `firestore.rules` (las lecturas son de documento completo); ADR-0025 (las reglas no ven las cláusulas de
  una consulta). Commits: pendientes.
- **Relacionada con:** ADR-0029 (qué se guarda), ADR-0030 (consentimiento), ADR-0021 (escalas con nombre),
  ADR-0025 y ADR-0026 (reglas y su verificación), ADR-0033 (lo que ve el propio mayor).

---

## Contexto

De todo lo que produce el análisis, el resumen es a la vez lo que más aporta a la familia ("habló de su nieto
y de que echa de menos el pueblo") y lo más invasivo. El autor decidió que el familiar lo vea, y que el mayor
pueda reajustar lo que su familiar ve.

Quedan dos preguntas: con qué granularidad, y **dónde se hace cumplir**. Si solo se oculta en el panel, la
privacidad depende de que la app del familiar se porte bien: el familiar tiene sesión y puede leer todo lo que
las reglas le permitan, con esta app o con otra. Y las reglas de Firestore no pueden filtrar campos: leer un
documento es leerlo entero o no leerlo. Es la misma limitación que forzó ADR-0024 con las consultas.

## Decisión

1. **Tres niveles con nombre**, siguiendo el patrón de peldaños de ADR-0021:

   | Valor | Lo que lee el mayor | Qué ve el familiar |
   |---|---|---|
   | `none` | "Nada" | Solo que el registro está activado. |
   | `wellbeing` | "Cómo me encuentro" | Actividad (cuándo y cuánto habla), ánimo y señales. |
   | `full` | "Cómo me encuentro y de qué hablamos" | Todo lo anterior, más temas, resúmenes y lo que el asistente recuerda. |

2. **Por defecto, `full`** (decisión del autor), dicho explícitamente en la pantalla de consentimiento
   (ADR-0030).
3. **Lo escribe solo el mayor.** El campo `companionSharing` vive en su documento, y el familiar no puede
   escribirlo porque no está en su lista de campos. En Ajustes aparece la fila **"Qué ve mi familiar"**,
   visible solo si el mayor está vinculado y ha consentido. El mayor puede subirlo y bajarlo cuando quiera.
4. **Lo hacen cumplir las reglas, gracias al reparto del almacenamiento** de ADR-0029:
   - `conversations/*` → el familiar lo lee si está vinculado y el nivel es `wellbeing` o `full`;
   - `conversationContents/*` y `memory/*` → el familiar lo lee solo con `full`.

   Las reglas consultan el documento del mayor con `get()` para comprobar el vínculo y el nivel.
5. **Un cambio de nivel afecta también al pasado.** Como se aplica al leer y no se copia al escribir, bajar a
   "Nada" oculta de inmediato todo el historial.
6. **El mayor siempre ve lo suyo**, incluido qué ve su familiar (ADR-0033).

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Ocultar solo en la interfaz del panel** | La privacidad dependería del cliente del familiar. Una regla sí se cumple aunque el cliente no quiera. |
| **Un solo documento por conversación, filtrado en el cliente** | Lo mismo que lo anterior, con otra forma. |
| **Copiar al escribir a una colección "compartida" según el nivel vigente** | Cambiar de nivel no afectaría al pasado, y los datos quedarían duplicados. |
| **Una casilla por dato** (actividad, ánimo, señales, temas, resúmenes, memoria) | Seis decisiones para el mayor, y combinaciones sin sentido (resúmenes sin ánimo). |
| **Sí o no** (todo o nada) | Pierde el término medio más útil: *"que sepa cómo estoy, pero no de qué hablo"*. |
| **Que el familiar pueda cambiar el nivel** | Son datos del mayor. El familiar puede dejar de mirar; no puede mirar más. |

## Justificación

Es la regla que el proyecto ya aplicó a la vinculación (ADR-0024, ADR-0025): una garantía de acceso solo vale
si la hace cumplir el servidor. Aquí el coste de cumplirla es partir cada conversación en dos documentos, a
cambio de que "lo que ve mi familiar" sea una propiedad del sistema y no una promesa de la interfaz.

## Consecuencias

- **Positiva:** la privacidad elegida por el mayor se verifica contra el emulador: un familiar con nivel
  `wellbeing` que intenta leer `conversationContents` es rechazado.
- **Positiva:** el cambio de nivel es inmediato y alcanza al pasado.
- **Coste:** dos escrituras por conversación, dos colecciones y reglas con `get()` (una lectura extra por
  evaluación).
- **Coste ético asumido:** las señales, incluida `risk`, están en el nivel `wellbeing`. Si el mayor elige
  "Nada", su familiar no sabrá que hubo una señal de riesgo. Se acepta: prima la autonomía del mayor, y la app
  no es un sistema de alertas (ADR-0029). La memoria del TFG debe decirlo.

## Verificación

Criterio de cierre. Tests de reglas contra el emulador (ADR-0026), casos nuevos por nivel:

- el familiar con `none` no lee nada;
- con `wellbeing` lee `conversations` y no lee `conversationContents` ni `memory`;
- con `full` lee las tres;
- un familiar no vinculado no lee nada;
- el familiar no puede escribir `companionSharing`;
- el dueño lee las tres colecciones y ninguno de los dos puede escribirlas.
