# CLAUDE.md — Quiet Companion

## Project
Flutter mobile app combating loneliness in elderly people. Dual UX: voice-first assistant for the elder, monitoring dashboard for the family companion. Package: `com.rosas.quiet_companion`. Trabajo Fin de Grado (TFG).

## Current Goal
**Stabilize HU-1 to HU-4 for testing.** No further feature changes in these areas — tests should not need to be redone. Priority: navigation flow polish (currently weak) and clear action paths between elder and companion roles.

Out of scope until HU-1→4 are stable: HU-5 (emotional analysis), conversation persistence, emergency call, Cloud Functions.

## Stack (locked)
- Flutter / Dart
- Android primary (compileSdk 36, minSdk 24, Java 11, Kotlin 2.1.0)
- `flutter_riverpod ^2.5.1` — **never upgrade to 3.x** (Linux dev env conflict with `scheduleNewFrame`)
- Firebase: `firebase_core ^3.15.2`, `firebase_auth ^5.7.0`, `cloud_firestore ^5.6.0`, `cloud_functions ^5.4.0`
- `google_generative_ai ^0.4.7` (gemini-2.5-flash)
- `go_router ^17.0.0`, `speech_to_text ^7.3.0`, `flutter_tts ^4.2.5`, `permission_handler ^12.0.1`, `flutter_dotenv ^6.0.0`
- Plan: Firebase Blaze

## Architecture
Clean Architecture + Feature-Sliced Design (CFS hybrid).

```
lib/
├── core/                       # cross-cutting only
│   ├── config/                 # app_router.dart, env.dart
│   ├── constants/              # firestore_paths.dart
│   ├── models/                 # UserModel, UserPreferences
│   ├── providers/              # currentUserProvider (single source of truth)
│   ├── repositories/           # user_repository.dart
│   ├── services/               # GeminiService, TtsService, SpeechService, PermissionService
│   └── theme/                  # AppTheme
├── features/
│   ├── conversation/           # {data, domain, presentation}
│   ├── dashboard/              # {domain, presentation}
│   └── onboarding/             # {data, domain, presentation}
└── main.dart, firebase_options.dart
```

### Rules (enforce strictly)
- **No horizontal coupling:** features never import from other features. Shared data lives in `core/`.
- **State:** `StateNotifier` + immutable State with `copyWith`. Never `setState` for business logic.
- **DI:** Controllers receive Repositories/Services via Riverpod Provider constructors. Never `new Service()` inside a class.
- **UI:** `ConsumerWidget` / `ConsumerStatefulWidget` only. UI is dumb — `ref.watch` and render.
- **Firestore paths:** always via `FirestorePaths` constants, never inline strings.
- **Cross-user writes:** Cloud Function only. Enforced since 2026-09-06: pairing runs in the `validateAndLink`
  callable and `firestore.rules` denies it from any client (ADR-0024, ADR-0025).
- **NO commits:** Do not run any bash commands that apply a commit or a push, let the dev do commits on their own. You can give the commands to run
    them in an organized manner.

### Accessibility (elder-facing UI only)
- Touch targets ≥ 80×80 logical px
- Body text ≥ 20sp, titles ≥ 28sp, scaled by `UserPreferences.textSizeMultiplier`
- Tap/toggle only — no long-press, no swipe, no double-tap
- WCAG 2.2 perceptibility + operability

## Data Model

### Firestore
```
/users/{uid}
- id, role ("elder" | "companion")
- autonomy ("none" | "independent" | "dependent")
- linkCode (4 chars, A-Z\{O,I} + 2-9) | null
- linkedCompanionId (on the elder) | linkedElderId (on the companion) | null
  <!-- RF-2 and older docs say a single `linkedPartnerId`; the code has always used these two. -->
- preferences (volume, speechRate, textSizeMultiplier)
```

### Auth strategy
- **Elder:** Anonymous Firebase Auth. Identity tied to device. **No logout** — sign-out would generate a new UID on next session and lose data. If reset needed, it's an explicit data-wipe action, not logout.
- **Companion:** Email/Password. Can log out cleanly.

## Reactive Backbone
- `firebaseAuthUserProvider` → Stream of Firebase `User?`
- `currentUserProvider` → Stream of `users/{uid}` doc as `UserModel?`. **Single source of truth.** Any widget anywhere uses `ref.watch(currentUserProvider)`.
- `RouterNotifier` listens to `elderAuthControllerProvider` + `companionAuthControllerProvider` and recalculates redirects.

## Completed (do not regress)
- Firebase Auth + Firestore (anonymous elder, email companion)
- `UserModel` + `UserPreferences` (immutable, `copyWith`, `fromMap`/`toMap`)
- Dual-role onboarding (splash → onboarding → branch)
- Pairing by 4-char code (atomic via `WriteBatch`)
- Router with auth-driven redirects
- Voice chat pipeline (STT → Gemini → TTS) with `systemInstruction` + `safetySettings`
- Dashboard with real-time preference propagation (sliders → Firestore → elder UI)
- TTS reactive to preferences via `ttsServiceProvider`

## Current Sprint — Stabilization Plan (HU-1 → HU-4)

### A. Navigation polish (BLOCKING — must finish before testing)
1. Elder navigation: `splash → onboarding → choice → (independent | linked) → home`. Each screen has explicit back-nav where it makes sense, none where it would cause data inconsistency.
2. Companion navigation: `splash → onboarding → companion/choice → (login | register) → pairing → dashboard`. Same back-nav audit.
3. Logout button: **companion only** (in dashboard). Elder UI must not show it.
4. Define and lock the exact screen transitions before any further work.

### B. HU-4 cleanup (in progress)
- Milestone 2.5.1: migrate `GeminiService` + `SpeechService` to providers (same DI pattern as `TtsService`).
- Milestone 2.5.2: break dashboard → onboarding horizontal coupling. Dashboard reads `currentUserProvider`, not `companionAuthControllerProvider`.
- Remove `_userSubscription` stream duplication between `ElderAuthController` and `currentUserProvider`. Controller should react to `authStateChanges()` directly; user data flows through `currentUserProvider`.

### C. Known technical debt
- ~~`chat_controller.dart:86` — `new GeminiService()` antipattern~~ — fixed (Milestone 2.5.1, DI via providers).
- ~~`home_screen.dart` — `withOpacity` deprecations, stray `print()` calls~~ — no longer in the tree.
- ~~Title placeholder `'¡Hola!'` until `UserModel` gets a `name` field~~ — `UserModel.name` exists; the elder's
  name is learned by Gemini function calling (`guardarNombre`).
- `home_screen.dart` — the `¿Teclado?` button is still inert (text input mode is a separate task).
- Pairing code collision is not retried on generation (~923 000 combinations; accepted risk at test scale).

## Working Agreements
- All `flutter analyze` warnings must be zero before commit on touched files.
- No new dependencies without justification against existing stack.
- Spanish (es-ES) for all user-facing strings.
- Document every decision as an ADR (see Documentation Rules); active plan in `doc/plan/ACTIVE.md`;
  onboarding context in `INFO.md`. (`PLAN.md` was retired in `566482a`.)

# Architecture Rules (Clean Architecture + Feature-Sliced Design)
- **Core (`lib/core/`):** Transversal elements ONLY (themes, global models like `UserModel` + `UserPreferences`, external service wrappers).
- **Features (`lib/features/`):** Isolated modules (`chat`, `onboarding`, `dashboard`).
- **Domain Layer (`/domain/`):** StateNotifier (`Controller`) and immutable state classes (`State` with `copyWith`).
- **Presentation Layer (`/presentation/`):** UI using `ConsumerWidget` or `ConsumerStatefulWidget`.
- **Single Source of Truth:** Use `StreamProvider` (e.g., `currentUserProvider`) to listen to Firestore changes in real-time. Controllers should not keep streams open themselves to avoid violating SRP.
- **Atomic Operations:** multi-document updates are transactional. Cross-user ones (pairing) run server-side
  in Cloud Functions with the Admin SDK; client-side transactions only ever touch the caller's own document.

# Documentation Rules

## Where the memoria lives

`doc/` is **not** tracked on `main_mario` — it is ignored there, so that the application branch's history
stays about application code. The memoria is versioned on its own branch, **`docs/memoria`**, which carries
its own `.gitignore` (LaTeX build artifacts and `doc/pdfs/` stay ignored everywhere).

- **Never merge `docs/memoria` into `main_mario`.** It exists to back up and share the memoria across
  machines, not to land in the application history. Bringing code forward goes the other way:
  `git checkout docs/memoria && git merge main_mario`.
- Do not `git add doc/` while on `main_mario`, and do not remove `doc/` from that branch's `.gitignore`.

## ADRs

- Any change involving a trade-off gets an ADR in `doc/memoria/decisions/` (`NNNN-kebab-title.md`), written
  in the **same working session** as the code. If there was an option you rejected, that's an ADR. Trivial
  edits are exempt.
- The ADR cannot ride in the code commit (different branches), so it carries the link instead: every ADR's
  `Evidencia:` line lists the short SHAs of the commits that enact it. That line *is* the traceability —
  without it the decision is unattributable, which defeats the purpose of writing it.
- ADRs are append-only. Superseding a decision means a NEW ADR and flipping the old one to
  `Estado: Superseded by ADR-NNNN`. Never rewrite history in `decisions/`. When a decision closes an open
  question from an earlier ADR or HU file, add an epilogue there pointing forward — the old text stays.
- When an HU closes: rewrite `doc/plan/ACTIVE.md` into `doc/memoria/hu/<hu>.md` in past tense — including
  deviations and rework — then move the plan to `doc/plan/archive/` and open a fresh `ACTIVE.md`.
- `doc/memoria/scope.md` is updated at every HU close. A capability moves to "Implemented" only when the
  code exists, never when the plan exists.
- Rejected approaches are documented with as much care as accepted ones. The rejections are the most
  defensible part of this project.
- Memoria prose is Spanish; trusted research PDFs live in `doc/pdfs/` (git-ignored) and count as citable
  evidence.

**Acknowledge this context and ask me what we are working on today.**
