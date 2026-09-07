# ADR-0016 — La transcripción sale al proveedor del LLM para resumirse aunque no se persista: cuestión de consentimiento

- **Estado:** Propuesta (decisión de consentimiento **pendiente**)
- **Fecha:** 2026-07-12
- **Ámbito:** Privacidad del tratamiento conversacional (prerequisito de HU-5). **Diseñado, sin resolver.**
- **Decisores:** Autor del TFG.
- **Evidencia:** `hu4-plan.md` §C y §D.6, `pending.md` §4, TFG RNF-10 (RGPD; *opt-in* desactivado por
  defecto).
- **Relacionada con:** ADR-0015 (resumen-solo), ADR-0002 (LLM en la nube).

---

## Contexto

ADR-0015 minimiza los datos **en reposo** (solo resúmenes). Pero para generar el resumen —y en la extensión
híbrida D.6, para el barrido de contexto post-sesión— la **transcripción completa en memoria se envía al
proveedor del LLM** en una segunda llamada. Ya durante la conversación en vivo el texto va a Gemini turno a
turno; el resumen añade un tratamiento más del mismo dato.

## Decisión (parcial)

Se reconoce explícitamente que "no persistir" **no equivale a** "no procesar en la nube": la transcripción
sale al proveedor para resumirse. La política del proyecto es **opt-in desactivado por defecto** (RNF-10)
para el registro; queda por decidir si ese consentimiento cubre también el envío del transcript completo al
resumen/barrido, y quién lo otorga.

> **UNRESOLVED — requiere decisión del autor:** ¿el consentimiento *opt-in* abarca el envío de la
> transcripción completa a una segunda llamada al LLM (resumen y, opcionalmente, barrido D.6)? ¿Quién
> consiente —el mayor como titular, el familiar como tercero— y cómo se recoge y revoca? Debe cerrarse antes
> de implementar HU-5.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Presentar "resumen-solo" como si resolviera la privacidad** | Deshonesto: el transcript completo sí sale a la nube para resumirse. |
| **Resumen extractivo/local sin segunda llamada al LLM** | Evitaría la salida extra, pero de menor calidad; no está diseñado. |
| **Reconocer la tensión y condicionarla a consentimiento explícito (elegida, parcial)** | Honesta; deja la decisión de consentimiento registrada como pendiente. |

## Consecuencias

- **Positiva:** la memoria del TFG trata la privacidad con honestidad (no la presenta como resuelta).
- **Negativa / estado:** bloquea la implementación de HU-5 hasta cerrar el modelo de consentimiento.

## Verificación

No aplica (diseño). Criterio futuro: existe un flujo de consentimiento *opt-in* documentado que cubre
explícitamente el envío del transcript al resumen.
