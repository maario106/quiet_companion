# ADR-0015 — Persistencia conversacional: solo resúmenes, sin transcripciones crudas en reposo (diseñado)

- **Estado:** Superseded by ADR-0029 (2026-09-26)
- **Fecha:** 2026-07-12 (diseño en `pending.md` §4 / `hu4-plan.md` §C)
- **Ámbito:** Persistencia de conversaciones (prerequisito de HU-5). **Diseñado, no implementado.**
- **Decisores:** Autor del TFG.
- **Evidencia:** `hu4-plan.md` §C, `pending.md` §4, TFG RNF-10 (RGPD, minimización de datos).
- **Relacionada con:** ADR-0016 (salida de datos para el resumen), ADR-0014 (Cloud Functions), HU-5.

---

## Contexto

Las conversaciones con Gemini son hoy efímeras: al cerrar la app se pierden y no hay nada que analizar
después (HU-5). Pero el sujeto es una población vulnerable y aplica el RGPD (minimización de datos, RNF-10).

## Decisión (propuesta)

Persistir en `users/{uid}/conversations/{id}` únicamente `{ startedAt, endedAt, summary, messageCount }` —un
**resumen generado por Gemini**, nunca la transcripción cruda—. El resumen se produce **en cliente** (la
transcripción vive solo en memoria durante la sesión) y se dispara al fin de sesión
(`AppLifecycleState.paused` + timeout de inactividad). El prompt de resumen se diseña antes con
`gemini-prompt-architect`.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Persistir la transcripción cruda** | Máximo contexto para HU-5, pero choca con la minimización de datos (RGPD) en un colectivo vulnerable. |
| **Resumen vía Cloud Function** | Exigiría subir la transcripción a la nube (contradice *"no persistirla"*); infraestructura extra sin beneficio claro a esta escala (`pending.md` §4). |
| **Resumen en cliente, persistir solo el resumen (elegida)** | Minimiza los datos en reposo; argumento fuerte de RGPD para la memoria. |

## Justificación

Guardar solo el resumen es un argumento directo de minimización de datos ante el tribunal. Hacer el resumen
en cliente evita subir la transcripción cruda a la nube, coherente con la regla de no persistirla.

## Consecuencias

- **Positiva (al implementar):** base para HU-5 con huella de datos mínima.
- **Negativa / riesgo:** si Android mata la app antes de completar la llamada de resumen, esa sesión se pierde
  (se pierde un resumen, no datos del usuario — aceptado).
- Abre ADR-0016: la transcripción **sí** sale al LLM para resumirse.

## Verificación

No aplica (diseño). Criterio futuro: `conversations/{id}` contiene resumen y metadatos, nunca los mensajes
crudos.

## Epílogo — qué se conserva y qué no (2026-09-26)

Esta decisión queda **superada por ADR-0029**, pero solo en parte, y conviene separar las dos mitades:

- **Se conserva**, y se amplía, el principio: **nunca se persiste la transcripción cruda**. Lo que se guarda
  sigue siendo el resultado del análisis (resumen, ánimo, señales, temas), ahora repartido en dos documentos
  para que las reglas puedan decidir qué ve el familiar (ADR-0031).
- **No se conserva** el lugar: el análisis ya no se hace **en el cliente**, sino en una callable,
  `closeConversation`. El motivo del rechazo de la tabla de arriba —*"exigiría subir la transcripción a la
  nube (contradice no persistirla)"*— mezclaba transmitir con almacenar. La transcripción ya viaja a Google
  en cada turno, y una Function que no la escribe no añade ni destinatario ni almacenamiento. Lo que sí añade
  el servidor es poder corregir el prompt sin publicar la app y sacar la llamada de la clave del cliente
  (ADR-0014).

El disparador de fin de sesión (`paused` + inactividad) se mantiene y se formaliza en ADR-0028. El riesgo
aceptado aquí —si Android mata la app antes de la llamada, se pierde esa conversación— sigue aceptado.
