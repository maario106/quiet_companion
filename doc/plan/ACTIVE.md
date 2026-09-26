# Plan activo — HU-5 y HU-6: conversaciones, memoria y bienestar

_Abierto el 2026-09-26. Sustituye a la *spec* del TTS, terminada y archivada en
`archive/tts-chirp3-spec.md`._

---

## Objetivo

Que el lado del familiar sirva para algo más que mover tres deslizadores, y que el análisis también le sirva
al propio mayor, sin guardar nunca lo que dice palabra por palabra.

- **HU-5 — Memoria conversacional (RF-7):** el asistente recuerda lo que el mayor le cuenta entre
  conversaciones.
- **HU-6 — Seguimiento del estado de ánimo (RF-8):** cada conversación se clasifica (positivo, neutro o
  negativo, con señales y temas) y el agregado lo ve el familiar en su panel y el mayor en "Mi semana".

> **Numeración:** se sigue la de la memoria (cap. 3 y 4): HU-5 es la memoria y HU-6 el ánimo. Documentos
> anteriores llaman "HU-5" al análisis emocional (ver `doc/memoria/scope.md`, divergencias).

## Decisiones que gobiernan el plan

| ADR | Estado | Qué fija |
|---|---|---|
| 0027 | Aceptada | El panel escucha al mayor en tiempo real (`linkedElderProvider`) y escribe cada campo con `update()`. |
| 0028 | Aceptada | Una conversación termina tras *N* minutos sin turnos o al pasar a segundo plano (salvo al ir al marcador de emergencia). Por debajo de 3 turnos del mayor no sale texto del móvil. |
| 0029 | Aceptada | Análisis único al cierre en la callable `closeConversation`. La transcripción no se guarda en ningún sitio. Supera a ADR-0015. |
| 0030 | **Propuesta** | Consiente el mayor, con un gesto explícito, una vez: tras elegir el modo independiente o tras vincularse. Retirarlo lo borra todo. |
| 0031 | Aceptada | Tres niveles de lo que ve el familiar (`none`, `wellbeing`, `full`; por defecto `full`), impuestos por las reglas repartiendo los datos en dos colecciones. |
| 0032 | Aceptada | Memoria extraída al cierre (cambios, tope de 30), en `memory/profile`, inyectada al empezar cada conversación. Se descarta `guardarContexto` en tiempo real. |
| 0033 | **Propuesta** | "Mi semana": el mayor ve su análisis, con los mismos datos que el panel y otra pantalla. |
| 0034 | Aceptada | Inactividad {2, 5, 10, 15} min y conservación {30, 60, 90, 180} días. Los fija el familiar (vinculado) o el propio mayor (independiente). Tope de 180 días en el servidor. |

## Pendiente de decidir

| # | Decisión | Bloquea | Dónde |
|---|---|---|---|
| 1 | Confirmar el momento del consentimiento, el borrado al retirarlo y un único consentimiento para análisis y memoria | Fase 1, y con ella de la 3 en adelante | ADR-0030, `UNRESOLVED` |
| 2 | "Mi semana": ¿solo para el independiente o para todo mayor con consentimiento? | Solo el predicado de visibilidad de la fase 6 | ADR-0033, `UNRESOLVED` |
| 3 | Vertex AI con credenciales del entorno o clave de AI Studio en Secret Manager | Fase 3 | ADR-0029 §4 |
| 4 | Posición del acceso a "Mi semana" en `HomeScreen` | Fase 6 | ADR-0033 §4 |

**Las fases 0 y 2 no dependen de ninguna de estas decisiones** y pueden empezar ya.

---

## Fase 0 — El panel ve al mayor en tiempo real (ADR-0027)

Requisito previo de todo lo demás. Arregla además lo que el autor notaba: el panel no muestra el valor
vigente.

- `core/providers/linked_elder_provider.dart`: `StreamProvider<UserModel?>` sobre
  `users/{linkedElderId}`, con la ruta tomada de `FirestorePaths`.
- `AuthRepository`: escritura de un campo de preferencias (`update({'preferences.<campo>': valor})`).
  `saveUser` queda solo para crear documentos.
- `DashboardController`: sin copia `linkedElder` ni *rollback* manual; solo errores de guardado.
- `DashboardScreen`: pinta desde `linkedElderProvider`.
- `dashboard_controller_test.dart`: reescrito para el nuevo camino.
- **Sin ADR (cambio trivial):** `EmergencyContactSetupScreen` precarga el nombre y el teléfono del contacto
  vigente.

**Aceptación:** el guion de ADR-0027 §Verificación, puntos 1 a 4.

## Fase 1 — Consentimiento (ADR-0030) · _bloqueada por la decisión 1_

- `core/models/`: `ConversationConsent { granted, answeredAt, textVersion }`. `UserModel` gana
  `conversationConsent`, `companionSharing` y `conversationSettings`, omitidos en `toMap` cuando son nulos
  (como `emergencyContact`).
- `functions/`: callable `setConversationConsent`.
  - Al conceder, escribe el registro con la hora del servidor y, si el mayor está vinculado, deja
    `companionSharing: 'full'`.
  - Al retirar, hace `recursiveDelete` de `conversations`, `conversationContents` y `memory`, y guarda
    `granted: false`.
- `firestore.rules`: el dueño no puede escribir `conversationConsent`. Tests contra el emulador.
- Router: un mayor dado de alta sin `conversationConsent` va a `/consent`. Test en
  `router_redirect_test.dart`.
- Pantallas del mayor:
  - consentimiento: pregunta, "Sí, quiero" / "Ahora no", "Escuchar" y "Saber más";
  - detalle, con los plazos vigentes y lo que ve el familiar;
  - fila de Ajustes "Guardar mis conversaciones".
- Panel: tarjeta de estado de solo lectura ("Sin activar" / "Activado desde el …").
- Texto del consentimiento versionado (`textVersion`) en una constante.

**Aceptación:** ADR-0030 §Verificación.

## Fase 2 — Frontera de la conversación (ADR-0028), sin red

- `core/config/conversation_config.dart`: valores por defecto (5 min, mínimo de 3 turnos) y márgenes.
- `ConversationCloser` en `core/services/`, con la interfaz y un doble para tests. La implementación real
  llega en la fase 3.
- `ChatController`:
  - búfer de turnos `(rol, texto, hora)` sin las respuestas de error;
  - `startedAt`;
  - temporizador de inactividad inyectable, que empieza a contar al terminar el TTS;
  - `endConversation(reason)`;
  - sesión de Gemini nueva, creada de forma perezosa en el primer turno tras un cierre.
- Ciclo de vida: `paused` cierra la conversación salvo con `intentionalBackgroundExitProvider` activo; al
  volver, cierra si el plazo ya venció.
- Primeros tests de `ChatController` (diferidos hasta ahora en `test.md`): los seis casos de ADR-0028
  §Verificación.

**Aceptación:** esos tests en verde y `flutter analyze` sin incidencias.

## Fase 3 — `closeConversation` y prompt v1 (ADR-0029) · _necesita las fases 1 y 2, y la decisión 3_

- **Primero, el prompt v1**, revisado antes de cablear nada:
  - evalúa el sentimiento del mayor, no el del diálogo;
  - lista cerrada de señales;
  - resumen en tercera persona, sin citas ni datos de salud;
  - advierte de que el texto viene del reconocedor de voz.
- `functions/conversation.js`, con funciones puras: validar la entrada, validar la salida del modelo, recortar
  listas y calcular el corte de conservación. Tests en `functions/conversation.test.js` (`node --test`).
- `exports.closeConversation`:
  - autenticación y comprobación del consentimiento;
  - Gemini con salida estructurada;
  - escritura en `conversations/{id}` y `conversationContents/{id}`;
  - limpieza por plazo;
  - registros sin texto.
- `firestore.rules`: las tres subcolecciones con escritura `if false` y lectura para el dueño. Tests.
- Cliente: `CloudConversationCloser` y `kCloseConversationCallable` en `functions_config.dart`.
- `FirestorePaths`: `conversations`, `conversationContents` y `memory`.
- Chat en vivo: instrucción de crisis en el `systemInstruction` (024 y 112).
- **Paso manual:** política TTL de Firestore sobre `expireAt` en las dos colecciones, y
  `firebase deploy --only functions,firestore:rules`.

**Aceptación:** ADR-0029 §Verificación.

## Fase 4 — Qué ve el familiar y plazos configurables (ADR-0031, ADR-0034)

- Reglas: lectura del familiar según `companionSharing`, y escritura de `conversationSettings`. Los casos de
  ADR-0031 y ADR-0034 contra el emulador.
- Ajustes del mayor:
  - "Qué ve mi familiar" (vinculado y con consentimiento): tres peldaños;
  - "Esperar antes de cerrar la conversación" y "Cuánto tiempo se guarda": solo el independiente.
  - `PreferenceScale` está ligada a los `double` de `UserPreferences`. Al implementar se decide si se
    generaliza la pantalla de peldaños o se hace una específica, porque estos valores no son preferencias.
- Panel: selector de los dos plazos (vinculado); nivel de compartición y consentimiento en solo lectura.
- `closeConversation`: acota y aplica `retentionDays`.

**Aceptación:** los criterios de ADR-0031 y ADR-0034.

## Fase 5 — Panel del familiar (HU-6)

- `core/models/conversation_record.dart` y `conversation_content.dart`; providers de lectura en
  `core/providers/`.
- `core/utils/week_summary.dart`, agregación pura con tests (semana vacía, un día, empates, sin señales).
- Secciones del panel, en orden de fiabilidad:
  1. actividad: última conversación, días con conversación y minutos;
  2. señales de la semana;
  3. ánimo por día;
  4. temas;
  5. lista de conversaciones, con detalle en `/dashboard/conversation/:id`.
- Aviso visible: *"orientativo, no es un diagnóstico"*.
- Si el mayor ha elegido `none` o `wellbeing`, el panel lo dice ("Ana ha elegido no compartir…") en vez de
  mostrar un error de permisos.
- Router: el familiar pasa con `startsWith('/dashboard')`. Test.

**Aceptación:** tests de la agregación y del router, y un recorrido manual con tres conversaciones reales en
el emulador.

## Fase 6 — "Mi semana" (ADR-0033) · _visibilidad según la decisión 2_

- *Feature* nueva del mayor, con la ruta `/my-week` y un acceso desde `HomeScreen`, visible con el
  consentimiento activo y al menos una conversación analizada.
- Frases y no gráficas; "Escuchar" mediante `ttsServiceProvider`; sin etiquetas clínicas; la línea "Tu
  familiar ve: …" con acceso a cambiarlo.
- Reutiliza `week_summary.dart`.

**Aceptación:** ADR-0033 §Verificación.

## Fase 7 — Memoria (ADR-0032)

- Prompt v2: la misma llamada devuelve también los cambios de memoria. Se sube `promptVersion`.
- `functions/`: aplicar los cambios (función pura, con el tope de 30) y escribir `memory/profile` con los tres
  resúmenes recientes. Tests.
- `core/providers/elder_memory_provider.dart`; `GeminiService.startSession(nombre, memoria, historial?)`;
  entrega al controlador por `ref.listen`.
- Al resembrar por un cambio de nombre, se conserva el hilo (`startChat(history: …)`).
- Reglas: lectura de `memory` (el dueño, y el familiar con `full`).
- Panel: "Lo que el asistente sabe", en solo lectura.

**Aceptación:** ADR-0032 §Verificación. Criterio clave: *"vivo en Granada"* se recuerda en la conversación
siguiente.

---

## Fuera de alcance de este plan

- Notificaciones al familiar (FCM, `pending.md` §6).
- Solicitud remota de consentimiento (ADR-0030, alternativas).
- Edición de la memoria por el familiar.
- Migrar el chat en vivo al servidor (ADR-0014).
- Modo teclado.
- n8n.
- La evaluación de impacto (EIPD) de un despliegue real: se cita como trabajo futuro en la memoria.

## Reglas de trabajo

- **El código va en `main_mario` y la documentación en `docs/memoria`** (`CLAUDE.md` §Documentation Rules).
  Cada ADR gana en `Evidencia:` los SHA cortos de los commits que lo implementan, y su `Estado` pasa de
  *pendiente de implementación* a implementado.
- `flutter analyze` sin incidencias en los ficheros tocados, y la suite en verde.
- Las reglas de Firestore cambian en el mismo commit que la operación que las justifica, con sus tests contra
  el emulador (ADR-0025, ADR-0026).
- Ningún texto de conversación en registros, ni del cliente ni de la Function.

## Al cerrar HU-5 y HU-6

- Reescribir este plan en pasado, en `doc/memoria/hu/hu5-memoria-conversacional.md` y
  `doc/memoria/hu/hu6-estado-de-animo.md`, con desviaciones y retrabajo.
- Actualizar `scope.md`: pasar a "Implementado" solo lo que tenga código.
- Memoria del TFG: RF-7 y RF-8 dejan de estar diferidos (cap. 4); la nota de RNF-10 (base jurídica, plazos y
  derecho de supresión) ya tiene respuesta; y hay que reflejarlo en los cap. 5 y 6.
- Mover este fichero a `archive/` y abrir un `ACTIVE.md` nuevo.
