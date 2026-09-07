# Memoria Bootstrap — Claude Code Task Brief

Paste this whole file into Claude Code (or keep it at `docs/memoria/BOOTSTRAP.md` and reference it with `@`).
It has two halves: a **one-off backfill** (§1–§6) and a **standing convention** (§7) to keep from ever needing a backfill again.

---

## 0. Role and hard rules

You are acting as **documentation archaeologist**, not as a developer. You do not write or modify application code in this task. You read the repository and produce documentation that is *traceable to evidence already in the repo*.

**Hard rules — violating any of these makes the output worthless:**

1. **No invention.** Every factual claim (a decision, a date, a feature status) must be traceable to a commit, or a PDF file trusted by the author, a file in the working tree, or a line in an existing `.md`. If you cannot trace it, do not write it.
2. **Cite the evidence inline.** Every ADR and every scope entry carries an `Evidence:` line listing commit SHAs (short form) and/or file paths. This is what makes the memoria defensible in front of a tribunal.
3. **Gaps are recorded, not filled.** When the reasoning behind a decision is not recoverable from the repo, write `> **UNRESOLVED — author input required:** <specific question>` and move on. A document with twelve honest gaps is more useful to me than one with twelve plausible fabrications, because I have to defend every sentence orally.
4. **Dates come from `git log` and nowhere else.** Do not smooth, interpolate, back-date, or infer a timeline. If development happened in three intense bursts, the timeline says three intense bursts. Bursty velocity is not a defect and will not be presented as one.
5. **Distinguish "designed" from "implemented" by reading `lib/` and `functions/`, not by reading `PLAN.md`.** Plans describe intent. Only the code describes reality. Where a plan claims something the code does not contain, that is a scope-boundary finding — record it.
6. **Preserve original language.** Prompts, UI strings, and user-facing copy are Spanish. Quote them verbatim; do not translate. Prose in the memoria files is written in **Spanish**, since the memoria is Spanish; ADR *structure* keywords stay in English where I've specified them below. (If you prefer, generate prose in English and I'll translate — but be consistent across all files and tell me which you chose.)

---

## 1. Inputs to read, in this order

Read everything before writing anything. Do not write a file until §1–§3 are complete.

**Existing documentation** (treat as *primary sources with unknown reliability* — they may be stale, aspirational, or contradicted by the code):
- `README.md`
- `INFO.md`
- `PENDING.md`
- `test.md`
- `emergency_call_spec.md`
- `docs/plan/archive/hu-4plan.md`
- `CLAUDE.md` — the architectural rules (DI, no horizontal coupling, accessibility constraints). This is the normative source for *why* several refactors happened.

**Git history:**
```bash
git log --reverse --date=short --pretty=format:'%h|%ad|%s' > /tmp/log.txt
git log --reverse --date=short --stat --pretty=format:'%n=== %h | %ad | %s' > /tmp/log-stat.txt
git log --date=short --pretty=format:'%h|%ad|%s' --name-only -- lib/features/ > /tmp/log-features.txt
```
Read all three. The `--stat` version is what tells you which HU a commit belongs to when the message is terse.

**Ground truth (the code):**
- `lib/features/` — one directory per feature slice; this is the definitive list of what exists.
- `lib/core/` — models, services, providers, repositories, router.
- `functions/` — Cloud Functions; check `index.js` exports for which functions are actually deployed vs. sketched.
- `firestore.rules`, `firestore.indexes.json` — security and index decisions are decisions.
- `pubspec.yaml` — dependency choices (e.g. `firebase_core` version pin, `url_launcher` vs `flutter_phone_direct_caller`) are decisions with evidence.

---

## 2. Build an evidence map first

Before writing prose, produce `docs/memoria/_evidence-map.md` (a working artifact, not part of the final memoria — prefix `_` marks it as internal):

| HU / area | Feature dirs | Cloud Functions | Commit range (SHA→SHA) | Date range | Source `.md` |
|---|---|---|---|---|---|

One row per HU (HU-1 onboarding, HU-2 conversation, HU-3 accessibility, HU-4 adaptive config, emergency call, and anything else you find in `lib/features/` that has no HU number — flag those).

Then show me this table and **stop**. I will correct the HU mapping before you generate anything downstream. Do not proceed past §2 without my confirmation.

---

## 3. Target tree

```
docs/
  memoria/
    _evidence-map.md          # internal working artifact (§2)
    scope.md                  # implemented vs. designed future work (§5)
    timeline.md               # honest development chronology from git (§6)
    decisions/
      NNNN-kebab-title.md     # one ADR per decision (§4)
    hu/
      hu1-onboarding.md
      hu2-conversation.md
      hu3-accessibility.md
      hu4-adaptive-config.md
      emergency-call.md
  plan/
    ACTIVE.md                 # do not touch — my working file
    archive/
```

---

## 4. ADRs — `docs/memoria/decisions/`

### Template (use exactly)

```markdown
# ADR-NNNN — <Title>

- **Status:** Accepted | Superseded by ADR-NNNN | Reverted | Proposed
- **Date:** YYYY-MM-DD   <!-- date of the commit that first enacts it; if design-only, date of the doc -->
- **Scope:** Implemented | Designed (not implemented)
- **Evidence:** `a1b2c3d`, `e4f5g6h`, `lib/core/services/tts_service.dart`, `CLAUDE.md#DI`

## Context
What forced a choice. Constraints in play: the elderly user population, anonymous device-bound auth,
thesis scope, Spanish regulatory context, cost. Written so a reader who has never seen the code
understands why doing nothing was not an option.

## Options considered
1. **<Option>** — <mechanism>. Pros / Cons.
2. **<Option>** — ...
Include options that were rejected. A single-option ADR is a note, not a decision record.

## Decision
The option taken, in one paragraph, active voice.

## Rationale
Why this option beat the others *against the constraints named in Context*. This is the paragraph
the tribunal will interrogate — it must not be generic engineering platitude.

## Consequences
- Positive: ...
- Negative / accepted cost: ...
- Follow-on work this created: ...

## Verification
How we know it works: the acceptance criterion, the test, or the manual verification performed.
```

### Numbering
Assign `NNNN` in **chronological order of the decision's evidence date**, not order of importance. Zero-padded to 4.

### Seed list — these are known and must exist

Derive Context/Rationale from the sources named; do **not** embellish beyond them.

| # | Title | Primary evidence source |
|---|---|---|
| — | Cloud Functions proxy for LLM API key isolation (vs. Vertex AI migration, vs. key-in-client) | `functions/`, `README.md`, `INFO.md` |
| — | Reject AI-adaptive accessibility in favour of caregiver-controlled explicit configuration | `CLAUDE.md`, HU-3/HU-4 code, `INFO.md` |
| — | Elder sign-out architecturally prohibited (anonymous auth is device-bound; sign-out destroys the UID) | `SignOutButton` in `core/widgets/`, router, `CLAUDE.md` |
| — | Reject exponential backoff as retry UX for the elder-facing path | `CLAUDE.md`, conversation feature error handling |
| — | Dialer launch (`tel:` via `url_launcher`) over direct dial — Spanish regulatory uncertainty + confirmation step | `emergency_call_spec.md`, `lib/features/emergency/`, `pubspec.yaml` |
| — | Align the full FlutterFire ecosystem to `firebase_core` 3.x to resolve dependency conflict | `pubspec.yaml` + the commit that changed it |
| — | `validateAndLink` as a callable Cloud Function for elder↔caregiver pairing (vs. client-side write) | `functions/index.js`, `firestore.rules`, `firestore.indexes.json` |
| — | `currentUserProvider` as SSOT `StreamProvider` over the user document | `lib/core/providers/current_user_provider.dart` |
| — | Slider writes on `onChangeEnd`, not `onChanged` — write amplification vs. responsiveness | `dashboard_screen.dart`, hu-4 plan Milestone 1 |
| — | Optimistic update with rollback on write failure (no silently-lying UI) | `dashboard_controller.dart` |
| — | `ElderAuthController` reactive session: `authStateChanges()` as outer stream over construction-time init | the fix commit |
| — | DI: services resolved via providers, never instantiated inside classes | `CLAUDE.md`, Milestone 2.5.1 commits |
| — | No horizontal coupling between feature slices; shared reads promoted to `core/` | `CLAUDE.md`, Milestone 2.5.2 commits |

Scan for decisions I have not listed — Firestore schema shape, index choices, security-rule model, TTS provider wiring, router redirect gating. Add them.

### Two ADRs I want written even though the code doesn't exist yet
Mark `Status: Proposed`, `Scope: Designed (not implemented)`:
- **Conversation persistence: summary-only, no raw transcripts at rest** — evidence: `hu-4plan.md#C`. Context must state the GDPR/consent driver explicitly (Spanish context, elder as data subject, caregiver as third-party viewer).
- **Data leaves the device for the summarization call even when nothing is persisted** — the tension between §C (summary-only at rest) and §D.6 (hybrid sweep sends the full in-memory transcript to a second LLM call). Frame it honestly as an unresolved consent question, not as a solved one. Mark `UNRESOLVED` where I still owe a decision.

---

## 5. `docs/memoria/scope.md`

Three tables. Membership is decided by **reading the code**, then reconciled against the docs.

```markdown
## Implemented and verified
| Capability | HU | Where | Evidence | Verified how |

## Implemented, not yet formally tested
| Capability | HU | Where | Evidence | Blocking |

## Designed, not implemented (future work)
| Capability | Design doc | Why deferred | Prerequisite |
```

Then a section:

```markdown
## Plan/reality divergences
Claims in the planning documents that the working tree does not support, with the reason if recoverable.
```

`PENDING.md` and `hu-4plan.md` §A–§E are the raw material for the third table. SMS alerting, async LLM summarization, the proactive check-in agent, and the D.6 hybrid sweep belong there — they are **designed future work and must never be described as built**. The inactivity alert pipeline / n8n escalation ladder: check whether any of it is committed; if it is design-only, it goes in table three regardless of how detailed the design is.

---

## 6. `docs/memoria/timeline.md`

From `git log` only.

- A table: phase | HU | first commit (SHA, date) | last commit (SHA, date) | commit count | one-line summary of what the phase delivered.
- A short prose paragraph per phase describing what was learned or changed, sourced from commit messages and the plan archive.
- A **Methodology note** section stating plainly: development proceeded in iterative HU-scoped increments, executed in concentrated sessions alongside full-time employment; architecture is frozen after HU-1→4 user testing. Do not present velocity as uniform. Do not add dates that are not in the log.
- Where a review loop is visible in the history (HU-4 Milestone 2.5 exists *because* an architecture review surfaced two pre-existing DI violations mid-milestone), say so. That is evidence of process, and it is worth more than a clean-looking graph.

---

## 7. Standing convention (applies to all future work)

Add this to `CLAUDE.md` so it survives context resets:

```markdown
## Documentation rules

- Any change involving a trade-off gets an ADR in `docs/memoria/decisions/` in the SAME commit
  as the code. If there was an option you rejected, that's an ADR. Trivial edits are exempt.
- ADRs are append-only. Superseding a decision means a NEW ADR and flipping the old one to
  `Status: Superseded by ADR-NNNN`. Never rewrite history in `decisions/`.
- When an HU closes: rewrite `docs/plan/ACTIVE.md` into `docs/memoria/hu/<hu>.md` in past tense
  — including deviations and rework — then move the plan to `docs/plan/archive/` and open a
  fresh ACTIVE.md.
- `scope.md` is updated at every HU close. A capability moves to "Implemented" only when the
  code exists, never when the plan exists.
- Rejected approaches are documented with as much care as accepted ones. The rejections are the
  most defensible part of this project.
```

---

## 8. Execution order

1. §1 read everything.
2. §2 produce `_evidence-map.md` → **stop, wait for my confirmation of the HU mapping.**
3. `decisions/` — one ADR at a time, chronological. After the first three, stop and show me them so I can correct tone and depth before you do the remaining ten.
4. `hu/` files.
5. `scope.md`.
6. `timeline.md`.
7. Append §7 to `CLAUDE.md`.
8. Final report: list every `UNRESOLVED` marker you emitted, grouped by file, as a to-do list for me.

Commit each numbered step separately with message `docs(memoria): <step>`.