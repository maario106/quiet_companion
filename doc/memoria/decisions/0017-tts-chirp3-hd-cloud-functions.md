# ADR-0017 — Sustitución del TTS nativo del dispositivo por Google Cloud TTS (Chirp 3: HD) vía proxy de Cloud Functions

- **Estado:** Aceptada (implementada el 2026-07-25; despliegue pendiente)
- **Fecha:** 2026-07-17
- **Ámbito:** Capa de síntesis de voz del companion (HU-2, chat de voz)
- **Decisores:** Autor del TFG
- **Relacionada con:** ADR-0014 (proxy de Cloud Functions para la clave del LLM); ADR-0018 (creación del codebase de Functions); ADR-0019 (preferencias de voz en el reproductor); principio de arquitectura aditiva; congelación de arquitectura post-pruebas de usuario

---

## Contexto

La voz es la interfaz primaria de la aplicación para el usuario mayor: toda la propuesta de valor del companion pasa por una conversación hablada. La implementación actual usa el motor TTS nativo de Android (`flutter_tts`), cuya calidad depende del motor instalado en cada dispositivo y que, en la práctica, produce una voz perceptiblemente robótica y artificial.

Esto plantea dos problemas:

1. **Calidad de experiencia.** Para una población mayor, una voz sintética poco natural reduce la confianza, la inteligibilidad y la disposición a conversar. La literatura de interacción persona-agente y la propia intuición de producto coinciden: la calidad percibida de la voz condiciona la percepción de todo el sistema.
2. **Contaminación de las pruebas de usuario.** Las pruebas de usabilidad de HU-1→4 evaluarán inevitablemente la voz junto con el flujo conversacional. Con una voz robótica, las observaciones medirían la voz, no la UX. Por ello esta decisión debe implementarse **antes** de las pruebas de usuario y de la congelación de arquitectura, pese a que técnicamente toca el camino conversacional en vivo.

Restricciones aplicables:

- **Coste:** proyecto de TFG sin financiación; el coste operativo debe ser ~0 € a la escala de pruebas y demo.
- **Seguridad:** ninguna clave de API puede residir en el cliente (decisión ya tomada con el proxy de Cloud Functions para Gemini; este ADR la reutiliza).
- **Latencia y previsibilidad de UX:** requisitos no negociables para la población objetivo. Introducir red en la síntesis de voz exige mitigación explícita.
- **Arquitectura aditiva:** el cambio debe realizarse detrás de una abstracción, sin reescribir el flujo de conversación existente y ya probado.

## Decisión

Se sustituye la síntesis nativa del dispositivo por **Google Cloud Text-to-Speech con voces Chirp 3: HD (es-ES)**, invocado desde el cliente a través de una **nueva callable en el proxy de Cloud Functions existente**, detrás de una **abstracción `TtsService`** en el cliente Flutter.

Elementos de la decisión:

1. **Interfaz `TtsService`** en `core/services/`, con el mismo patrón interfaz + fake ya usado en `EmergencyCallService`: implementación de producción (`CloudTtsService`), implementación de respaldo (`DeviceTtsService`, envolviendo el motor nativo actual) y fake para tests.
2. **Callable `synthesizeSpeech`** en el mismo codebase Node.js del proxy. La función usa las credenciales por defecto del entorno de Cloud Functions (ADC): no se introduce ninguna clave nueva ni en cliente ni en configuración.
3. **Troceado por frases (sentence chunking):** la respuesta del LLM se divide en frases; se sintetiza y reproduce la primera mientras se sintetizan las siguientes. Mantiene el tiempo hasta el primer audio en un rango aceptable (~300–700 ms) sin necesidad de streaming gRPC.
4. **Política de respaldo sin reintentos:** si la síntesis en nube falla o supera el timeout, esa locución se reproduce con el TTS del dispositivo. No hay reintentos con backoff, en coherencia con la decisión previa de rechazar el backoff exponencial como patrón de UX para esta población: es preferible una voz peor pero inmediata a un silencio impredecible.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Mantener TTS nativo (`flutter_tts`)** | Calidad insuficiente y no determinista entre dispositivos; contaminaría las pruebas de usuario. Se conserva únicamente como respaldo offline/error. |
| **Gemini-TTS (TTS nativo del LLM)** | Dirección prometedora (estilo dirigible por prompt: "habla despacio y con calidez"), pero sin capa gratuita, con precio por token y mayor latencia. Documentada como trabajo futuro. |
| **Azure Neural TTS** | Calidad comparable y capa gratuita (F0, 0,5M caracteres/mes), pero introduce un segundo proveedor cloud en una arquitectura puramente Firebase/GCP sin ganancia funcional: más superficie de credenciales, facturación y explicación en la defensa. |
| **ElevenLabs** | La mayor expresividad del mercado, pero modelo de suscripción y capa gratuita (~10k caracteres/mes) incompatible con el perfil de coste del proyecto. |
| **OpenAI TTS** | Sin capa gratuita (15 $/1M caracteres) y voces optimizadas para inglés. |
| **Modelos abiertos en dispositivo (Kokoro, etc.)** | Coste por carácter nulo, pero la inferencia neuronal en los dispositivos de gama baja habituales entre mayores es un riesgo de latencia y batería, y complica el empaquetado Flutter. |
| **Gemini Live API (conversación de audio nativa bidireccional)** | Es el estado final "correcto" de un companion de voz, pero sustituye por completo el pipeline STT→LLM→TTS actual: incompatible con la congelación de arquitectura y con el presupuesto. Trabajo futuro principal de esta línea. |

## Justificación

- **Coste:** Chirp 3: HD dispone de una capa gratuita de 1M caracteres/mes (después, 30 $/1M). Un usuario mayor con ~30 min de conversación diaria genera del orden de 60–80k caracteres sintetizados al mes: la capa gratuita cubre holgadamente las pruebas de usuario y la demo del TFG.
- **Coherencia arquitectónica:** misma cuenta y proyecto GCP que Firebase; el patrón de proxy ya resuelto para Gemini se extiende sin decisiones nuevas de seguridad. El cambio es aditivo: el flujo de chat invoca una abstracción y solo cambia la implementación tras ella.
- **Calidad:** las voces Chirp 3: HD ofrecen prosodia natural y resonancia emocional en es-ES, un salto cualitativo (no incremental) frente al motor del dispositivo.

## Consecuencias

**Positivas:**
- Mejora perceptible e inmediata de la propiedad más visible de la aplicación para el usuario final.
- Cero coste operativo a escala de TFG; coste marginal conocido y acotado si el proyecto escalara.
- El patrón `TtsService` deja preparada la migración futura (Gemini-TTS, Live API) sin tocar el flujo conversacional.

**Negativas / riesgos asumidos:**
- La síntesis pasa a depender de la red. Mitigación: respaldo automático al TTS del dispositivo por locución, sin reintentos.
- Latencia añadida por el doble salto (cliente → Function → API TTS). Mitigación: troceado por frases; el streaming gRPC queda descartado por complejidad a esta escala y documentado como optimización futura.
- Coste variable si el número de usuarios superara la capa gratuita (~12–15 usuarios activos diarios). Aceptado: fuera del alcance del TFG.
- Los caracteres sintetizados transitan por la Function. No se persiste ningún contenido de conversación en este camino (coherente con la política de minimización de datos del proyecto), pero debe mencionarse en el capítulo de RGPD como tratamiento adicional del mismo dato ya tratado por el proxy de Gemini, con la misma base jurídica.

## Notas de implementación

Especificación técnica: `doc/plan/ACTIVE.md`. Verificación manual pendiente tras el despliegue: calidad y latencia percibida en dispositivo físico de gama baja con red móvil, y comportamiento del respaldo con el modo avión.

### Añadido el 2026-07-25 (implementación)

Al implementar aparecieron tres hechos que el ADR daba por resueltos y no lo estaban. Se registran aquí sin
reescribir la decisión, que no cambia:

1. **El "proxy de Cloud Functions existente" no existía.** ADR-0014 estaba en estado *Propuesta* y no había
   carpeta `functions/`. La callable `synthesizeSpeech` no se pudo *añadir* a un codebase: hubo que crearlo.
   La decisión de crearlo con una sola función, en vez de aprovechar para migrar Gemini, es ADR-0018.
2. **Voz elegida: `es-ES-Chirp3-HD-Sulafat`.** El catálogo Chirp 3: HD ofrece 30 voces en es-ES; `Sulafat`
   es la única que Google describe como *Warm*. Alternativas anotadas en `functions/index.js`. No se pudo
   enumerar con `listVoices()` contra el proyecto (sin `gcloud` ni credenciales locales), así que la
   verificación queda como paso manual: `npm run list-voices` en `functions/`.
3. **Las preferencias de voz del familiar** (volumen y velocidad, HU-4) habrían dejado de funcionar en el
   camino de nube, porque el cliente no envía parámetros de síntesis. Se resuelven en el reproductor:
   ADR-0019.

El troceado, el prefetch de uno y la cancelación por generación quedan cubiertos por
`test/core/services/cloud_tts_service_test.dart` y `test/core/utils/sentence_splitter_test.dart`.

### Añadido el 2026-07-27 (fallo de secuenciación en dispositivo)

En la primera escucha real con respuestas de varias frases se oía la primera frase y la última: los
fragmentos intermedios se cortaban. La causa no estaba en el troceado sino en la costura del reproductor.

`just_audio` documenta que el futuro de `play()` **completa de inmediato si el reproductor ya está
reproduciendo**, y que `playing` sigue siendo `true` después de cada pista (solo `pause()` o `stop()` lo
bajan). Es decir: el futuro de `play()` solo es una señal de fin válida para la primera pista. A partir de
la segunda volvía al instante, el bucle avanzaba y el `setAudioSource` del fragmento siguiente cortaba al
anterior. La secuenciación pasa a esperar `processingStateStream` (`completed` o `idle`), con un tope de
espera basado en la duración de la pista para que un evento perdido no congele la conversación en
"hablando".

**Lección para la memoria:** los tests no podían detectarlo y no fue un descuido de cobertura. El doble de
`TtsAudioPlayer` cumple el contrato "completa cuando termina de sonar" por construcción; el que lo
incumplía era el plugin real. Toda la lógica de orquestación era correcta y estaba verde. En una costura
con un plugin, el test protege del error propio, no de una suposición equivocada sobre la librería: eso
solo lo dice el dispositivo. Es el mismo patrón que ADR-0020, encontrado en la misma sesión de pruebas.