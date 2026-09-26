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

## Epílogo — el *rollback* cambia de mecanismo (2026-09-26)

ADR-0027 detecta que el camino de escritura de este ADR parte de una copia del mayor leída una sola vez y la
reescribe entera con `saveUser`. Desde que el mayor escribe sus propios ajustes (ADR-0021), eso revierte sus
cambios o hace fallar la escritura. Cuando ADR-0027 se implemente:

- **`onChangeEnd` se mantiene** tal cual: una escritura por gesto.
- **La honestidad de la interfaz se mantiene, pero el *rollback* manual desaparece.** El panel pintará desde
  un *stream* del documento del mayor, y la compensación de latencia de Firestore ya muestra el valor escrito
  al instante y lo revierte si el servidor lo rechaza. El controlador solo tendrá que mostrar el error.
- `saveUser` deja de usarse para editar: el panel escribe cada campo con `update()`.

Al implementarse, este ADR pasará a *Superseded by ADR-0027* en lo relativo al mecanismo de *rollback*.
