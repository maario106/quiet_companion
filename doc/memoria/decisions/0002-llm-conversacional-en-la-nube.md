# ADR-0002 — Inteligencia conversacional: LLM en la nube frente a modelos locales (on-device)

- **Estado:** Aceptada
- **Fecha:** 2026-03-11
- **Ámbito:** Núcleo conversacional (HU-2). Implementado; proveedor concreto: Gemini (`gemini-2.5-flash`).
- **Decisores:** Autor del TFG.
- **Evidencia:** `doc/pdfs/Justificación del Stack Tecnológico.pdf` §3 (fuente de confianza del autor);
  commit `f400e3c` (*API Gemini Integrada*, 2026-03-11); `708d71a` (nombre aprendido vía *function calling*);
  `lib/core/services/gemini_service.dart`; `pubspec.yaml` (`google_generative_ai`); `CLAUDE.md` (§Stack).
- **Relacionada con:** ADR-0003 (Firebase BaaS); ADR pendiente sobre **proxy de Cloud Functions para
  aislamiento de la clave de API** (diseñado, no implementado); ADR pendiente sobre selección de proveedor
  concreto (Gemini frente a otros LLM en la nube).

---

## Contexto

La propuesta de valor del producto es una conversación **empática** con el mayor; la calidad del modelo de
lenguaje es, por tanto, el núcleo funcional. El hardware del público objetivo condiciona la decisión: el
segmento *Silver Economy* tiende a poseer *"dispositivos de gamas de entrada o con varios años de
antigüedad"*, sin unidad de procesamiento neuronal (NPU) ni memoria suficiente para inferencia neuronal
local. Además, dotar a un modelo de un tono clínico/de acompañamiento exigiría un *fine-tuning* con un
volumen de datos conversacionales del que no se dispone en el ámbito de un TFG. El coste operativo debe
tender a cero a escala de pruebas.

## Decisión

La capacidad conversacional se delega en una **API de LLM en la nube**, descartando el despliegue y
entrenamiento de un modelo de código abierto local (LLaMA, Mistral). La fuente del autor deja abierta la
familia concreta (*"GPT-4o-mini, Claude 3 Haiku o Gemini Flash"*); en implementación se seleccionó **Gemini
(`gemini-2.5-flash`)** a través del paquete `google_generative_ai`. El comportamiento empático no se logra
reentrenando la red, sino con **Prompt Engineering** (`systemInstruction` + `safetySettings`) y **RAG
parcial**: inyectando el contexto del usuario guardado en Firebase antes de cada interacción.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Modelo abierto local / on-device** (LLaMA, Mistral) | *"Ejecutar un LLM en el propio dispositivo requiere teléfonos móviles de alta gama con NPU y gran cantidad de RAM"*; consumiría batería y recursos, degradando la experiencia en el hardware real del público objetivo. |
| **Fine-tuning de un modelo propio** | Requiere *"un volumen masivo de datos conversacionales estructurados de los que no se dispone en el ámbito de este TFG"*. |
| **LLM en la nube (elegida)** | Delega la carga computacional pesada; el tono empático se consigue por Prompt Engineering + RAG parcial, no por reentrenamiento. |

## Justificación

Citas literales de la fuente del autor (§3): las **restricciones de hardware (Edge AI)**, la **inviabilidad
del fine-tuning** y la **eficiencia y escalabilidad** de delegar el cómputo a la nube. La decisión es
coherente con ADR-0001 (Android de gama media-baja como plataforma objetivo): no tendría sentido elegir un
framework por su alcance a dispositivos modestos y luego exigirles inferencia neuronal local.

## Consecuencias

**Positivas:**
- Cómputo pesado fuera del dispositivo; funciona en el hardware modesto del público objetivo.
- El *function calling* de Gemini habilitó una decisión de producto posterior (el mayor nunca teclea su
  nombre; el modelo lo aprende por voz — `708d71a`, HU-1/HU-5).

**Negativas / coste asumido:**
- Dependencia de red y de un servicio externo (RNF-14: degradación controlada ante pérdida de conectividad).
- **Los datos del mayor salen del dispositivo** en cada interacción; debe tratarse en el capítulo de RGPD.
- **La clave de la API reside hoy en el cliente** vía `flutter_dotenv` (`.env`). La fuente del autor describe
  el proxy de Cloud Functions como *"requisito de seguridad crítico"* y RNF-8 lo marca como *"prevista la
  migración"*: es **diseño, no realidad**. → ADR dedicado + entrada en `scope.md` (tabla 3).

> **UNRESOLVED — requiere decisión del autor:** la selección del **proveedor concreto** (Gemini frente a
> GPT-4o-mini o Claude Haiku) está evidenciada por el código pero su justificación (capa gratuita,
> multimodalidad, soporte de *function calling*) no está documentada en la fuente. ¿Se redacta un ADR de
> selección de proveedor, o se cita el criterio en el capítulo de diseño?

## Verificación

El pipeline de voz de HU-2 (STT → Gemini → TTS) funciona con Gemini. El *function calling* (`guardarNombre`)
se verificó en `708d71a`. La clave sigue en el cliente (`.env`): **RNF-8 aún no cumplido**.

## Epílogo — el "RAG parcial" toma forma (2026-09-26)

La decisión anunciaba *"RAG parcial: inyectando el contexto del usuario guardado en Firebase antes de cada
interacción"*. Hasta ahora ese contexto era solo el nombre. ADR-0032 lo diseña completo: una memoria de datos
estables y resúmenes recientes, extraída al cerrar cada conversación e inyectada en el `systemInstruction` **al
empezar cada conversación** (no antes de cada turno: el `systemInstruction` ya viaja en todos los turnos de la
sesión). Se confirma de paso lo que esta decisión daba por supuesto: la API de Gemini no guarda estado entre
llamadas, y cualquier memoria entre conversaciones tiene que guardarla y entregarla la app.
