# ADR-0004 — Arquitectura: modelo híbrido Clean Feature-Sliced (CFS)

- **Estado:** Aceptada
- **Fecha:** 2026-03-11 (estructura inicial; consolidada en `104eeca`, 2026-04-28)
- **Ámbito:** Organización de todo el código fuente. Implementado.
- **Decisores:** Autor del TFG.
- **Evidencia:** `doc/pdfs/Arquitectura Flutter_ FSD vs Feature-First.pdf` (fuente de confianza del autor);
  commits `f400e3c` (primera estructura `core/` + `features/`), `104eeca` (features con capas
  `data/domain/presentation`), `c117166` / INFO.md §8.4 (rotura de acoplamiento horizontal); `CLAUDE.md`
  (§Architecture, RNF-11).
- **Relacionada con:** ADR-0005 (Riverpod).

---

## Contexto

Un TFG lo evalúa un tribunal que valora el rigor de ingeniería, no solo que la app funcione. Se prevé
crecimiento modular (features de emergencia, ánimo, etc.). El enfoque *layer-first* se descarta por su
fricción cognitiva al escalar; el *feature-first* puro, por su propensión a acoplamientos cruzados.

## Decisión

Modelo híbrido **Clean Feature-Sliced (CFS)**: *slices* de funcionalidad (`features/<slice>/{data,domain,
presentation}`) sobre un núcleo transversal `core/`, con **flujo de dependencias unidireccional** y **sin
acoplamiento horizontal** entre features (lo compartido sube a `core/`). Se adopta la macro-estructura de
CFS pero con la **nomenclatura de Clean Architecture** (`presentation/domain/data`) en lugar de los segmentos
FSD (`ui/model/api/lib`), y con Riverpod en vez de BLoC (ADR-0005).

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Layer-first** (por tipo técnico) | Fricción cognitiva al escalar; *"carpetas con cientos de archivos"*. |
| **Feature-first puro** | Buena cohesión, pero *"carece de reglas estrictas... acoplamientos laterales y dependencias circulares"*. |
| **FSD estricto** (`ui/model/api/lib` + BLoC/GetIt) | Riesgo de sobreingeniería y curva de entrada elevada para el plazo de un TFG. |
| **CFS híbrido (elegida)** | Estructura estandarizada y testable sin la burocracia completa de FSD; pragmático. |

## Justificación

La fuente valora en FSD/CFS la modificabilidad *"Muy Alta"*, la testabilidad *"Alta"* y la mantenibilidad
*"Máxima"*, y advierte a la vez contra la **sobreingeniería académica** —mitigada aquí con una adopción
pragmática (naming Clean, sin `fpdart`/GetIt)—. La regla *"sin acoplamiento horizontal"* no es aspiracional:
se hizo cumplir en la estabilización rompiendo el acoplamiento `dashboard → onboarding` (INFO.md §8.4).

## Consecuencias

- **Positivas:** código autodocumentado, testable y preparado para crecer linealmente.
- **Negativas / coste asumido:** *boilerplate* de carpetas; la frontera *entity* vs *feature* puede
  difuminarse. Deuda conocida: `authRepositoryProvider` y `SignOutButton` cruzaron la frontera y se
  promovieron/aceptaron en `core/` (INFO.md §8.6).

## Verificación

La estructura `features/*/{data,domain,presentation}` + `core/` existe; el *test suite* aísla por slice; el
análisis estático (RNF-13) queda en 0 *warnings* en los archivos tocados.
