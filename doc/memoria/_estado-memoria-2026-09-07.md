# Estado de la memoria — auditoría del 2026-09-07

> **Actualización del mismo 2026-09-07 (tarde).** Los puntos §1 a §6 de esta auditoría **ya se han
> ejecutado**: se escribieron los ADR-0024, ADR-0025 y ADR-0026, se marcó ADR-0008 como *Superseded*, se
> actualizaron `scope.md`, `timeline.md` y `hu/hu1-onboarding.md`, y se corrigieron los cuatro pasajes
> obsoletos del capítulo 5 (emparejamiento, accesibilidad, cronología y cierre), además de su tabla de ADRs
> y su figura de hitos. El capítulo recompila sin errores ni cajas desbordadas.
>
> **Queda pendiente:** el capítulo 6 (vacío), las fichas `hu/hu2-conversation.md`, `hu/emergency-call.md` y
> la de seguridad, archivar `doc/plan/ACTIVE.md`, y los diagramas del §7. El documento se conserva íntegro
> como registro de lo que se encontró.


_Artefacto interno (prefijo `_`), no forma parte de la memoria final. Fotografía del desfase entre lo que
dice `doc/` y lo que dice el código a fecha de hoy. Toda afirmación de aquí está trazada a un commit, a un
fichero del árbol de trabajo o a una ejecución real (`flutter test`)._

---

## 0. Resumen en una tabla

| Documento | Estado | Desfase principal |
|---|---|---|
| `decisions/` (23 ADRs) | 🟠 Bueno pero incompleto | Faltan 3 ADRs de la ráfaga del 6-sep; ADR-0008 debe pasar a *Superseded* |
| `scope.md` | 🔴 Desactualizado | RNF-9 sigue en «diseñado, no implementado» cuando ya está en producción |
| `timeline.md` | 🔴 Desactualizado | Cuenta 33 commits; hay **48**. Falta entera la fase de seguridad |
| `hu/` | 🟠 Incompleto | Existen hu1, hu3, hu4. Faltan **hu2 (conversación)**, **emergencia** y **seguridad** |
| `cap. 5 (TeX)` | 🟠 Sólido pero con 3 pasajes falsos ya | Declara abiertos dos compromisos que se cerraron el 6-sep |
| `cap. 6 (TeX)` | 🔴 Vacío | 2 líneas: `\chapter` + `\label` |
| Diagramas | 🔴 Insuficientes | 3 PNG, todos del cap. 4; el conceptual ya no describe el modelo real |
| Versionado de `doc/` | 🔴 Riesgo | **`doc/` está en `.gitignore`**: la memoria no tiene historial ni copia |

Cifras verificadas hoy: **48 commits** (`git log`), **137 tests Dart en verde** (`flutter test`, ejecutado
hoy), **29 casos** en `firestore-tests/rules.test.js`, **10** en `functions/pairing.test.js`,
**23 ADRs**, **5 *features*** en `lib/features/`, **3 PNG** en `doc/tfg/imagenes/uml/`.

---

## 1. El agujero grande: la ráfaga del 6 de septiembre no está documentada

El 2026-09-06 entraron **15 commits** que la memoria no menciona en ningún sitio. Los cinco últimos son,
además, los que **cierran el defecto más criticable del proyecto**:

| Commit | Qué hizo | ¿Documentado? |
|---|---|---|
| `c66d365` | `firestore.rules` reales: lectura por id, `list` denegado, escritura del familiar acotada a `preferences`+`name` | ❌ sin ADR |
| `6efdb3a` | Suite de reglas contra el emulador (`firestore-tests/`) | ❌ sin ADR ni mención |
| `8be3fa9` | Callable `validateAndLink`: **la vinculación sale del cliente (RNF-9)** | ❌ sin ADR |
| `4cbd57f` | Cliente migrado a la callable; se borra `auth_repository_pairing_test.dart` | ❌ |
| `b5093f0` | `/users` deja de ser enumerable desde cliente | ❌ |

Comprobación: `grep -rln "validateAndLink" doc/` sólo devuelve `bootstrap.md` y `plan/ACTIVE.md`. **Ni un
solo fichero de `doc/memoria/` ni del capítulo 5 sabe que esto existe.**

Esto importa más de lo que parece: el capítulo 5 dedica hoy tres párrafos a explicar que reglas y código
son «mutuamente inconsistentes» y lo marca `UNRESOLVED` (línea 626 de `05_Diseño_Desarrollo.tex`), y el
cierre del capítulo enumera «RNF-9 sin cumplir» entre los compromisos abiertos. **Ya no es cierto.** Estás
documentando como agujero lo que es tu mejor evidencia de proceso: detectaste la incoherencia, la
documentaste, y la cerraste con reglas + tests de emulador + función de servidor.

### Qué escribir (por orden)

1. **ADR-0024 — Vinculación mediada por callable (`validateAndLink`)**, que *supersede* a ADR-0008.
   Contexto: la incoherencia declarada en ADR-0008. Opciones: seguir en cliente con reglas laxas / abrir
   `list` sobre `/users` / callable con Admin SDK. Evidencia: `8be3fa9`, `4cbd57f`, `functions/pairing.js`.
2. **ADR-0025 — Modelo de reglas de Firestore: cerrar por defecto y modelar lo que el código hace hoy.**
   La decisión no trivial es `allow list: if false` y el `changed().hasOnly(['preferences','name'])`.
   Evidencia: `c66d365`, `b5093f0`, `firestore.rules`.
3. **ADR-0026 — Verificación de reglas contra el emulador en un paquete aparte** (por qué
   `firestore-tests/` vive fuera de `functions/`, y el conflicto JDK 11 vs. JDK 21 que obligó al
   `JAVA_HOME` local). Evidencia: `6efdb3a`, `firestore-tests/README.md`, se enlaza con ADR-0023.
4. **Editar ADR-0008**: `Estado: Superseded by ADR-0024`. Es lo único que se toca de un ADR viejo — la
   regla de *append-only* lo permite explícitamente.

---

## 2. `scope.md` — cuatro filas mal colocadas

- «Migración del emparejamiento a Cloud Function (RNF-9)» sigue en **«Diseñado, no implementado»**. Está
  implementado (`8be3fa9`).
- Fila «Emparejamiento elder↔familiar (transacción de cliente…)» en «Implementado y verificado»: la
  descripción ya no es la del código, y su evidencia apunta a `auth_repository_pairing_test.dart`, **fichero
  borrado en `4cbd57f`**. Un miembro del tribunal que abra esa ruta no encuentra nada.
- Divergencia «Emparejamiento *atómico server-side*»: **resuelta**, márcala como se marcó la de
  autoconfiguración (tachada + `RESUELTA (2026-09-06, ADR-0024)`).
- Divergencia «Reglas de seguridad sin auditar»: **resuelta** (`c66d365` + 29 casos de test).
- Falta añadir a «Implementado, aún sin verificación formal»: escucha por turnos (ya está), y **el recorrido
  extremo a extremo contra el emulador** que documentaste en `firestore-tests/README.md` (sin commitear).

## 3. `timeline.md` — se quedó en julio

Dice literalmente «33 commits, 2026-03-05 → 2026-07-16». Hoy hay 48. Falta una **Fase 5** completa, que
además es la más densa del proyecto:

| Fase | Fecha | Commits | Qué entregó |
|---|---|---|---|
| 5 — Voz en la nube, accesibilidad local y endurecimiento | 2026-09-06 | 15 (`566482a` → `b5093f0`) | TTS Chirp 3 HD con respaldo, troceado por frases, escucha por turnos, escalas locales de accesibilidad, reglas de Firestore + 29 tests de emulador, callable de vinculación |

**Ojo con las fechas.** El capítulo 5 sitúa la migración de voz en el «25 al 27 de julio» y `scope.md` dice
«desplegado el 2026-07-27»; el historial fecha esos commits el **2026-09-06**. Tu propia regla (bootstrap
§0.4) dice que las fechas salen de `git log` y de ningún otro sitio. O se corrige a la fecha del commit, o
se explica en una nota que el trabajo se hizo en local en julio y se consolidó en septiembre. Lo que no
puede quedar es la contradicción sin explicar: es exactamente el tipo de detalle que un tribunal usa para
poner en duda el resto de la trazabilidad.

## 4. Capítulo 5 — tres pasajes que hoy son falsos

Está bien escrito y es defendible, pero tiene fecha de caducidad puesta:

| Línea aprox. | Dice | Realidad |
|---|---|---|
| 584-630 (§Identidad) | «la vinculación está implementada como **transacción de cliente**… bajo las reglas desplegadas esa escritura sería denegada» + nota `UNRESOLVED` | Resuelto: callable + reglas verificadas |
| 600-610 (§ADR-0013) | «los controles locales… **no existen en el código**», «`settings_rows.dart` contiene una única fila» | Resuelto el 6-sep (`826642c`, ADR-0021): tres escalas locales |
| 866+ (§Cierre) | «141 casos en verde»; «los compromisos abiertos son **tres**» | Son **137** (ejecutado hoy); los compromisos abiertos son **dos**: clave de Gemini (RNF-8) y consentimiento (ADR-0016) |
| 790-820 (§Cronología) | 33 commits, 5 fases, figura TikZ con 5 hitos | 48 commits, 6 fases; la figura necesita un sexto punto |

Lo bueno: el capítulo queda **más fuerte** tras la actualización, no más débil. Pasa de «tengo dos agujeros
de seguridad» a «detecté dos, cerré uno con función de servidor y tests de reglas, y el otro queda declarado
con su ruta de cierre».

## 5. Huecos estructurales

- **`hu/` incompleto.** Existen `hu1-onboarding.md`, `hu3-accessibility.md`, `hu4-adaptive-config.md`. El
  propio `bootstrap.md` §3 pedía además `hu2-conversation.md` y `emergency-call.md`. Y ahora falta un
  tercero, de la vertical de seguridad. HU-2 es especialmente sangrante: **es el corazón del producto** (el
  pipeline de voz) y es la única HU sin ficha de memoria.
- **`doc/plan/ACTIVE.md` no es un plan activo**: contiene la spec del cambio de TTS, que está **terminada**.
  Según tus propias reglas (`CLAUDE.md` §Documentation Rules) debería haberse reescrito a
  `doc/memoria/hu/` en pasado y movido a `doc/plan/archive/`. Es la segunda vez que este documento aparece
  señalado: `scope.md` ya lo listaba como «higiene documental».
- **Capítulo 6 (`06_Desarrollo_Futuro.tex`) está vacío** — 2 líneas. Es el capítulo donde vive todo lo que
  has decidido *no* construir, y tienes el material ya escrito y trazado: tabla 3 de `scope.md`, ADR-0014,
  ADR-0015, ADR-0016. Es probablemente el mejor ratio esfuerzo/resultado que te queda.

## 6. `doc/` no está en git — riesgo real

`.gitignore:58` ignora `doc/` entero (`8b7cccc`, «ignore thesis LaTeX documentation»). Consecuencias:

1. **La memoria no tiene copia ni historial.** 898 líneas de capítulo 5, 23 ADRs y las fichas de HU viven en
   un único disco sin versionar. Un `git clean -xdf` los borra sin aviso.
2. **La regla estrella de `CLAUDE.md` es inaplicable tal como está escrita**: «todo cambio con *trade-off*
   lleva un ADR en el **mismo commit** que el código». Si `doc/` está ignorado, ningún ADR puede ir en
   ningún commit. Esto explica mecánicamente por qué faltan los ADRs del §1.
3. La propiedad *append-only* de los ADRs no es verificable por nadie: no hay historial que lo demuestre.

Recomendación: dejar de ignorar `doc/` (manteniendo ignorados sólo los artefactos de LaTeX —
`*.aux`, `*.bbl`, `*.log`, `*.toc`, `*.synctex.gz`… — y `doc/pdfs/`). El primer commit puede ser uno solo,
`docs: incorporar la memoria al control de versiones`, con una nota honesta de por qué llega tarde.

## 7. Diagramas — el área más floja

**Lo que hay (3, todos del cap. 4, del 4 de julio):** actores, casos de uso, conceptual. Más una figura
TikZ de hitos en el cap. 5.

**El diagrama conceptual ya no describe el sistema.** Muestra `Mayor{autonomia, codigoVinculacion}`,
`Companion`, `Usuario{id, rol}` y `Preferencias{volumen, velocidadVoz, multiplicadorTexto}`. El modelo real
(`lib/core/models/user_model.dart`) tiene además `name`, `phoneNumber`, `linkedCompanionId` **y**
`linkedElderId` (dos campos, no una relación genérica), y una entidad entera que falta:
`EmergencyContact{name, phone, source}`. Además `AutonomyStatus` tiene **4** valores en código
(`independent/dependent/linked/none`) frente a los 2 del diagrama, y `UserRole` **3** (`elder/companion/unassigned`)
frente a 2. Ese desajuste ya está confesado en `scope.md` §Divergencias, pero el diagrama sigue en el PDF.

**Lo que falta, por prioridad:**

| # | Diagrama | Por qué es el que más pesa |
|---|---|---|
| 1 | **Secuencia del pipeline de voz** (STT → Gemini → troceado → callable `synthesizeSpeech` → reproducción, con el respaldo a TTS de dispositivo y la cancelación por *generation counter*) | Es la parte más técnica del TFG y hoy sólo existe en prosa. Un diagrama aquí vale por tres páginas |
| 2 | **Secuencia de vinculación vía `validateAndLink`** (familiar → callable → Admin SDK → dos documentos) | Es la respuesta gráfica a la crítica de seguridad. Contrástalo con el flujo antiguo de cliente: dos diagramas lado a lado cuentan la historia entera |
| 3 | **Arquitectura por capas / *slices*** (core vs. features, sin acoplamiento horizontal, DI por providers) | El cap. 5 §5.6 lo describe en texto; es el diagrama que justifica ADR-0004 |
| 4 | **Modelo de datos actualizado** (sustituye al conceptual, con `EmergencyContact` y los dos campos de vínculo) | El que está es incorrecto, que es peor que no tenerlo |
| 5 | **Despliegue** (dispositivo Android · Firebase Auth/Firestore · Cloud Functions `europe-west1` gen 2 · Cloud TTS · API de Gemini **desde el cliente**) | Enseña de un vistazo dónde está la clave de Gemini y por qué RNF-8 sigue abierto. Convierte una debilidad en una decisión explicada |
| 6 | **Navegación / máquina de estados del enrutador** (splash → onboarding → ramas por rol, con los *redirects* de `RouterNotifier`) | Era el «punto débil declarado» del proyecto; el diagrama demuestra que se cerró |
| 7 | **Estados de `ChatStatus`** (idle/escuchando/pensando/hablando + turnos y cierre por silencio, ADR-0022) | Barato y refuerza el cap. de accesibilidad |
| 8 | Reglas de seguridad como matriz sujeto × operación | Alternativa tabular al diagrama; convierte los 29 tests en una figura |
| 9 | Las **3 imágenes de diseño ya referenciadas y comentadas** en el cap. 5 (bocetos, wireframes de iPad, mockups) | Ya tienes el hueco hecho con `\includegraphics` comentado (líneas 255, 272, 287). Sólo hay que exportar los ficheros |

Sugerencia práctica: 1, 2, 3 y 5 se hacen en PlantUML o Mermaid en minutos y se exportan a PNG; el 9 es
sólo exportar lo que ya existe.

---

## 8. Orden de trabajo propuesto

| Orden | Tarea | Esfuerzo | Por qué primero |
|---|---|---|---|
| 1 | Sacar `doc/` del `.gitignore` y commitear | 15 min | Todo lo demás corre riesgo mientras no esté |
| 2 | ADR-0024/0025/0026 + `Superseded` en ADR-0008 | 2 h | Desbloquea la actualización del cap. 5 |
| 3 | Actualizar `scope.md` y `timeline.md` | 1 h | Son la fuente que consume el capítulo |
| 4 | Corregir los 4 pasajes del cap. 5 + figura de hitos | 1,5 h | Elimina afirmaciones hoy falsas |
| 5 | Diagramas 1, 2, 3, 5 | 3 h | Máximo impacto visual |
| 6 | `hu/hu2-conversation.md`, `hu/emergency-call.md`, `hu/seguridad.md` | 3 h | Cierra la estructura que prometiste en `bootstrap.md` |
| 7 | Archivar `ACTIVE.md` y abrir uno nuevo | 20 min | Cumplir tu propia regla, y se nota que se cumple |
| 8 | Capítulo 6 | 4 h | El material ya está trazado en `scope.md` tabla 3 |
| 9 | Diagrama de datos (4), navegación (6), estados (7), imágenes de diseño (9) | 3 h | Relleno de calidad |

---

## 9. Diez preguntas para la reunión con los tutores

Ordenadas de mayor a menor riesgo ante un tribunal. Cada una lleva **por qué** se pregunta y **qué tienes ya
para defenderte**, para que la reunión sirva para decidir, no para informar.

### 1. La clave de Gemini vive en el cliente (RNF-8 incumplido). ¿La implemento antes de defender o la declaro como límite consciente?
**Por qué.** El PDF de justificación del *stack* lo llama «requisito de seguridad crítico» y RNF-8 lo da por
previsto; el código lee la clave de `.env` empaquetado (`lib/core/config/env.dart`, `gemini_service.dart:59`).
Es la incoherencia requisito–implementación más fácil de encontrar para un tribunal.
**Qué tengo.** El *codebase* de Functions ya existe y ya tiene dos *callables* desplegadas
(`synthesizeSpeech`, `validateAndLink`): mover la llamada a Gemini es la misma pieza otra vez, no una
arquitectura nueva. Está documentado en ADR-0014 como decisión tomada y no ejecutada.
**Lo que quiero decidir.** Si el coste (unas horas) compensa frente a dedicar ese tiempo al capítulo 6.

### 2. No hay validación con personas mayores reales. ¿Qué exige el tribunal como mínimo?
**Por qué.** Es un TFG sobre soledad no deseada en mayores y el argumento central es de usabilidad. Sin
usuarios, todas las decisiones de accesibilidad quedan sostenidas por bibliografía, no por evidencia propia.
**Qué tengo.** Requisitos de accesibilidad trazados (táctil ≥88 px, cuerpo ≥20 sp, *tap-only*, WCAG 2.2) y
decisiones justificadas por fuentes.
**Lo que quiero decidir.** Si basta con una evaluación heurística (Nielsen) o un recorrido cognitivo
documentado, o si hay que hacer sesiones reales — y en ese caso, si la ETSIIT exige consentimiento
informado o paso por comité de ética, y con cuánta antelación.

### 3. HU-5 y HU-6 —el análisis emocional— no están construidas. ¿Cómo evito que el tribunal lea «falta el núcleo»?
**Por qué.** El análisis emocional es la propuesta de valor diferencial en la introducción, y `scope.md` lo
declara honestamente al 0 %. Un tribunal puede leer que el TFG entrega la infraestructura y no la idea.
**Qué tengo.** Cadena de dependencias explícita y documentada: HU-5 requiere persistencia (ADR-0015), que
requiere cerrar el modelo de consentimiento (ADR-0016), que es una decisión legal, no técnica. Es decir: no
está sin hacer por falta de tiempo, sino por una decisión de privacidad tomada a conciencia.
**Lo que quiero decidir.** Si reescribo los objetivos del cap. 1 para que el alcance entregado los cumpla
literalmente, o mantengo el objetivo ambicioso y lo reencuadro en el cap. 6.

### 4. RGPD: voz de una persona mayor que sale del dispositivo, y un familiar que ve sus datos. ¿Qué profundidad de análisis legal esperáis?
**Por qué.** Sujeto vulnerable + datos de voz + tercero con acceso. Si en el tribunal hay alguien sensible a
protección de datos, ésta es la pregunta difícil. Hoy ADR-0016 está abierto **a propósito**.
**Qué tengo.** La tensión está documentada, no escondida: ADR-0015 (sólo resúmenes en reposo) frente a la
realidad de que el audio se transcribe y el texto sale a Google.
**Lo que quiero decidir.** Si basta con nombrar base jurídica y minimización, o si esperáis algo tipo
evaluación de impacto (AIPD) y quién es el responsable del tratamiento en un TFG.

### 5. Uso intensivo de agentes de IA en desarrollo y documentación. ¿Cómo se declara y qué evidencia de autoría propia se espera?
**Por qué.** El repositorio contiene los *briefs* de los agentes; la trazabilidad juega a favor si se declara
y en contra si el tribunal lo descubre. Es hoy uno de los temas más vivos en las defensas.
**Qué tengo.** Cada decisión con alternativas rechazadas está en un ADR con evidencia (commit + fichero), y
el bucle revisión→hallazgo→refactorización del hito 2.5 de HU-4 está documentado como proceso.
**Lo que quiero decidir.** Dónde va la declaración (prefacio, metodología o anexo) y con qué nivel de
detalle.

### 6. No hay métricas cuantitativas del sistema. ¿Hace falta una sección de evaluación con números?
**Por qué.** El capítulo 5 argumenta calidad sin medirla: no hay latencia extremo a extremo del pipeline de
voz, ni tasa de acierto del STT en es-ES, ni frecuencia de respaldo del TTS, ni coste por sesión. Un
tribunal técnico pregunta «¿cuánto tarda?» y hoy no hay respuesta.
**Qué tengo.** Los puntos de instrumentación existen (troceado por frases, *timeout* de 4 s, contador de
respaldos), así que medir es barato.
**Lo que quiero decidir.** Qué tres o cuatro métricas dan más valor por hora invertida.

### 7. Cobertura de tests desigual y sin CI. ¿Es un problema de rigor o es aceptable en un MVP?
**Por qué.** 137 tests Dart en verde, 29 de reglas contra emulador y 10 de la lógica de vinculación — pero
`GeminiService` y `ChatController`, que son el corazón funcional, están **deliberadamente fuera** de
cobertura, y no hay integración continua ni pruebas de extremo a extremo.
**Qué tengo.** La exclusión es una decisión declarada (esperar a que se asiente el perfil de contexto
conversacional), no un olvido, y el recorrido manual contra el emulador está documentado paso a paso.
**Lo que quiero decidir.** Si monto un GitHub Actions mínimo (analyze + test) por señal de rigor, o si el
tiempo rinde más en otra parte.

### 8. Clean Architecture + Feature-Sliced Design en un proyecto de una persona. ¿Se defiende o suena a sobre-ingeniería?
**Por qué.** Es una pregunta clásica de tribunal: «¿no era esto demasiado para un MVP?». La respuesta
perezosa («es buena práctica») no aguanta.
**Qué tengo.** Una respuesta con evidencia: la abstracción `TtsService` permitió **cambiar el motor de voz
del dispositivo a la nube tocando sólo la implementación**, y la vinculación pudo migrar de cliente a Cloud
Function cambiando un repositorio. Eso son dos sustituciones reales, no un argumento teórico.
**Lo que quiero decidir.** Si merece un apartado propio del capítulo 5 en vez de quedar diluido.

### 9. ¿Qué conjunto de diagramas consideráis mínimo exigible, y en qué notación?
**Por qué.** Hoy hay tres (actores, casos de uso, conceptual) y **el conceptual ya no coincide con el
modelo de datos real**: le faltan `EmergencyContact`, `name`, `phoneNumber` y los dos campos de vínculo.
Un diagrama incorrecto es peor que ninguno.
**Qué tengo.** La lista priorizada del §7 de este documento, con los cuatro que más aportan
(secuencia de voz, secuencia de vinculación, capas y despliegue).
**Lo que quiero decidir.** Si esperáis UML estricto o admitís notación tipo C4 / diagramas de secuencia
informales; y si el de casos de uso hay que rehacerlo tras haber añadido emergencia y ajustes locales.

### 10. Cronología a ráfagas y trazabilidad de fechas. ¿Cómo lo presento sin que parezca inconsistente?
**Por qué.** El desarrollo tiene saltos grandes (17-mar → 14-abr → 13-may → 16-jul → 6-sep) y, sobre todo,
**la memoria data la migración de voz el 25-27 de julio mientras el historial la fecha el 6 de septiembre**.
Además `doc/` está fuera de git, así que la propia memoria no tiene historial que la respalde.
**Qué tengo.** Una nota metodológica ya escrita que explica las ráfagas por compatibilizar el TFG con
empleo a tiempo completo, y cada ráfaga cierra un incremento compilable.
**Lo que quiero decidir.** Si corrijo las fechas a las del commit, o añado una nota explicando el desfase
trabajo-local / consolidación; y si conviene meter `doc/` en git ya, aun a riesgo de que se vea que llegó
tarde al control de versiones.

---

## 10. Preguntas de reserva (si sobra tiempo)

- **Accesibilidad sin auditar.** Se declara WCAG 2.2 AA como objetivo pero no hay informe de conformidad; el
  recorrido con TalkBack sigue pendiente y hay un *token* de color («Pensando», `#E07B20`, 2,84:1) por
  debajo del umbral 3:1. ¿Basta con declarar el nivel objetivo o esperáis conformidad verificada (EN 301 549)?
- **Identidad anónima del mayor.** Reinstalar la app crea un usuario nuevo y se pierde el perfil, sin
  migración entre dispositivos. Está documentado como coste asumido (ADR-0006) — ¿es asumible para un
  tribunal, siendo el usuario objetivo el menos capaz de recuperarse de esa pérdida?
- **Colisión de códigos de vinculación.** Espacio de ~923 000 combinaciones y sin reintento ante colisión.
  Riesgo asumido a escala de pruebas: ¿lo dejo declarado o lo cierro (son pocas líneas en la callable)?
