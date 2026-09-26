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

## Epílogo — respuesta propuesta (2026-09-26)

La cuestión abierta de este ADR tiene respuesta **propuesta** en **ADR-0030**. Se cerrará cuando el autor
confirme los tres puntos que ese ADR deja marcados.

- **¿El *opt-in* cubre el envío de la transcripción al análisis?** Sí, y se dice expresamente en el texto del
  consentimiento: lo hablado se envía a Google para analizarse y no se guarda. El análisis pasa a hacerse en
  una callable (ADR-0029), así que el salto que este ADR describía (cliente → proveedor) es ahora cliente →
  Function del proyecto → proveedor, y también se declara.
- **¿Quién consiente?** Siempre el mayor, en su dispositivo, con un gesto explícito. El familiar no puede
  hacerlo por él: la vinculación no le convierte en representante legal. En modo vinculado se pregunta justo
  tras la vinculación, que suele ser presencial, para que el familiar pueda explicarlo sin decidir.
- **¿Cómo se recoge y se retira?** Una pantalla con dos botones grandes, registrada por una callable con la
  hora del servidor. Se retira en Ajustes con la misma facilidad, y retirarlo borra todo lo guardado.

La alternativa *"resumen extractivo/local sin segunda llamada al LLM"* sigue sin diseñar y no se retoma: el
análisis emocional de HU-6 no se puede hacer de forma extractiva.
