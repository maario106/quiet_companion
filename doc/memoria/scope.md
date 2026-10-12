# Alcance del sistema — implementado vs. diseñado

_Membresía decidida leyendo el código (`lib/`, `test/`, `firestore.rules`) y reconciliada con la
documentación. Una capacidad solo entra en "Implementado" cuando existe el código, nunca cuando existe el
plan._

---

## Implementado y verificado

| Capacidad | HU | Dónde | Evidencia | Verificado cómo |
|---|---|---|---|---|
| Onboarding dual y selección de modo (independiente / vinculado) | HU-1 | `features/onboarding/presentation/onboarding_screen.dart`, `.../domain/elder_auth_controller.dart` | ADR-0007, hu1 | `router_redirect_test.dart` + manual |
| Generación de código de vinculación (4 car., sin O/0/I/1) | HU-1 | `elder_auth_controller.dart` (`_genCode`) | hu1 | Manual |
| Emparejamiento elder↔familiar mediado por servidor (callable `validateAndLink` + desnormalización de contacto) | HU-1 | `functions/index.js`, `functions/pairing.js`, `auth_repository.dart` (`linkCompanionToElder`) | ADR-0024 (supera a ADR-0008), hu1 | `functions/pairing.test.js` (10 casos) + reglas contra emulador |
| Modelo de datos (`UserModel`, `UserPreferences`, `EmergencyContact`) | HU-1/4 | `core/models/` | — | `user_model_test.dart`, `emergency_contact_test.dart` (137 tests verdes en total el 2026-09-07) |
| Sistema de diseño accesible (pisos tipográficos, táctil ≥88 px, *tap-only*, es-ES, contraste emergencia AAA) | HU-3 | `core/theme/app_theme.dart`, `home_screen.dart` | hu3, ADR-0013 | Manual |
| Indicación visual + textual de estado (Escuchando/Pensando/Hablando) | HU-2/3 | `home_screen.dart` (switch `ChatStatus`) | hu3, RF-4 | Manual |
| Dashboard remoto + propagación en caliente de preferencias | HU-4 | `features/dashboard/`, `core/providers/current_user_provider.dart` | ADR-0009, ADR-0010 | `dashboard_controller_test.dart` + manual (2 dispositivos) |
| `currentUserProvider` como *single source of truth* | core | `core/providers/current_user_provider.dart` | ADR-0009 | `router_redirect_test.dart` |
| Llamada de emergencia (112 + contacto, marcador `tel:`) | Emergencia | `features/emergency/`, `core/services/emergency_call_service.dart` | ADR-0012 | `emergency_call_service_test.dart`, `emergency_screen_test.dart` |
| Shell de ajustes del mayor (filas declarativas, visibilidad compartida) | HU-3/4 | `features/settings/`, `core/config/settings_rows.dart` | hu3, ADR-0021 | `settings_screen_test.dart` |
| Reglas de Firestore acotadas por operación (lectura por id, `/users` no enumerable, escritura del familiar limitada a `preferences`+`name`) | RNF-9 | `firestore.rules` | ADR-0025 | `firestore-tests/rules.test.js` (29 casos contra emulador al cerrar el MVP; la suite tiene hoy 48 tras HU-5/HU-6, ver tabla siguiente) |

## Implementado, aún sin verificación formal

| Capacidad | HU | Dónde | Evidencia | Bloqueante |
|---|---|---|---|---|
| Pipeline de voz STT → Gemini → TTS | HU-2 | `chat_controller.dart`, `core/services/{gemini,speech,tts}_service.dart` | ADR-0002 | Sin tests unitarios (diferidos, `test.md`); solo verificación manual |
| Escucha por turno con cierre automático por silencio (2 s) y reanudación de la sesión nativa | HU-2/3, RF-3 | `core/services/speech_service.dart`, `core/config/speech_config.dart` | ADR-0022 | Sin tests (decisión del autor); guion de verificación manual en ADR-0022 §Verificación, pendiente |
| Nombre del mayor aprendido por *function calling* | HU-1/5-semilla | `gemini_service.dart` (`guardarNombre`) | — | Verificación manual (`708d71a`); `GeminiService`/`ChatController` sin tests |
| Transacción real de emparejamiento contra Firestore (precedencia manual/companion) | HU-1 | `functions/index.js` (`validateAndLink`) | ADR-0024, hu1 §7 | La *lógica* de precedencia y normalización tiene 10 tests puros (`functions/pairing.test.js`); la transacción en sí solo se ejercita en el recorrido manual contra el emulador, **pendiente** |
| `DashboardController.updateElderName` | HU-4 | `dashboard_controller.dart` | — | Test diferido (`test.md`) |
| Marcación `tel:` en Android 11+ (bloque `<queries>`) | Emergencia | `AndroidManifest.xml` | ADR-0012 | Pendiente en dispositivo físico (`pending.md` §3) |
| TTS en la nube (Chirp 3: HD) tras abstracción `TtsService`, con respaldo a dispositivo | HU-2 | `core/services/{tts_service,cloud_tts_service,device_tts_service,tts_synthesizer,tts_audio_player}.dart`, `core/utils/sentence_splitter.dart` | ADR-0017, ADR-0019, ADR-0020 | Testeado (`cloud_tts_service_test.dart`, `sentence_splitter_test.dart`); desplegado el 2026-07-27. Pendiente la escucha real en dispositivo tras corregir la reproducción (ADR-0020) |
| Controles locales de accesibilidad del mayor (tamaño de letra, volumen, velocidad; escalas de peldaños con nombre) | HU-3/4, CU-05/RF-5 | `core/config/preference_scales.dart`, `features/settings/presentation/preference_stepper_screen.dart`, `auth_repository.dart` (`updatePreferences`) | ADR-0021 | Sin tests propios (decisión del autor: contener el volumen de pruebas); pendiente recorrido manual en dispositivo |
| Callable `synthesizeSpeech` (Cloud Functions, `europe-west1`, gen 2) | HU-2 | `functions/index.js` | ADR-0018 | Desplegada y verificada por registros (`auth: VALID`, sin errores de síntesis); sin tests automáticos (el codebase no tiene runner de Node) |
| Panel del familiar en tiempo real y escritura por campo | HU-4 | `core/providers/linked_elder_provider.dart`, `dashboard_controller.dart`, `auth_repository.dart` (`updatePreferenceField`) | ADR-0027 | `dashboard_controller_test.dart` reescrito; guion de dos dispositivos de ADR-0027 §Verificación pendiente |
| Consentimiento del mayor: pregunta única tras elegir modo o vincularse, callable `setConversationConsent`, campo solo-servidor en reglas, retirada con periodo de gracia y borrado por TTL | HU-7 (memoria) | `features/privacy/`, `core/config/route_redirect.dart`, `functions/index.js`, `functions/conversation.js`, `firestore.rules` | ADR-0030 (cierra ADR-0016) | `router_redirect_test.dart`, `conversation.test.js`, `rules.test.js`; recorrido en dispositivo pendiente |
| Frontera de la conversación (inactividad o segundo plano) y búfer de turnos en memoria | HU-5/HU-6 | `chat_controller.dart`, `core/services/conversation_closer.dart`, `core/config/conversation_config.dart` | ADR-0028 | `chat_controller_test.dart`; dispositivo pendiente |
| Análisis al cierre en `closeConversation` (Vertex AI sin clave, salida estructurada, dos documentos, sin transcripción en reposo) | HU-6 | `functions/index.js`, `functions/conversation.js` | ADR-0029 (supera a ADR-0015) | `conversation.test.js` (34 casos, verdes con Node 18); requiere API de Vertex AI y política TTL activadas a mano |
| Niveles de lo que ve el familiar (`none` / `wellbeing` / `full`) impuestos por reglas | HU-7 (memoria) | `firestore.rules` (`companionMayRead`), `core/models/companion_sharing.dart`, `features/privacy/presentation/choice_screen.dart` | ADR-0031 | `rules.test.js` (48 casos en total contra emulador) |
| Memoria del mayor: cambios extraídos al cierre, `memory/profile`, inyección al empezar | HU-5 | `functions/conversation.js`, `core/services/gemini_service.dart`, `core/models/elder_memory.dart` | ADR-0032 | `conversation.test.js`, `gemini_memory_context_test.dart`; "vivo en Granada" en dispositivo pendiente |
| Panel de bienestar del familiar y pantalla "Mi semana" del mayor sobre la misma agregación | HU-6 | `core/utils/week_summary.dart`, `features/my_week/`, `dashboard/presentation/wellbeing_section.dart` | ADR-0033 | `week_summary_test.dart`, `my_week_text_test.dart`; dispositivo pendiente |
| Plazos configurables (inactividad 2–15 min, conservación 30–180 días acotada en el servidor) | HU-5/HU-6/HU-7 | `core/models/conversation_settings.dart`, `settings_rows.dart`, `dashboard/presentation/conversation_settings_card.dart` | ADR-0034 | `rules.test.js`, `conversation.test.js`; dispositivo pendiente |
| Conversación por escrito (modo teclado): mismo camino que el turno hablado, respuesta sin leer salvo "Escuchar" | HU-8 (memoria) | `features/conversation/domain/{chat_state,chat_controller}.dart`, `presentation/home_screen.dart` (rama `feat/modo-teclado`) | ADR-0035 | `chat_controller_test.dart`, `home_screen_test.dart`; sin verificar en dispositivo |
| Escucha: la sesión espera al resultado final (última palabra) y la pausa la elige el mayor ("Tiempo que te espero", 2–10 s) | HU-2/HU-3 | `core/services/speech_service.dart`, `core/config/preference_scales.dart`, `core/models/user_preferences.dart` | ADR-0036 (corrige ADR-0022) | `speech_service_test.dart`; verificación en dispositivo pendiente |

## Diseñado, no implementado (trabajo futuro)

| Capacidad | Documento de diseño | Por qué se difiere | Prerequisito |
|---|---|---|---|
| Proxy de Cloud Functions para aislar la clave del LLM en la conversación en vivo (RNF-8) | ADR-0014, PDF Stack §2 | **Parcial:** el análisis al cierre ya llama a Gemini desde el servidor sin clave (Vertex AI, ADR-0029); la conversación en vivo sigue con la clave del `.env` del cliente. El codebase `functions/` sirve cuatro callables: falta la del chat en vivo. **Es el último incumplimiento de seguridad declarado del proyecto** | Cuenta Blaze (activa) |
| Evaluación de impacto (EIPD, art. 35 RGPD) para un despliegue real | ADR-0030 §Consecuencias | Fuera del alcance académico; obligada con datos de salud de personas vulnerables | — |
| Opción "Borrarlo ya" al retirar el consentimiento | ADR-0030, epílogo | Cerraría la tensión con el art. 17.1.b | — |
| Solicitud remota del consentimiento (el familiar la pide, el mayor confirma) | ADR-0030, alternativas | Añade estado y reglas; la vinculación ya ofrece un momento presencial | — |
| Corrección de la memoria por el familiar o el mayor | ADR-0032, riesgos | Hoy solo se corrige si el mayor lo aclara en otra conversación | — |
| Notificaciones al familiar (inactividad, flag emocional, resumen semanal) | `pending.md` §6 | Depende de que existan datos que notificar | HU-6 (ADR-0029) + Cloud Function/FCM |
| Propagación del cambio de teléfono del familiar (`onDocumentUpdated`) | `pending.md` §3 | La desnormalización evita lecturas cross-user; propagación diferida | Cloud Functions |
| CI en GitHub Actions (analyze + test) | `pending.md` §5 | Prioridad baja | — |

---

## Divergencias plan/realidad

Afirmaciones de la documentación que el árbol de código no sostiene, con su motivo cuando es recuperable.

- **Nomenclatura de vinculación.** RF-2, `CLAUDE.md` y `test.md` hablan de un único `linkedPartnerId`; el
  código usa dos campos, `linkedCompanionId` (mayor) y `linkedElderId` (familiar) — hu1 §5.1.
- ~~**Emparejamiento "atómico server-side".**~~ **RESUELTA (2026-09-06, ADR-0024).** RF-2/RNF-9/`CLAUDE.md`
  lo describen mediado por servidor y durante cuatro meses estuvo implementado como transacción de cliente,
  en conflicto con `firestore.rules`. Hoy lo ejecuta la callable `validateAndLink` con credenciales de
  servidor; el cliente ya no escribe en el documento de otro usuario — ADR-0024, hu1 §5.2.
- ~~**Autoconfiguración del mayor independiente.**~~ **RESUELTA (2026-09-06, ADR-0021).** CU-05/RF-5 describen
  controles *más/menos* en el dispositivo del mayor y durante casi todo el proyecto solo existió la ruta remota
  (familiar), con una única fila en `settings_rows.dart`. Ya existen las tres escalas locales (tamaño de letra,
  volumen, velocidad), visibles para todo mayor y no solo para el independiente — hu3 §5.2, ADR-0021.
- **Proxy de Cloud Functions.** El PDF de Stack lo llama *"requisito de seguridad crítico"* y RNF-8 lo da por
  "previsto"; no está implementado, la clave vive en `.env` — ADR-0014.
- **Trazabilidad de RF-4.** La tabla de trazabilidad (TFG cap. 4) asigna a HU-3 `RF: ---`, pero la ficha de
  RF-4 declara `Origen: HU-2, HU-3` — hu3 §5.1.
- **`AutonomyStatus`.** Cuatro valores (`independent/dependent/linked/none`) frente a los dos de RF-1 — hu1 §6.
- **Stack "por determinar".** `README.md` presenta el stack como propuesto y el LLM "por determinar"; la
  realidad es Gemini + Firebase, bloqueados en `CLAUDE.md` — ADR-0002, ADR-0003.
- **Higiene documental.** `doc/plan/ACTIVE.md` contiene en realidad la *spec* del cambio de TTS (no un plan
  activo) y sigue sin archivar pese a que el trabajo está terminado; `scope.md` estaba vacío (este documento
  lo rellena); existía un ADR de TTS duplicado (eliminado). **Resuelto en parte (2026-09-26):** la *spec* del
  TTS se archivó en `doc/plan/archive/tts-chirp3-spec.md` y `ACTIVE.md` es ya el plan de HU-5/HU-6.
- **Numeración de las HU.** La memoria (cap. 3, tabla de HU; cap. 4, RF-7 y RF-8) define **HU-5 = memoria
  conversacional** (RF-7) y **HU-6 = seguimiento del estado de ánimo** (RF-8). `CLAUDE.md`, `pending.md`,
  `hu4-plan.md` §E, ADR-0015/0016 y versiones anteriores de este documento llamaban "HU-5" al análisis
  emocional y "HU-6" a "Mi semana". Se adopta la numeración de la memoria. Los documentos antiguos no se
  reescriben; `CLAUDE.md` ya está corregido.
- **HU-7 y HU-8 (2026-10-12).** La memoria (cap. 3 y 4) añade dos historias: **HU-7 = control del mayor sobre
  sus conversaciones** (consentimiento y qué ve el familiar; RF-9, CU-07) y **HU-8 = conversación por
  escrito** (modo teclado; RF-10, CU-10). Los ADR-0030, 0031 y 0034 presentan el consentimiento como requisito
  previo de HU-5/HU-6, y ADR-0035 encuadra el modo teclado en HU-2/HU-3; no se reescriben, porque los ADR son de
  solo adición. Para la memoria manda la nueva numeración.
- **ADR-0023 duplicado.** Dos ficheros comparten número: `0023-ciclo-de-vida-del-chatcontroller.md` y
  `0023-jdk-21-fijado-y-memoria-de-gradle-acotada.md`. No se renumeran, porque los ADR son de solo adición y
  el número puede estar citado. Las decisiones nuevas continúan en ADR-0027.
- **Copia única del mayor en el panel.** HU-4 describe la propagación en caliente de preferencias
  *familiar → mayor*, y funciona. La dirección contraria no existe: el panel lee el documento del mayor una
  sola vez y lo reescribe entero en cada deslizador, revirtiendo lo que el mayor haya cambiado desde entonces
  (ADR-0021) o fallando por las reglas. Diagnosticado el 2026-09-26; corrección diseñada en ADR-0027.
- **Fechas del cambio de voz.** Esta tabla y el capítulo 5 datan la migración de TTS entre el 25 y el 27 de
  julio de 2026, que es cuando se hizo el trabajo; el historial la fecha el **2026-09-06**, que es cuando se
  consolidó en el repositorio. Se registran las dos porque la regla del proyecto es que las fechas salen de
  `git log`, y aquí no coinciden.
- ~~**Reglas de seguridad sin auditar.**~~ **RESUELTA (2026-09-06, ADR-0025 y ADR-0026).** `pending.md` §1
  marcaba `firestore.rules` como *"probablemente en modo dev"*. Se reescribieron modelando operación por
  operación lo que hace el código, y se verifican con 29 casos contra el emulador. Queda pendiente ejecutar
  el recorrido manual extremo a extremo documentado en `firestore-tests/README.md`.
