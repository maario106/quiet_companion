# Instrucciones — Capítulo 5: «Diseño y Desarrollo»

> **Audience:** Claude Code, running locally with full access to `/home/mario/quiet_companion`.
> **Deliverable:** the full text of `doc/tfg/capitulos/05_Diseño_Desarrollo.tex`, written in **Spanish**, ready to `\include` from `proyecto.tex` and to compile in isolation.
> **These instructions are in English on purpose (better agent performance). ALL generated `.tex` content — headings, prose, captions, table cells — must be in Spanish (es-ES).**

---

## 0. Non-negotiables (read before touching anything)

1. **Accuracy over impression.** Nothing is described as "implemented / done / working" unless you have confirmed it *in the code*. The author's docs may be stale. See §3 (Verification protocol). When in doubt, downgrade the claim and add a `**note:**`.
2. **Single chapter.** Produce one chapter, `5. Diseño y Desarrollo`. Do **not** split. Do **not** renumber `06_Desarrollo_Futuro.tex`.
3. **Language:** Spanish. Sober academic register. Match the author's existing voice (see §9), do not invent a new one.
4. **Citations:** `biblatex` APA. Use `\textcite{clave}` for author-prominent references and `\autocite{clave}` for parenthetical ones. Every new reference goes into `doc/tfg/bibliografia.bib`. Never cite a source you have not verified exists.
5. **Pending-decision convention:** keep the author's `**note:** [...]` markers inline for anything still open (latency thresholds, GDPR detail, connectivity-loss UX, unresolved design choices).
6. **Do not duplicate other chapters.** Methodology/Kanban lives in ch. 3; requirements & HU specs in ch. 4. Reference them (`\autoref`/`\ref`) instead of repeating. Read ch. 3 and ch. 4 first to align terminology and voice.
7. **LaTeX hygiene:** touch only source files. Do **not** create/edit `.aux/.bbl/.bcf/.blg/.log/.toc` etc. Note: the repo contains stale artifacts (`proyecto..bbl`, `proyecto.bbl-SAVE-ERROR`, duplicate `imagenes/proyecto.tex`, duplicate `imagenes/bibliografia.bib`) — **ignore them, do not read them as truth, do not write to them.** Confirm the canonical main file is `doc/tfg/proyecto.tex` and the canonical bib is `doc/tfg/bibliografia.bib` (check its `\addbibresource`).

---

## 1. Files to read first (build context before writing)

Read, in this order:

- `CLAUDE.md` (root) — locked scope HU-1→HU-4, stack versions, architecture rules, data model.
- `doc/memoria/scope.md`, `doc/memoria/timeline.md`
- `doc/memoria/hu/hu1-onboarding.md`, `hu3-accessibility.md`, `hu4-adaptive-config.md`
- **All 20 ADRs** in `doc/memoria/decisions/0001…0020-*.md`
- `doc/pdfs/Justificación del Stack Tecnológico.pdf`, `Solución Propuesta - Historias de Usuario.pdf`, `Arquitectura Flutter_ FSD vs Feature-First.pdf`
- `doc/plan/ACTIVE.md`, `doc/plan/archive/hu4-plan.md`
- Existing chapters `doc/tfg/capitulos/03-*.tex` and `04-*.tex` (for tone + cross-refs)
- The actual source tree under `lib/` — this is the ground truth for §3.

---

## 2. Chapter outline (target structure)

Use this section skeleton. Titles are Spanish and final. Adjust depth per available material, but keep the order.

```
\chapter{Diseño y Desarrollo}

5.1 Introducción del capítulo            (qué cubre, relación diseño↔desarrollo)

-- PARTE I: DISEÑO --
5.2 Filosofía y principios de diseño
    5.2.1 Diseño centrado en la persona mayor (soledad no deseada → requisitos)
    5.2.2 Revelación progresiva como principio rector
5.3 Accesibilidad
    5.3.1 Cumplimiento WCAG 2.2 AA (objetivos y alcance)
    5.3.2 Decisiones de interacción (targets ≥80×80, tap-only, sin swipe/long-press/doble toque)
    5.3.3 Tipografía y escalado dinámico (20sp cuerpo / 28sp títulos, textSizeMultiplier)
    5.3.4 Teoría del color aplicada a personas mayores   (breve, con fuentes)
5.4 Evolución del diseño de interfaz (bocetos → código)
    5.4.1 Bocetos a mano (libreta)
    5.4.2 Wireframes en iPad
    5.4.3 Mockups con Claude Design
    5.4.4 Del mockup a Flutter: por qué acortó la distancia diseño→código

-- PARTE II: DESARROLLO --
5.5 Stack tecnológico en uso (breve; el "porqué" se remite a los ADRs)
5.6 Arquitectura realizada (CFS híbrido)
    5.6.1 Estructura core/ vs features/ y capas data/domain/presentation
    5.6.2 Single Source of Truth: currentUserProvider
    5.6.3 Gestión de estado (StateNotifier + estados inmutables) e inyección por Riverpod
    5.6.4 Operaciones atómicas (WriteBatch) y enrutado reactivo (RouterNotifier)
5.7 Decisiones de arquitectura y desarrollo (ADRs)   ← narrativa temática, ver §4
    5.7.1 Plataforma, stack y dependencias
    5.7.2 Arquitectura y gestión de estado
    5.7.3 Identidad, roles y emparejamiento
    5.7.4 IA conversacional, voz y proxy seguro
    5.7.5 Acompañamiento, datos y privacidad
    5.7.6 Tabla resumen de decisiones (ADR)
5.8 Cronología del desarrollo   (narrativa + diagrama, ver §6)
5.9 Cierre del capítulo   (qué queda abierto → remisión a Desarrollo Futuro, cap. 6)
```

If the chapter grows very long, prefer trimming ADR prose (lean on the summary table) over dropping sections.

---

## 3. Verification protocol for implementation status (CRITICAL)

For **every** feature or ADR you are about to describe, it should be updated on the docs, but if there is a shred of doubt, check on `lib/`:

- **Implementado** — code exists and wires the feature end to end.
- **Parcial** — partially wired / behind a flag / TODO in code.
- **Diseñado (no implementado)** — decided in an ADR but absent from code.

Rules:

- The author confirms these ARE now implemented (verify anyway, then treat as done): **emergency call**, **some Cloud Function(s)**, **TTS Chirp3-HD**. Check `pubspec.yaml`, `url_launcher` usage, any `functions/` directory or `cloud_functions` call sites, and the TTS service.
- Anything you classify as **Diseñado (no implementado)** or **Parcial**: describe the *design decision* briefly here, then **defer the implementation to the future-work chapter** with an explicit cross-reference, e.g. *«…cuya implementación se aborda en el \autoref{cap:desarrollo-futuro}»*. Add the label `cap:desarrollo-futuro` to `06_Desarrollo_Futuro.tex` if it lacks one.
- Never phrase deferred work in past tense. Use *«se ha diseñado / se propone»*, not *«se ha implementado»*.
- Where status is genuinely unclear after checking code, leave a `**note:** verificar estado de X en el código antes de entrega`.

Produce (for your own use, and optionally as the §5.7.6 table) a status column per ADR.

---

## 4. ADR treatment: thematic narrative + summary table

Do **not** write one subsection per ADR. Group the 20 ADRs into the five themes below. In each `5.7.x` subsection, write flowing prose that explains the *problem, the alternatives weighed, and the decision*, weaving the relevant ADRs together and citing sources where the ADR does. Reference each ADR inline by its number/name so the mapping is traceable.

**Grouping (all 20 covered):**

- **5.7.1 Plataforma, stack y dependencias:** 0001 (Flutter multiplataforma), 0002 (LLM en la nube), 0003 (Firebase BaaS), 0005 (Riverpod vs BLoC), 0011 (alineación firebase-core 3.x).
- **5.7.2 Arquitectura y gestión de estado:** 0004 (Clean + Feature-Sliced), 0009 (currentUserProvider SSOT), 0010 (preferencias `onChangeEnd`, optimista + rollback), 0019 (preferencias de voz en el reproductor).
- **5.7.3 Identidad, roles y emparejamiento:** 0006 (auth dual anónima/email), 0007 (revelación progresiva), 0008 (emparejamiento transaccional en cliente), 0013 (config explícita vs IA).
- **5.7.4 IA conversacional, voz y proxy seguro:** 0014 (Cloud Function proxy de la clave LLM), 0017 (TTS Chirp3-HD), 0018 (codebase de functions, una callable), 0020 (tráfico en claro solo a loopback).
- **5.7.5 Acompañamiento, datos y privacidad:** 0012 (emergencia, marcador `tel:` vía url_launcher), 0015 (persistencia: solo resúmenes), 0016 (salida transcripción/resumen con consentimiento).

**5.7.6 Tabla resumen (ADR).** One `booktabs` `longtable` (may span pages). Columns:

| Col | Contenido |
|-----|-----------|
| ID | 0001…0020 |
| Decisión | título corto |
| Alternativa descartada | la principal |
| Estado | Implementado / Parcial / Diseñado |

Check `proyecto.tex` preamble for `booktabs` and `longtable`; if missing, add them there (and note the change in your summary). Use `\toprule/\midrule/\bottomrule`, no vertical rules.

---

## 5. Section-specific guidance

### 5.3.4 Teoría del color para personas mayores (breve, ~1–2 párrafos + fuentes)
Cover only what justifies the app's choices: lens yellowing with age reducing short-wavelength (blue) transmission and blue–yellow discrimination; reduced contrast sensitivity; hence high luminance contrast, avoidance of low-contrast blue text and blue/purple–on–dark combinations, and reliance on WCAG contrast ratios rather than hue alone. Tie each claim back to a concrete decision in `AppTheme`/`app_theme.dart` (read it). 
**Sources:** you must locate and cite real references — do not fabricate. Good anchors to search and verify: the WCAG 2.2 contrast success criteria (W3C), Nielsen Norman Group guidance on senior/older-adult UX, and a peer-reviewed source on colour perception and ageing vision. Add each to `bibliografia.bib` with correct APA fields and cite with `\autocite`. If you cannot verify a source, leave a `**note:** buscar y citar fuente para X` rather than inventing one.

### 5.4 Evolución del diseño (bocetos → código)
Narrate the three stages honestly: (1) hand sketches in a notebook, (2) cleaner iPad wireframes, (3) Claude Design mockups. Then §5.4.4 argues the practical payoff: Claude Design mockups mapped more directly onto Flutter widget structure (layout, component hierarchy, spacing, theme tokens), shortening the design→code round-trip. Keep it factual, not promotional.
**Figures:** insert `\begin{figure}[htbp] … \end{figure}` blocks with `\includegraphics[width=…]{imagenes/…}`, a Spanish `\caption`, and a `\label{fig:…}`. The image files are not all present yet — use plausible paths under `doc/tfg/imagenes/` and, for any missing file, leave `**note:** añadir imagen: <descripción>` and a commented `%\includegraphics{...}` so it compiles. Never let a missing image break the build.

### 5.5 Stack tecnológico
Keep it short here — this section states *what* is used and *how it fits*, and explicitly defers the *justification* to the ADRs in §5.7.1 (and to the stack chapter/PDF). Reference exact locked versions from `CLAUDE.md`/`pubspec.yaml` (e.g. `flutter_riverpod ^2.5.1` — note the deliberate non-upgrade to 3.x). Do not re-argue choices already argued in §5.7.

### 5.6 Arquitectura realizada
Describe the *as-built* architecture from `lib/`, not the ideal. Cover: `core/` vs `features/` with no horizontal coupling; the three layers per feature; `currentUserProvider` as SSOT; `StateNotifier` + immutable `copyWith`; DI via Riverpod (flag any residual `new Service()` antipattern only if it still exists in code — verify `chat_controller.dart`); `WriteBatch` for pairing; `RouterNotifier`. Cross-reference the FSD/CFS analysis PDF and ch. 4.

---

## 6. Cronología del desarrollo (LaTeX)

Yes, a timeline in LaTeX is feasible. Provide **both** the prose narrative (from `doc/memoria/timeline.md` + `plan/`) **and** a visual. Prefer one of:

**Option A — Gantt (recommended; aligns with the pending Gantt deliverable), `pgfgantt`:**
```latex
% preamble (proyecto.tex): \usepackage{pgfgantt}
\begin{figure}[htbp]\centering
\begin{ganttchart}[hgrid, vgrid, x unit=0.55cm, y unit chart=0.6cm,
  bar height=0.6, title label font=\small, bar label font=\small]{1}{16}
  \gantttitle{Semanas}{16} \\
  \gantttitlelist{1,...,16}{1} \\
  \ganttbar{HU-1 Onboarding}{1}{3} \\
  \ganttbar{HU-2 Chat por voz}{3}{6} \\
  \ganttbar{HU-3 Accesibilidad}{5}{8} \\
  \ganttbar{HU-4 Config. adaptativa}{7}{11} \\
  \ganttbar{Estabilización HU-1..4}{11}{13} \\
  \ganttbar{Redacción memoria}{2}{16}
\end{ganttchart}
\caption{Cronograma de desarrollo del MVP.}\label{fig:gantt}
\end{figure}
```
Fill weeks/bars from the real `timeline.md`; do not invent dates.

**Option B — línea de hitos horizontal, `tikz`:**
```latex
% preamble: \usepackage{tikz}
\begin{figure}[htbp]\centering
\begin{tikzpicture}[x=2.4cm,>=stealth]
  \draw[->,thick] (0,0) -- (5.5,0);
  \foreach \x/\txt in {0/{Boceto},1/{Wireframe},2/{Mockup},3/{MVP HU1--4},4/{Estabilización}}
    {\filldraw (\x,0) circle (2pt); \node[above,align=center,font=\small] at (\x,0.15){\txt};}
\end{tikzpicture}
\caption{Hitos del proceso de diseño y desarrollo.}\label{fig:hitos}
\end{figure}
```
Add whichever packages you use to `proyecto.tex` preamble and note the addition. If neither renders cleanly, fall back to prose + a `**note:** insertar diagrama de cronología en la defensa` — do not block on it.

---

## 7. Figures, labels, cross-references

- Every float gets a `\caption` (Spanish) and a `\label` with a namespaced key (`fig:`, `tab:`, `sec:`, `cap:`).
- Cross-reference with `\autoref{}` where possible.
- Confirm the graphics path: check whether `proyecto.tex` sets `\graphicspath{{imagenes/}}`. If it does, use paths relative to it; otherwise use `imagenes/...`.

---

## 8. Bibliography

- Add new entries only to `doc/tfg/bibliografia.bib`.
- APA via biblatex; ensure `@article/@online/@book` types have the required fields (author, title, year, url+urldate for web).
- New sources expected: color/vision-in-ageing, WCAG 2.2, senior UX. Verify each before citing; otherwise leave a `**note:**`.
- Do not touch the stale `imagenes/bibliografia.bib` duplicate.

---

## 9. Style guide — match the author's voice

Read ch. 3–4 and the ADRs and mirror that register:
- Concise, technically precise, no filler, no marketing tone.
- Impersonal/first-person-plural academic Spanish, consistent with existing chapters (detect which they use and follow it).
- Justify decisions explicitly against constraints (single developer, target hardware, deadline) — the author consistently frames choices as trade-offs.
- Honest about limitations and residual debt (the author writes things like *«rollback honesto»*, *«único punto donde queda este antipatrón»*). Preserve that candor.
- Short paragraphs, concrete examples over abstractions.

---

## 10. Definition of done

- [ ] `05_Diseño_Desarrollo.tex` written in Spanish, follows the §2 outline.
- [ ] Every implementation claim verified against `lib/` (§3); statuses correct; deferred items cross-referenced to ch. 6.
- [ ] All 20 ADRs covered via the five thematic subsections + the summary `longtable`.
- [ ] Color-theory paragraph present with **verified** citations (or explicit `**note:**`).
- [ ] Sketch-evolution section with figure blocks (real paths or compile-safe placeholders).
- [ ] Timeline: prose + one working LaTeX diagram (or a documented fallback note).
- [ ] Any new packages added to `proyecto.tex` preamble and listed in your final summary.
- [ ] New bib entries in `bibliografia.bib`, APA-valid.
- [ ] Chapter compiles in isolation and via `proyecto.tex`; no stale artifacts touched.
- [ ] Open questions surfaced as `**note:**` (GDPR, latency thresholds, connectivity-loss UX, missing images/sources).

**At the end, output a short summary of: (a) implementation-status classification per ADR, (b) preamble/package changes made, (c) new bib entries, and (d) every `**note:**` left open, so the author can resolve them before submission.**