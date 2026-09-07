# Quiet Companion — HU-4 Implementation Plan

Ordered milestones to finish HU-4 (Adaptive Configuration). Each step's verification is independent; you can stop after any milestone without leaving the codebase broken.

---

## Milestone 1 — Dashboard sliders write to Firestore (no flooding)

**Why first:** smallest blast radius, fully testable on the companion side without touching the elder's flow.

### Task 1.1 — Switch sliders from `onChanged` to `onChangeEnd`
- **File:** `lib/features/dashboard/presentation/dashboard_screen.dart`
- Add an `onChangeEnd` parameter to `_SettingSlider` and have the parent pass `updateElderPreferences` there. Keep `onChanged` for *local* visual feedback only (use a `StatefulWidget` or a tiny `StateProvider` to hold the in-flight slider value).
- **Acceptance:** drag a slider continuously; only **one** Firestore write fires when you release.

### Task 1.2 — Optimistic local update with honest error rollback
- **File:** `lib/features/dashboard/domain/dashboard_controller.dart` (line 40-46)
- On Firestore error, revert `state.linkedElder` to its previous value, not just append an `errorMessage`. Otherwise the UI shows a saved value that didn't save.
- **Acceptance:** turn off wifi, drag slider → slider snaps back + error banner appears.

**Verification step:** open Firestore console, watch `users/{elderId}.preferences` change in real time as the companion drags sliders.

---

## Milestone 2 — Real-time settings flow to the elder

**Why second:** depends on Milestone 1 producing real Firestore writes, but isolated from auth/router work.

### Task 2.1 — Create `currentUserProvider` as a `StreamProvider<UserModel?>`
- **New file:** `lib/core/providers/current_user_provider.dart`
- Snapshots `users/{uid}` from Firestore, mapped through `UserModel.fromMap`. The `uid` comes from `FirebaseAuth.instance.authStateChanges()` — wrap that in a `StreamProvider` first (`firebaseAuthUserProvider`) and then `currentUserProvider` watches it and switches the Firestore stream when the uid changes.
- **Acceptance:** in any widget, `ref.watch(currentUserProvider)` returns the live elder document.

### Task 2.2 — `TtsService` becomes a Riverpod provider that reacts to preferences
- **File:** `lib/core/services/tts_service.dart` + new provider
- Convert to `final ttsServiceProvider = Provider<TtsService>((ref) { ... })`. Inside, use `ref.listen(currentUserProvider, ...)` to call `_flutterTts.setSpeechRate` and `_flutterTts.setVolume` whenever preferences change. Keep `TtsService` itself stateless about preferences — the *provider* wires them in.
- **Risk note:** `flutter_tts` may not allow rate change mid-speech on all devices; setting between utterances is safest. Apply changes at provider-listen time, but if mid-speak fails silently, that's expected.
- **Acceptance:** companion changes speech rate slider → next TTS utterance on elder device speaks at new rate.

### Task 2.3 — `home_screen.dart` font sizes scale with `textSizeMultiplier`
- **File:** `lib/features/conversation/presentation/home_screen.dart`
- Replace hardcoded `AppTheme.fontHuge` / `AppTheme.fontLarge` with `AppTheme.fontHuge * multiplier`, where `multiplier = ref.watch(currentUserProvider).valueOrNull?.preferences.textSizeMultiplier ?? 1.0`.
- Replace the placeholder `'!Hola, Pedro!'` with the actual elder's data (or keep generic Spanish "¡Hola!" until a `name` field is added — known TODO).
- **Acceptance:** companion drags text size slider → elder's font changes within ~1s.

**Verification step:** two devices/emulators side by side. Companion slider → elder UI changes without app restart.

---

## Milestone 2.5 — DI cleanup (pre-existing tech debt surfaced during review)

**Why:** the reviewer agent flagged two pre-existing rule violations while auditing Milestone 2's work. They're independent of HU-4 but should be resolved before Milestone 3 to avoid carrying them into the router refactor.

### Task 2.5.1 — Migrate `GeminiService` and `SpeechService` to providers
- **File:** `lib/features/conversation/domain/chat_controller.dart` (lines 86-87)
- **Current bug:** `chatControllerProvider` instantiates `GeminiService()` and `SpeechService()` inline. Violates the DI rule "Never instantiate services inside a class" (CLAUDE.md). The same fix was already applied to `TtsService` in Milestone 2.2.
- Wrap each in a `Provider<...>` (in their own `lib/core/services/*.dart` files) and have the controller read them via `ref.watch`.
- **Acceptance:** grep `GeminiService(` and `SpeechService(` returns hits only inside their own provider declarations.

### Task 2.5.2 — Resolve dashboard ↔ onboarding cross-feature import
- **File:** `lib/features/dashboard/domain/dashboard_controller.dart` (lines 2-3)
- **Current bug:** the dashboard feature imports `companion_auth_controller.dart` and `auth_repository.dart` directly from the onboarding feature. Violates "NO Horizontal Coupling" (CLAUDE.md).
- Two viable fixes:
  - **(a)** The dashboard reads `currentUserProvider` (now in `core/`) for the companion's data and uses the `linkedElderId` from there to fetch the elder. Removes the `companionAuthControllerProvider` import entirely.
  - **(b)** Promote `AuthRepository` (or just its read methods) to `core/` as a `UserRepository`, and let both features share it.
- Recommend (a) — it slots naturally with the `currentUserProvider` SSOT pattern from Milestone 2.1.
- **Acceptance:** no `import '...features/onboarding/...'` lines remain in any `features/dashboard/` file.

---

## Milestone 3 — Auto-login polish (skip splash + onboarding for returning elders)

**Why last:** touches the router, which is the most fragile piece. Do it once Milestones 1–2 prove the data flow works.

### Task 3.1 — Persist a "session ready" signal cleanly
- **File:** `lib/core/config/app_router.dart`
- Today, `_elderState.status == AuthStatus.checking` blocks redirect (good). But the *initial location* is `/splash`, so a returning user briefly sees splash even if their auth + Firestore doc are already cached. Make sure `SplashScreen` itself is just a plain `CircularProgressIndicator` with **no** logic — the redirect already handles routing once `elderAuthControllerProvider` settles. No `initSession()` call from the screen; that should run once in `main.dart` or via the controller's constructor.

### Task 3.2 — Returning elder lands on `/home` directly
- **File:** `lib/core/config/app_router.dart` (the `redirect` method)
- Current logic at lines 81-83 already does this for `independent` / `linked`. Verify the path `/splash → /home` happens in **one** redirect tick (no `/splash → /onboarding → /home` intermediate flash). If it flashes, the issue is that `_elderState` momentarily has `autonomy == none` before Firestore data arrives — gate `isFullyOnboarded` on `_elderState.user != null` and keep returning `null` (stay on splash) until the user doc loads.
- **Acceptance:** cold-start app with an existing elder account → splash → home, no onboarding flash.

### Task 3.3 — Returning companion lands on `/dashboard` directly
- Same file, lines 57-58. Should already work, but verify with a real cold start (kill app, reopen).

---

## Order of operations

1. Open two terminals: one for `flutter run` (debug session), one for the assistant.
2. Start with Milestone 1. Run, drag sliders, confirm Firestore. Commit.
3. Milestone 2.1 (provider) → 2.2 (TTS) → 2.3 (fonts). Commit after each task — they're separable.
4. Milestone 3 last, with the app fully working before touching the router.

### Suggested agent assignment
- **Direct edits:** Tasks 1.1, 1.2, 2.3, 3.2, 3.3 — surgical edits.
- **Dev agent (opus):** Tasks 2.1, 2.2 — they introduce new files + cross-cutting wiring where architectural awareness helps.

---

## Beyond HU-4 — Future Work (not yet planned, just tracked)

HU-4 is a slice of a larger product. The items below are **not** scheduled as part of this plan and should be promoted to their own PLAN.md sections when picked up. They are listed here so they don't get lost between conversations.

### A. Navigation & UX polish
- **Problem:** Most screens lack a home / back / log-out affordance. Once the user lands somewhere, the only recourse is to kill the app.
- **Scope:**
  - Add a persistent `AppBar` (or equivalent voice-first equivalent for the elder) with a back/home action on every secondary screen.
  - Add a log-out flow on the `DashboardScreen` (and an equivalent "switch elder" path for the elder if they want to start over).
  - Audit the elder's `HomeScreen` for buttons that currently do nothing — either wire them up or hide them.
- **Why not now:** unrelated to adaptive config; safer to do once HU-4's data wiring is stable so we don't churn the same files twice.

### B. Emergency Call feature (new HU)
- **Problem:** the emergency-call button is referenced in the UX brief but there is no feature implementing it.
- **Scope:**
  - New feature `lib/features/emergency/` (data + domain + presentation slices).
  - Reads the linked Companion's phone number (requires adding a `phoneNumber` field to `UserModel` for companions; collected at registration).
  - One-tap action that launches the dialer via `url_launcher` (`tel:` scheme) or `flutter_phone_direct_caller`. Tap-only — no LongPress per the accessibility rules.
  - Permission handling: `permission_handler` for `CALL_PHONE` if going the direct-call route.
- **Open questions:** confirm whether legal/regulatory constraints in Spain permit a direct-dial without a confirmation step. Default to dialer-launch (user confirms in the system UI) until that's settled.

### C. Conversation persistence + summarization
- **Problem:** Gemini conversations are entirely ephemeral. Once the elder closes the app the session evaporates, so there is nothing to analyze later.
- **Scope:**
  - Define `users/{uid}/conversations/{conversationId}` with `{ startedAt, endedAt, summary, messageCount }`. **Do not persist raw transcripts** unless we add explicit consent — only store a Gemini-generated summary.
  - Trigger summarization on session end (app lifecycle `paused` or an explicit "end conversation" action).
  - Summarization prompt belongs in `gemini-prompt-architect`'s domain — write it before wiring the persistence call.
- **Open questions:** is summarization done client-side (extra Gemini call from the device) or via a Cloud Function triggered on conversation close? Cloud Function is safer (key isolation, retry, atomicity) but adds infra.

### D. User Context Profile — aprendizaje progresivo del mayor

**Prerequisite:** HU-1→4 testing and documentation complete. Does **not** depend on (C); the real-time path works independently. The hybrid extension in D.6 does depend on (C) being in place.

**Goal:** Gemini accumulates personal facts about the elder (family members, city, hobbies, doctor, routines…) across conversations and injects them into each new session so the elder is always greeted by a companion that "remembers" them.

**Design decision (recorded here, to be re-evaluated before implementation):**
The default approach is **real-time function calling** — the same pattern already used by `guardarNombre`. The hybrid extension (post-session sweep) is optional and should only be added if real-time calling proves to miss meaningful context. If the hybrid is adopted, it must remain invisible to the elder — the natural conversational feel cannot degrade.

---

#### D.1 — Data model: `context` map on the user document

- Add `context: Map<String, String>?` to `UserModel` (optional, null-safe, empty map on first load).
- Update `fromMap` / `toMap` / `copyWith` in `lib/core/models/user_model.dart`.
- No Firestore migration needed — existing docs without the field read as null, treated as empty map.
- Keep entries as free-form key-value strings (e.g. `"nieto": "Pablo, 8 años"`, `"ciudad": "Sevilla"`). Avoid rigid schemas — Gemini will coin keys naturally.
- **Acceptance:** `UserModel.fromMap({'context': {'ciudad': 'Sevilla'}})` produces `context == {'ciudad': 'Sevilla'}`. Round-trips through `toMap` correctly.

#### D.2 — `GeminiService`: add `guardarContexto` function declaration

- Add a second `FunctionDeclaration guardarContexto(clave: string, valor: string)` to the existing `Tool` alongside `guardarNombre`.
- In `sendMessage`, handle `guardarContexto` the same way as `guardarNombre`: send `FunctionResponse` automatically, return `contextUpdate: MapEntry<String, String>?` in `GeminiResponse`.
- Update system prompt in `startSession` to include an injected context block:
  ```
  Lo que ya sabes de [nombre]:
  - Ciudad: Sevilla
  - Nieto: Pablo, 8 años
  - Hobby: jardinería
  ```
  If `context` is empty, omit the block entirely (don't mention there is no context).
- Instruct the model in the system prompt: learn facts naturally during conversation; do not interrogate the elder; call `guardarContexto` only when confident, not on speculation.
- **Acceptance:** say "vivo en Granada" during a conversation → `guardarContexto("ciudad", "Granada")` is called → next `startSession` injects "Ciudad: Granada".

#### D.3 — `ChatController`: persist context updates

- In `sendMessage`, after receiving `GeminiResponse`, check for `contextUpdate`.
- If present: call `userRepository.updateContext(uid, key, value)` — a Firestore `update({'context.$key': value})` (dot-notation merge, no other fields touched).
- No session restart needed (unlike `guardarNombre`) — context is injected at session start, not mid-session.
- **Acceptance:** `context` map in Firestore grows incrementally across conversations.

#### D.4 — `UserRepository`: add `updateContext`

- New method `Future<void> updateContext(String uid, String key, String value)`.
- Uses `doc.update({'context.$key': value})` — Firestore dot-notation ensures atomic field-level write with no overwrite of sibling keys.
- **File:** `lib/core/repositories/user_repository.dart`.

#### D.5 — Dashboard: companion read-only context view

- Add a collapsible card in `DashboardScreen` showing the elder's context map as a key-value list.
- Read-only initially. Edit affordance can be added later if needed (low priority — the elder's natural speech is the primary input).
- Companion can use this view to understand what the app has learned and spot errors.
- **Accessibility:** companion UI, so elder accessibility rules do not apply here. Standard Material text sizes.

#### D.6 — (Optional extension) Hybrid: post-session extraction sweep

**Only implement if real-time calling misses meaningful context after real-world testing.**

How to evaluate: after a week of real usage, check if the context map captures the conversational detail you'd expect. If important facts (e.g. "her daughter visited yesterday") never get saved because Gemini didn't trigger `guardarContexto`, the hybrid is worth adding.

**If implemented:**
- On app lifecycle `paused` or an explicit session-end signal, send the conversation transcript (kept in-memory during the session as a `List<({String role, String text})>`) to a second Gemini call with a focused extraction prompt:
  > "Del siguiente fragmento de conversación, extrae todos los datos personales nuevos del usuario que no estén ya en su perfil conocido: [contexto actual]. Devuelve JSON `{\"clave\": \"valor\"}` únicamente para datos nuevos o corregidos. Si no hay nada nuevo, devuelve `{}`."
- Merge the returned map into Firestore using the same `updateContext` method.
- This step runs silently after the conversation; the elder never sees it.
- **Risk:** adds a second Gemini API call per session — evaluate cost vs. quality gain before shipping.
- **Acceptance:** a fact mentioned once during a conversation (e.g. "tengo una gata que se llama Luna") appears in the context map even if `guardarContexto` was never called during the conversation.

---

### E. Emotional analysis pipeline (HU-5)
- **Problem:** the Companion's emotional dashboard is the headline value-prop of the app and is currently 0% built.
- **Scope:**
  - Depends on (C). Reads each new `conversations/{id}.summary` and produces a sentiment / emotion classification (e.g. `{ valence, arousal, flags: [loneliness, agitation, ...] }`).
  - Pipeline candidates:
    - **Gemini** with a strict-JSON classification prompt (cheapest, single vendor).
    - **HuggingFace Inference API** with a Spanish-language emotion model (more nuanced labels, second vendor risk).
  - Write the classification back to the same conversation doc so the Dashboard can stream-aggregate trends.
  - Cloud Function on `onCreate(users/{uid}/conversations/{conversationId})` is the natural trigger.
- **UI:** new section in `DashboardScreen` rendering a 7-day mood trend + flagged sessions list.
- **Why this is HU-5, not HU-4:** entirely independent data flow; can be built in parallel with HU-4 if (C) is in place.
