# ADR-0014 — Proxy de Cloud Functions para aislar la clave del LLM (diseñado, no implementado)

- **Estado:** Propuesta
- **Fecha:** 2026-03-11 (documentado en la *Justificación del Stack*; sin implementar)
- **Ámbito:** Seguridad de credenciales del LLM. **Diseñado, no implementado.**
- **Decisores:** Autor del TFG.
- **Evidencia:** `doc/pdfs/Justificación del Stack Tecnológico.pdf` §2 (*"requisito de seguridad crítico"*),
  TFG RNF-8, `lib/core/services/gemini_service.dart` (usa `.env`), ausencia de carpeta `functions/`,
  `pending.md` §1 (reglas sin auditar).
- **Relacionada con:** ADR-0002 (LLM), ADR-0003 (Firebase), ADR-0008 (emparejamiento).

---

## Contexto

La app llama al LLM. Si la clave de API viaja en el binario del cliente, queda expuesta a extracción. La
fuente del autor lo califica de *"requisito de seguridad crítico"*: el frontend nunca debe conectarse
directamente al LLM.

## Decisión (propuesta)

Enrutar las llamadas al LLM (y las escrituras *cross-user*, ADR-0008) a través de **Cloud Functions** que
custodien la clave con las credenciales del entorno (ADC), de modo que el cliente nunca la vea. **Aún no
implementado:** hoy la clave vive en `.env` en el cliente vía `flutter_dotenv`.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Clave en el cliente** (estado actual) | Simple, pero expone la credencial; incumple RNF-8. Aceptable solo en desarrollo. |
| **Migración a Vertex AI / SDK server** | Cambio de proveedor mayor; fuera del alcance actual. |
| **Proxy de Cloud Functions (elegida como objetivo)** | Aísla la clave sin cambiar de proveedor; reutiliza el proyecto GCP. |

## Justificación

Reutiliza la infraestructura Firebase/GCP ya elegida (ADR-0003) sin introducir un proveedor nuevo. Es el
mismo patrón que resolvería la tensión de seguridad del emparejamiento (ADR-0008).

## Consecuencias

- **Positiva (al implementar):** cumpliría RNF-8 y RNF-9; una sola pieza server-side resolvería la clave del
  LLM y las escrituras *cross-user*.
- **Negativa / estado:** **mientras no exista, RNF-8 no se cumple.** → `scope.md` (tabla 3).

## Verificación

No aplica: no hay artefacto. Criterio de cierre futuro: la clave no aparece en el cliente (`grep`) y las
llamadas pasan por la callable.

## Epílogo — primera llamada al LLM fuera del cliente (2026-09-26)

ADR-0029 diseña `closeConversation`, que será la **primera llamada a Gemini que no use la clave del cliente**:
el análisis de cada conversación al cerrarse. Se hará con Vertex AI y las credenciales del entorno (el mismo
mecanismo que ya usa Cloud TTS) o, si el modelo no está disponible en la región, con la clave en Secret
Manager.

Este ADR **no se cierra** con eso: el canal conversacional en vivo sigue llamando a Gemini desde el cliente con
la clave del `.env`, y RNF-8 sigue incumplido mientras sea así. Lo que cambia es que migrar el chat en vivo ya
no exigirá decidir cómo llama el servidor a Gemini: estará resuelto y probado en `closeConversation`.
