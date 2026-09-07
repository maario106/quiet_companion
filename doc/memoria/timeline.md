# Cronología del desarrollo

_Reconstruida **exclusivamente** a partir de `git log` (48 commits, 2026-03-05 → 2026-09-06). No se
interpolan ni se infieren fechas fuera del historial. Actualizada el 2026-09-07._

---

## Fases

| Fase | HU / área | Primer commit | Último commit | Nº commits | Qué entregó |
|---|---|---|---|---|---|
| 0 — Arranque del repositorio | — | `008a547` (2026-03-05) | `223385c` (2026-03-05) | 3 | README y descripción inicial del proyecto (sin código). |
| 1 — Prototipo funcional y stack | HU-2 (semilla), fundamentos HU-1 | `6479d15` (2026-03-10) | `d05ef03` (2026-03-17) | 14 | Init de Flutter, integración de la API de Gemini, prototipo de chat con TTS/STT, permisos de micrófono, configuración de Firebase y primer `UserModel` en `core/`. |
| 2 — Onboarding dual, dashboard y config. adaptativa | HU-1, HU-4 | `5555d83` (2026-04-14) | `f1978e0` (2026-04-28) | 4 | Onboarding dual (mayor/familiar), controladores de auth, emparejamiento (`WriteBatch`), router con redirects, dashboard remoto, `currentUserProvider` y HU-4 Milestones 1 y 2. |
| 3 — Estabilización HU-1→4 | HU-1 a HU-4 | `c117166` (2026-05-13) | `119c208` (2026-05-13) | 3 | Pulido de navegación, migración a DI por providers, refactor de router y UI, nombre del mayor por *function calling*, y notas de sesión (`INFO.md` §8-10). |
| 4 — Emergencia, ajustes y suite de tests | Emergencia, endurecimiento HU-1/3/4 | `2ebf10f` (2026-07-16) | `895c921` (2026-07-16) | 9 | Suite de tests (105 verdes), llamada de emergencia (`tel:`/`url_launcher`), migración del emparejamiento a `runTransaction` con desnormalización del contacto, shell de ajustes y estado de salida en segundo plano. |
| 5 — Voz en la nube, accesibilidad local y endurecimiento | HU-2, HU-3, RNF-9 | `566482a` (2026-09-06) | `b5093f0` (2026-09-06) | 15 | TTS en la nube (Chirp 3: HD) con troceado por frases y respaldo al dispositivo, escucha por turnos con cierre por silencio, escalas locales de accesibilidad para el mayor, reglas de Firestore verificadas contra el emulador y vinculación migrada a la callable `validateAndLink`. |

---

## Notas por fase

**Fase 1 — Prototipo funcional y stack.** El proyecto arrancó demostrando lo más arriesgado primero: que el
pipeline de voz (STT → Gemini → TTS) funcionaba. En paralelo se fijó el stack (Flutter, Gemini, Firebase) y
se movió el `UserModel` a `core/`, sentando la arquitectura. El commit `f0db65d` ("Borrado del prototipo
para reunión TFG") marca el cierre de la primera versión funcional presentable.

**Fase 2 — Onboarding dual y configuración adaptativa.** Sobre los cimientos anteriores se construyó la
identidad de los dos actores (onboarding dual, emparejamiento por código) y el bucle de configuración remota
(dashboard del familiar → Firestore → dispositivo del mayor), con `currentUserProvider` como columna
vertebral reactiva. `96cfd57` cierra los dos primeros *milestones* de HU-4.

**Fase 3 — Estabilización.** No añadió funcionalidad nueva de usuario: consolidó lo existente antes de las
pruebas, para que los tests no hubiera que rehacerlos. Aquí se pulió la navegación (puntos débiles
declarados), se completó la migración a inyección de dependencias por providers y se eliminó la duplicación
de streams del `ElderAuthController`.

**Fase 4 — Emergencia, ajustes y tests.** Tras una pausa larga, la última ráfaga añadió la feature de
emergencia (112 + contacto desnormalizado), el shell de ajustes y, sobre todo, la **suite de tests** (105
casos). El emparejamiento se reescribió de `WriteBatch` a `runTransaction` para poder leer el doc del mayor
y respetar la precedencia del contacto de emergencia.

**Fase 5 — Voz en la nube, accesibilidad local y endurecimiento.** La ráfaga más densa del proyecto (15
commits en un día de consolidación) y la que cambia la naturaleza del sistema: deja de ser una app que habla
con servicios y pasa a tener **backend propio**. Tres bloques encadenados. El primero sustituye el TTS del
dispositivo por voz de nube sintetizada en una Cloud Function, tras una abstracción `TtsService` con respaldo
al motor local (ADR-0017 a ADR-0020); el segundo corrige la entrada de voz, que perdía palabras en cada pausa
del mayor, y añade las escalas locales de accesibilidad que cierran CU-05 (ADR-0021, ADR-0022); el tercero es
el endurecimiento: reglas de Firestore que modelan el código real, 29 casos contra el emulador y la
vinculación movida al servidor (ADR-0024 a ADR-0026).

Ese tercer bloque merece leerse en orden, porque el orden es el argumento: **primero se escribieron las
reglas, y fueron las reglas las que obligaron a mover el código**. Al redactarlas se descubrió que las reglas
de Firestore no ven las cláusulas `where` de una consulta, de modo que buscar al mayor por su código desde el
cliente exigía dejar `/users` enumerable por cualquier sesión autenticada. La deuda que ADR-0008 había
declarado en abril resultó ser mayor de lo anotado, y se cerró en la misma sesión en que se midió.

---

## Una advertencia sobre dos fechas

El trabajo de la fase 5 **no se hizo todo el 2026-09-06**. La migración de voz se desarrolló entre el 25 y el
27 de julio —así la datan ADR-0017 y `scope.md`— y se consolidó en el repositorio el 6 de septiembre, junto
con el resto de la ráfaga. El historial, por tanto, comprime en un día un trabajo de varias sesiones.

Se deja escrito en lugar de elegir una de las dos fechas porque la regla de este documento es que las fechas
salen de `git log`, y aquí el log describe cuándo se versionó, no cuándo se construyó. Es el único punto del
proyecto donde ambas cosas divergen de forma apreciable.

---

## El bucle de revisión (evidencia de proceso)

El *Milestone 2.5* de HU-4 existe **porque una revisión de arquitectura lo provocó**, no por planificación
previa. Al auditar el trabajo del Milestone 2, el agente revisor detectó **dos violaciones de reglas
preexistentes**: (1) `GeminiService` y `SpeechService` se instanciaban directamente dentro del provider del
`ChatController` (antipatrón de DI) y (2) el dashboard importaba de `features/onboarding`, rompiendo la regla
de no acoplamiento horizontal. Ambas se corrigieron a mitad del hito (`hu4-plan.md` §2.5, `INFO.md` §8.3-8.4).
Esta corrección intermedia es evidencia de proceso —revisión → hallazgo → refactor— más valiosa que un grafo
de commits limpio.

El mismo patrón se repite en la fase 5 y con más nitidez: los primeros 29 casos de reglas se escribieron
**incluyendo los huecos** —casos que documentaban lo que las reglas todavía permitían—, y fue eso lo que
hizo evidente que la vinculación desde el cliente obligaba a dejar `/users` enumerable. La reescritura
posterior (`b5093f0`) cerró el hueco y convirtió esos casos en aserciones de denegación. El test se escribió
antes que la solución y sirvió para encontrarla (ADR-0026).

Otros bucles visibles en el historial: el bug de re-login del familiar (vinculado enviado a la pantalla de
código), diagnosticado y corregido en la fase 3 (`INFO.md` §9.4), el arreglo del test rojo de
`refreshElderData` en la fase 4 (`895c921`, `pending.md` §2.1) y el texto duplicado del reconocedor de voz,
diagnosticado en dispositivo y corregido al día siguiente de la decisión que lo introdujo (ADR-0022
§Corrección posterior).

---

## Nota metodológica

El desarrollo procedió en **incrementos iterativos por HU**, ejecutados en **sesiones concentradas** en
paralelo a un empleo a tiempo completo. La velocidad **no fue uniforme**, y el historial no lo disimula: hay
saltos deliberados entre fases (2026-03-17 → 04-14 → 04-28 → 05-13 → 07-16 → 09-06). Esa cadencia a ráfagas es una
consecuencia de las condiciones del proyecto, no un defecto: cada ráfaga cerró un incremento coherente y
dejó el código en un estado compilable y estabilizado. La arquitectura queda **congelada tras las pruebas de
usuario de HU-1→4**; las HU-5 y HU-6 se difieren de forma explícita (aplicación del principio Lean de
construir solo lo necesario).
