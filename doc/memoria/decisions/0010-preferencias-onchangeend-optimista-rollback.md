# ADR-0010 — Persistencia de preferencias desde el dashboard: `onChangeEnd` + actualización optimista con rollback

- **Estado:** Aceptada
- **Fecha:** 2026-04-28 (`96cfd57`, HU-4 Milestone 1)
- **Ámbito:** Escritura de preferencias del familiar hacia Firestore (HU-4). Implementado.
- **Decisores:** Autor del TFG.
- **Evidencia:** `hu4-plan.md` §1.1/§1.2, INFO.md §2/§3, `lib/features/dashboard/presentation/
  dashboard_screen.dart`, `lib/features/dashboard/domain/dashboard_controller.dart`, `test.md` §2;
  commit `96cfd57`.
- **Relacionada con:** ADR-0009 (SSOT), HU-4.

---

## Contexto

El familiar ajusta volumen, velocidad y tamaño de texto con deslizadores. `onChanged` se dispara decenas de
veces por segundo al arrastrar: escribir en Firestore en cada *tick* saturaría la red y agotaría la cuota
gratuita. Además, mostrar el valor como "guardado" antes de confirmar la escritura mentiría al usuario si
ésta falla.

## Decisión

Dos decisiones acopladas en el mismo camino de escritura: (1) la persistencia se dispara en **`onChangeEnd`**
—una sola escritura al soltar; `onChanged` solo actualiza el valor visual local—; (2) **actualización
optimista con rollback honesto** —la UI muestra el valor nuevo de inmediato, pero si `saveUser` falla el
controlador revierte `state.linkedElder` al snapshot previo y muestra el error—.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Escribir en `onChanged`** | Amplificación de escrituras; coste y saturación de red. |
| **UI optimista sin rollback** | La UI mostraría un valor que no llegó a persistir (miente al familiar). |
| **`onChangeEnd` + optimista con rollback (elegida)** | Una escritura por gesto y estado siempre veraz. |

## Justificación

Los dos ejes son el coste de Firestore y la honestidad de la UI. El rollback revierte el estado y
`_SettingSlider` reconcilia el valor visual en `didUpdateWidget` cuando no se está arrastrando (INFO §2).

## Consecuencias

- **Positiva:** una escritura por ajuste; el familiar siempre ve el estado real.
- **Negativa / coste:** lógica de reconciliación en `_SettingSlider` (estado de arrastre vs. cambio externo).

## Verificación

`dashboard_controller_test.dart`: *happy path* (una sola llamada a `saveUser`), rollback ante error (revierte
`linkedElder` + fija `errorMessage`) y no-op si no hay elder vinculado (`test.md` §2).
