# CLAUDE.md — Quiet Companion

## Project
Flutter mobile app combating loneliness in elderly people. Dual UX: voice-first assistant for the elder, monitoring dashboard for the family companion. Package: `com.rosas.quiet_companion`. Trabajo Fin de Grado (TFG).

## Current Goal
**HU-5 + HU-6: conversation memory and mood tracking.** HU-1→4 are the MVP and are done; do not change their
behaviour except where a phase of the plan says so. Active plan, phases and acceptance criteria:
`doc/plan/ACTIVE.md`. Governing decisions: ADR-0027 → ADR-0034.

HU numbering follows the memoria (ch. 3–4): **HU-5 = conversational memory (RF-7)**, **HU-6 = mood tracking
(RF-8)**. Older docs (`pending.md`, `hu4-plan.md`, ADR-0015/0016) call mood analysis "HU-5" — ignore that.

Out of scope for this plan: companion notifications (FCM), moving the live chat's Gemini call server-side
(ADR-0014), keyboard input mode, n8n.

## Stack (locked)
- Flutter / Dart
- Android primary (compileSdk 36, minSdk 24, Java 11, Kotlin 2.1.0)
- `flutter_riverpod ^2.5.1` — **never upgrade to 3.x** (Linux dev env conflict with `scheduleNewFrame`)
- Firebase: `firebase_core ^3.15.2`, `firebase_auth ^5.7.0`, `cloud_firestore ^5.6.0`, `cloud_functions ^5.4.0`
- `google_generative_ai ^0.4.7` (gemini-2.5-flash)
- `go_router ^17.0.0`, `speech_to_text ^7.3.0`, `flutter_tts ^4.2.5`, `permission_handler ^12.0.1`, `flutter_dotenv ^6.0.0`
- `just_audio ^0.10.6` (cloud TTS playback, ADR-0017), `url_launcher ^6.3.2` (emergency dialer, ADR-0012)
- Cloud Functions: `functions/`, JavaScript, gen 2, Node 22, region **`europe-west1`** (must match
  `kFunctionsRegion`). Callables: `synthesizeSpeech`, `validateAndLink`, `setConversationConsent`,
  `closeConversation` (the last two from 2026-09-26, unverified). The analysis calls Gemini through Vertex AI
  with ADC (`@google/genai`), no key. Pure logic lives in `pairing.js` / `conversation.js` with `node --test`.
- Security rules: `firestore.rules`, verified against the emulator in `firestore-tests/` (ADR-0025, ADR-0026)
- Plan: Firebase Blaze

## Architecture
Clean Architecture + Feature-Sliced Design (CFS hybrid).

```
lib/
├── core/                       # cross-cutting only
│   ├── config/                 # app_router, env, functions/speech/tts config, preference_scales, settings_rows
│   ├── constants/              # firestore_paths.dart
│   ├── models/                 # UserModel, UserPreferences, EmergencyContact
│   ├── providers/              # currentUserProvider (SSOT), authRepositoryProvider, ttsServiceProvider, …
│   ├── services/               # GeminiService, SpeechService, TtsService (cloud + device), EmergencyCallService, …
│   ├── theme/                  # AppTheme
│   ├── utils/                  # sentence_splitter.dart
│   └── widgets/                # sign_out_button.dart
├── features/
│   ├── conversation/           # {data, domain, presentation} — elder voice chat
│   ├── dashboard/              # {domain, presentation} — companion panel
│   ├── emergency/              # {presentation}
│   ├── onboarding/             # {data, domain, presentation} — AuthRepository lives here
│   └── settings/               # {presentation} — elder settings shell
└── main.dart, firebase_options.dart
functions/                      # Cloud Functions (see Stack)
firestore.rules, firestore-tests/
```

Data shared by two features (read models, their providers, pure aggregations) goes in `core/`. Example: the
conversation records read by both the companion panel and the elder's "Mi semana" (ADR-0033).

### Rules (enforce strictly)
- **No horizontal coupling:** features never import from other features. Shared data lives in `core/`.
- **State:** `StateNotifier` + immutable State with `copyWith`. Never `setState` for business logic.
- **DI:** Controllers receive Repositories/Services via Riverpod Provider constructors. Never `new Service()` inside a class.
- **UI:** `ConsumerWidget` / `ConsumerStatefulWidget` only. UI is dumb — `ref.watch` and render.
- **Firestore paths:** always via `FirestorePaths` constants, never inline strings.
- **Cross-user writes:** Cloud Function only. Enforced since 2026-09-06: pairing runs in the `validateAndLink`
  callable and `firestore.rules` denies it from any client (ADR-0024, ADR-0025).
- **Conversation text is never persisted.** The transcript lives in `ChatController` memory, travels to the
  `closeConversation` callable at conversation end, and is discarded. It must never appear in Firestore,
  on disk, or in any log (client or Function): log lengths and ids only (ADR-0028, ADR-0029).
- **Privacy is enforced by rules, not UI.** What the companion may read is decided in `firestore.rules` from
  the elder's `companionSharing` level; hiding something in the panel is not protection (ADR-0031).
- **In stateful providers, `watch` only what should destroy the state when it changes;** everything else
  arrives through `ref.listen` (ADR-0023).
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
- id, name | null, role ("elder" | "companion")
- autonomy ("none" | "independent" | "dependent" on the elder; "linked" on the companion)
- linkCode (4 chars, A-Z\{O,I} + 2-9) | null
- linkedCompanionId (on the elder) | linkedElderId (on the companion) | null
  <!-- RF-2 and older docs say a single `linkedPartnerId`; the code has always used these two. -->
- preferences (volume, speechRate, textSizeMultiplier)      ← accessibility only (ADR-0013, ADR-0021)
- phoneNumber (companion, E.164) | null
- emergencyContact { name, phone, source: companion|manual } (elder) | absent
```

HU-5/HU-6 — **coded on 2026-09-26, not yet compiled or verified on device**; see `doc/plan/ACTIVE.md`:
```
/users/{elderId}
- conversationConsent { granted, answeredAt, textVersion, revokedAt?, deleteAfter? } ← only via setConversationConsent (ADR-0030)
- companionSharing ("none" | "wellbeing" | "full")          ← only the elder writes it (ADR-0031)
- conversationSettings { inactivityMinutes, retentionDays } ← companion (linked) or elder (independent) (ADR-0034)

/users/{elderId}/conversations/{id}          ← Function only; companion reads at "wellbeing"+
- startedAt, endedAt, elderTurns, endReason, status, sentiment, signals[], promptVersion, model, expireAt
/users/{elderId}/conversationContents/{id}   ← Function only; companion reads at "full"
- endedAt, topics[], summary, expireAt
/users/{elderId}/memory/profile              ← Function only; companion reads at "full" (ADR-0032)
- facts {key: value} (≤ 30), recent [{endedAt, summary}] (3), updatedAt, expireAt? (only while frozen)
```

Consent withdrawal freezes everything above: companion loses read access at once, analysis stops, and
`expireAt` is moved to `revokedAt + retentionDays / 2` so the TTL policy deletes it unless the elder
re-consents in time (ADR-0030, epilogue).

### Auth strategy
- **Elder:** Anonymous Firebase Auth. Identity tied to device. **No logout** — sign-out would generate a new UID on next session and lose data. If reset needed, it's an explicit data-wipe action, not logout.
- **Companion:** Email/Password. Can log out cleanly.

## Reactive Backbone
- `firebaseAuthUserProvider` → Stream of Firebase `User?`
- `currentUserProvider` → Stream of `users/{uid}` doc as `UserModel?`. **Single source of truth.** Any widget anywhere uses `ref.watch(currentUserProvider)`.
- `RouterNotifier` gathers its inputs (`elderAuthControllerProvider`, `companionAuthControllerProvider`,
  `firebaseAuthUserProvider`, `currentUserProvider`, `consentPromptDeferredProvider`) and delegates to the
  pure `routeRedirect` in `core/config/route_redirect.dart`, which is what `router_redirect_test.dart` tests.
  Companions are pinned to `/dashboard/*` (prefix); onboarded elders who never answered the consent question
  go to `/consent` once (ADR-0030).
- `chatControllerProvider` rebuilds only on uid change (`select`); the name reaches it by `ref.listen`
  (ADR-0023).
- `linkedElderProvider`: the companion's live view of the elder (ADR-0027). The panel never keeps a copy.
- `conversationRecordsProvider` / `conversationContentsProvider` / `elderMemoryProvider` (family by elder id,
  in `core/providers/conversation_providers.dart`): shared by the companion panel and the elder's "Mi semana".
  Only request what the elder's `companionSharing` level allows, or the stream ends in permission-denied.
- The chat receives consent, conversation settings and memory by `ref.listen`, never by rebuilding.

## Completed (do not regress)
- Firebase Auth + Firestore (anonymous elder, email companion)
- `UserModel` + `UserPreferences` (immutable, `copyWith`, `fromMap`/`toMap`)
- Dual-role onboarding (splash → onboarding → branch)
- Pairing by 4-char code, server-side: `validateAndLink` callable with a transaction (ADR-0024; supersedes the
  client `WriteBatch` of ADR-0008)
- Router with auth-driven redirects
- Voice chat pipeline (STT → Gemini → TTS) with `systemInstruction` + `safetySettings`; the elder's name
  learned by function calling (`guardarNombre`)
- Turn-based listening closed by silence (ADR-0022); `ChatController` survives user-doc changes (ADR-0023)
- Cloud TTS (Chirp 3: HD) behind `TtsService`, device-TTS fallback (ADR-0017 → ADR-0020)
- Dashboard with preference propagation companion → elder (sliders → Firestore → elder UI). The reverse
  direction is broken; see technical debt.
- Elder's local accessibility scales in Settings (ADR-0021)
- Emergency call: dialer launch with 112 + emergency contact (ADR-0012)
- Firestore rules scoped per operation, 29 emulator tests (ADR-0025, ADR-0026); optional emulator connection
  for the app (`core/config/emulator_config.dart`)

## Current Sprint — HU-5 + HU-6

All eight design decisions are accepted and phases 0–7 of `doc/plan/ACTIVE.md` were coded on 2026-09-26
without a working Flutter toolchain. **Next step is verification**, not new features: `flutter analyze`,
`flutter test`, the emulator rules tests, the manual deploy steps and the on-device script in `ACTIVE.md`.
Fix what they surface before building anything else. Consent withdrawal does **not** delete immediately: data freezes and is TTL-deleted
after half the retention period unless the elder re-consents (ADR-0030, epilogue).

### Known technical debt
- ~~Companion panel works on a one-shot copy of the elder~~ — fixed in code (ADR-0027), pending verification.
  `saveUser` is for creating documents only; edit with field-level `update()`.
- Two ADR files share number 0023 (chat controller lifecycle, JDK 21). Not renumbered; next new ADR is 0035.
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
- **Features (`lib/features/`):** Isolated modules (`conversation`, `onboarding`, `dashboard`, `emergency`, `settings`).
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
