# ADR-0013 — Configuración de accesibilidad explícita (cuidador/mayor) frente a adaptación automática por IA

- **Estado:** Aceptada
- **Fecha:** 2026-04-28 (materializada en HU-4)
- **Ámbito:** Modelo de accesibilidad (HU-3/HU-4). Implementado por ambas rutas: dashboard del familiar y controles locales del mayor (ADR-0021).
- **Decisores:** Autor del TFG.
- **Evidencia:** `doc/pdfs/Solución Propuesta - Historias de Usuario.pdf` (controles *más/menos*),
  `CLAUDE.md` (§Accessibility), HU-3, HU-4, `lib/features/dashboard/`.
- **Relacionada con:** ADR-0007 (revelación progresiva), ADR-0021 (materializa los controles locales), HU-3.

---

## Contexto

La accesibilidad (tamaño de texto, volumen, velocidad de voz) debe adaptarse a cada mayor. Una app
"inteligente" podría intentar inferir y **autoajustar** estos parámetros. Pero para un colectivo vulnerable,
un cambio de interfaz no solicitado es desorientador, y la inferencia puede equivocarse sin que el usuario
sepa por qué cambió su pantalla.

## Decisión

La adaptación es **explícita y controlada por un humano**, nunca automática por IA: el familiar ajusta los
parámetros desde su panel remoto (HU-4) y el mayor independiente los ajusta con **controles simples de
incremento/decremento** ("más/menos", "Letra más grande/normal") en su propio dispositivo. La IA no modifica
la accesibilidad.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Accesibilidad autoadaptativa por IA** | Cambios no solicitados desorientan; inferencia opaca y falible; erosiona la confianza del mayor. |
| **Configuración explícita humana (elegida)** | Control predecible y transparente; el cambio siempre lo pide una persona. |

## Justificación

El PDF de solución prescribe controles explícitos *"sin necesidad de deslizar"* (más/menos) y un lenguaje de
diseño accesible; `CLAUDE.md` refuerza la simplicidad y la ausencia de gestos. Para esta población, la
predecibilidad prima sobre la "inteligencia".

## Consecuencias

- **Positiva:** interfaz predecible; el mayor o su familiar mandan siempre.
- **Negativa / coste:** los controles locales del mayor quedaron **sin implementar durante casi todo el
  proyecto** — hasta 2026-09-06 solo el familiar ajustaba desde el dashboard (HU-3 §5.2). **Deuda saldada por
  ADR-0021**, que los materializa como escalas discretas de peldaños con nombre (el `Slider` del panel no era
  reutilizable: exige arrastre). Ambas rutas, remota y local, funcionan ya.

## Verificación

La propagación remota familiar→mayor funciona (HU-4, `dashboard_controller_test.dart`). Los controles locales
del mayor se implementaron en ADR-0021 (`core/config/preference_scales.dart`); su verificación es manual en
dispositivo y queda pendiente.
