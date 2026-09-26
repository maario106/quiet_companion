# SPEC — TTS swap: device TTS → Google Cloud TTS (Chirp 3: HD) via Cloud Functions proxy

_Target: Claude Code. Project: Quiet Companion (`com.rosas.quiet_companion`), Flutter + Firebase (Firestore, Anonymous Auth, Cloud Functions Node.js, FlutterFire aligned to `firebase_core` 3.x). Related ADR: `adr-tts-chirp3-hd.md`._

---

## 1. Goal

Replace the robotic device-native TTS in the elder voice chat with Google Cloud TTS **Chirp 3: HD** Spanish (es-ES) voices, synthesized server-side through the **existing Cloud Functions proxy** (no API keys in the client), behind a **`TtsService` abstraction** with a device-TTS fallback.

## 2. Non-goals (out of scope — do NOT implement)

- gRPC/streaming synthesis (chunked request/response only).
- Gemini-TTS, Gemini Live API, or any pipeline change to STT or the LLM call.
- Audio caching of synthesized phrases.
- A voice-selection UI or settings row.
- Retries with backoff on synthesis failure (project-wide rejected UX pattern — fall back instead).
- Any change to Firestore schema or security rules.

## 3. Hard constraints

1. **Additive architecture.** The conversational flow (`ChatController` and the voice loop) must not be restructured. It should end up calling a `TtsService` abstraction; only the implementation behind it changes. Keep the diff to the existing flow minimal: swap the concrete TTS call sites for the interface, nothing else.
2. **No secrets in the client.** The Cloud Function uses Application Default Credentials of the Functions runtime. Do not add any API key to Flutter code, `.env` shipped in the app, or Remote Config.
3. **Follow existing project patterns:**
   - Service abstraction: interface + production impl + fake for tests, same as `core/services/emergency_call_service.dart`.
   - DI via the existing provider pattern in `core/providers/` (as with `auth_repository_provider.dart`).
   - Firestore path constants via `FirestorePaths` are NOT needed here (no persistence).
4. **Language:** all synthesized content is Spanish (es-ES). Voice name and speaking rate live in ONE config constant file.
5. `flutter analyze` must stay at 0 issues; full test suite must stay green (currently 105 passing).

## 4. Backend — Cloud Function `synthesizeSpeech`

Location: existing Functions codebase (Node.js), same deployment unit as the Gemini proxy.

- **Type:** `onCall` (callable), consistent with `validateAndLink` and the Gemini proxy.
- **Auth:** reject unauthenticated calls (`context.auth == null` → `unauthenticated`). Anonymous auth is valid (elders are anonymous-auth users).
- **Dependency:** `@google-cloud/text-to-speech` (official client, uses ADC automatically inside Functions).
- **Input:** `{ text: string }`. Optional overrides are NOT accepted from the client — voice, language, rate are server-side constants (smaller attack/abuse surface).
- **Validation:**
  - `text` required, non-empty after trim.
  - Max length: **900 characters** per call (chunking happens client-side; this is a safety cap). Over limit → `invalid-argument`.
- **Synthesis request:**
  - `input: { text }` (plain text — Chirp 3: HD voices do not accept SSML; never wrap in SSML).
  - `voice: { languageCode: 'es-ES', name: <VOICE_NAME> }`.
  - `audioConfig: { audioEncoding: 'MP3', speakingRate: <RATE> }`.
  - **`VOICE_NAME`:** Chirp 3: HD voices follow the pattern `es-ES-Chirp3-HD-<Name>`. At implementation time, call `client.listVoices({ languageCode: 'es-ES' })` (one-off script or temporary log) to enumerate the actual available Chirp3-HD names in this project/region, pick a warm female voice, and hardcode it as a constant with a comment listing the alternatives found. Do not invent a name from memory.
  - **`RATE`:** default `1.0`. Define the constant; if the chosen Chirp 3: HD voice rejects `speakingRate` (some tiers restrict audioConfig params — verify against the API error, not assumptions), omit the field and note it in the constant's comment.
- **Output:** `{ audioContent: string /* base64 MP3 */ }`. Sentence-sized chunks are tens of KB in base64 — well within callable limits.
- **Errors:** map synthesis failures to `internal` with a generic message; log details server-side. Never echo the input text back in errors.
- **Manual prerequisite (document in the PR description, do not attempt from code):** enable the Cloud Text-to-Speech API on the GCP project. Blaze plan is already active.

## 5. Client — `TtsService` abstraction

### 5.1 Interface — `lib/core/services/tts_service.dart`

```dart
abstract interface class TtsService {
  /// Speaks [text]. Splits into sentences internally, synthesizes and plays
  /// them in order. Returns when playback of ALL chunks completes or after
  /// stop() is called. Must be safe to call while already speaking
  /// (implicitly stops the current utterance first).
  Future<void> speak(String text);

  /// Immediately stops playback, cancels all pending synthesis for the
  /// current utterance, and clears the queue. Idempotent.
  Future<void> stop();

  /// Whether an utterance is currently being played or synthesized.
  bool get isSpeaking;
}
```

Match the return-type/stream conventions of whatever contract the current device-TTS wrapper exposes to `ChatController` — if the controller currently awaits completion or listens to a completion callback to resume listening (turn-taking), the interface MUST preserve that semantic exactly. Inspect the current call sites first and adapt the interface shape if needed; the behavioral contract above is what matters, not the exact signatures.

### 5.2 Sentence chunking — pure function, `lib/core/utils/sentence_splitter.dart`

- `List<String> splitIntoSentences(String text)` — pure, no dependencies, fully unit-tested.
- Split on `.`, `!`, `?`, `…` followed by whitespace/EOL; keep the delimiter with the sentence. Handle: abbreviations are NOT worth special-casing (accept occasional over-splitting), decimal numbers must not split (`3.5`), ellipses collapse to one boundary, empty/whitespace-only segments dropped.
- **Also add `String sanitizeForSpeech(String text)`**: strip markdown artifacts the LLM may emit before synthesis — `*`, `_`, `#`, backticks, bullet dashes at line start, emojis. Applied before splitting. Unit-tested.
- Merge very short fragments (< 25 chars) into the next sentence to avoid choppy audio and wasted round trips.

### 5.3 `CloudTtsService` — `lib/core/services/cloud_tts_service.dart`

Production implementation:

- **Dependencies:** the existing callable-client pattern used for `validateAndLink` (inject `FirebaseFunctions` or the project's callable wrapper — reuse whatever seam already exists for testability), plus an audio player.
- **Audio playback:** use **`just_audio`** for MP3-from-bytes playback. If the project already depends on an audio player package for STT/earcons, reuse that instead — check `pubspec.yaml` first.
- **Pipeline (the core of this task):**
  1. `speak(text)` → sanitize → split into sentences → build chunk list.
  2. Synthesize chunk 0; start playing it as soon as it arrives.
  3. While chunk *i* plays, synthesize chunk *i+1* (prefetch of exactly one — do not fire all requests at once).
  4. Chunks play strictly in order.
- **Cancellation (`stop()`):** must (a) stop the player, (b) mark in-flight synthesis results as discarded (callables can't be aborted — use a generation counter/token: results carrying a stale generation are dropped), (c) clear the queue, (d) leave the service reusable for the next `speak()`. This is the highest-risk logic — test it thoroughly.
- **Fallback policy (per utterance, NO retries):**
  - Wrap each synthesis call in a timeout (constant, **4 s**).
  - If the FIRST chunk of an utterance fails or times out → delegate the ENTIRE original text to `DeviceTtsService.speak()` and mark the utterance as degraded (debug log only, no user-facing error).
  - If a LATER chunk fails → speak only the remaining text via `DeviceTtsService` (do not replay what was already heard). If that's disproportionately complex given the current code, simplifying to "remaining chunks are skipped silently" is acceptable — choose one, document it in a comment, and test the chosen behavior.
  - No exponential backoff anywhere (project decision).

### 5.4 `DeviceTtsService` — wrap the existing `flutter_tts` usage

- Extract the current device TTS logic into `DeviceTtsService implements TtsService` with no behavior change (es-ES locale, current rate/pitch settings preserved).
- It is both the fallback for `CloudTtsService` and the offline path.

### 5.5 `FakeTtsService` — `test/` helpers

- Records `speak`/`stop` calls and spoken texts; controllable completion (`Completer`-based) so tests can simulate long utterances and interruption. Same style as the existing emergency-call fake.

### 5.6 Config — `lib/core/config/tts_config.dart`

Single source of truth: chunk timeout (4 s), max chunk length (matching the 900-char server cap), min-fragment merge threshold (25), and a doc comment pointing to the server-side voice constant (the client never sends voice params).

### 5.7 Wiring

- `core/providers/tts_service_provider.dart`: provider exposing `TtsService`, defaulting to `CloudTtsService` (which itself holds a `DeviceTtsService` for fallback).
- Replace direct TTS calls in the voice chat flow with the provider. **Do not** alter turn-taking logic, STT triggering, or UI state transitions — if the current code resumes listening on TTS completion, the new `speak()` completing must trigger the exact same path.
- Barge-in: if the current flow stops TTS when the user starts speaking, route that through `TtsService.stop()`.

## 6. Dependencies & platform changes

- `pubspec.yaml`: add `just_audio` (skip if an equivalent player already present).
- `functions/package.json`: add `@google-cloud/text-to-speech`.
- No new Android permissions. No manifest changes expected (playback of app-generated audio needs none). Do not touch the `<queries>` block added for the emergency call.

## 7. Tests (target: all green, follow existing suite conventions)

1. `sentence_splitter_test.dart`: sanitization (markdown/emoji stripping), splitting (punctuation, decimals `3.5`, ellipsis, short-fragment merging, empty input).
2. `cloud_tts_service_test.dart` with a fake callable + fake player:
   - happy path: N sentences → N synthesis calls, played in order, `speak()` completes after last chunk;
   - prefetch: chunk i+1 requested while chunk i playing (verify via call ordering);
   - `stop()` mid-utterance: player stopped, stale in-flight result discarded (generation counter), queue cleared, service reusable;
   - `speak()` while speaking: previous utterance stopped first;
   - first-chunk failure/timeout → full text delegated to injected fallback `TtsService`;
   - later-chunk failure → chosen degraded behavior (per §5.3) verified;
   - `isSpeaking` transitions.
3. `DeviceTtsService`: thin wrapper — a smoke test around configuration is enough; do not attempt to test `flutter_tts` internals.
4. Existing `ChatController` tests must pass unchanged apart from swapping in `FakeTtsService`.

Do NOT add tests requiring real network or real Firebase.

## 8. Acceptance criteria

- [x] `synthesizeSpeech` callable deployed code-complete (deploy itself may be manual), auth-gated, 900-char cap, server-side voice constants, no SSML.
- [x] `TtsService` interface + `CloudTtsService` + `DeviceTtsService` + `FakeTtsService` in place following the emergency-call service pattern.
- [x] Voice chat flow uses the provider; zero changes to turn-taking semantics.
- [x] Sentence chunking with single-chunk prefetch; first-audio latency bounded by one synthesis round trip.
- [x] Fallback to device TTS on failure/timeout, no retries/backoff.
- [x] `flutter analyze` 0 issues; full suite green including new tests (105 → 140).
- [x] PR description lists the two manual steps: enable Cloud Text-to-Speech API in GCP; `firebase deploy --only functions`.

### Implementation status (2026-07-27)

**Deployed.** `synthesizeSpeech` is live in `europe-west1` (gen 2, `ACTIVE`), the Cloud Text-to-Speech API
is enabled, and the Function logs show real invocations with `{"auth":"VALID"}` and no synthesis errors —
which also confirms, empirically, that `es-ES-Chirp3-HD-Sulafat` exists in this project and accepts
`speakingRate`. `npm run list-voices` was never needed.

Two defects found only on device, both at the `just_audio` seam, both fixed:

1. Playback refused the in-memory audio — Android blocks cleartext to the loopback server `just_audio`
   uses. Loopback-only network-security-config (ADR-0020).
2. Multi-sentence answers played the first and last sentence only: `play()`'s future completes immediately
   when the player is already `playing`, so each chunk cut off the previous one. Sequencing now waits on
   `processingStateStream` (ADR-0017, implementation note 2026-07-27).

Deviations from this spec, each with an ADR:

- The "existing Cloud Functions proxy" did not exist; `functions/` was created from scratch with only this
  callable — ADR-0018.
- The dashboard's volume/speed sliders would have silently stopped working under §4's "no client-side
  overrides"; they are applied at the player instead — ADR-0019.
- `CloudTtsService` takes an injectable `chunkTimeout` (defaults to `kTtsChunkTimeout`) so the timeout test
  does not wait 4 real seconds.
- §6 was wrong: **a manifest change was needed.** `just_audio` serves in-memory audio over a local HTTP
  server on `127.0.0.1`, which Android blocks by default since API 28 — synthesis succeeded and playback
  failed. Fixed with a loopback-only `network-security-config` — ADR-0020.

## 9. Manual verification (post-implementation, human)

- Physical low-end Android device on mobile data: perceived first-audio latency per response; no gaps/overlap between chunks.
- Airplane mode: utterance falls back to device voice without error UI and conversation continues.
- Barge-in during a long multi-sentence response: audio stops instantly, no stale chunk plays afterwards.
- Voice quality check with an es-ES Chirp3-HD voice; if the picked voice sounds wrong for the persona, changing it is a one-constant server-side edit.