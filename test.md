# Test Plan — Quiet Companion

Quick reference: assumed knowledge baked into each test group. If any of these assumptions change, update the corresponding tests before running the suite.

---

## 1. `test/core/models/user_model_test.dart`

**Source:** `lib/core/models/user_model.dart`, `lib/core/models/user_preferences.dart`

### Assumed knowledge

| Assumption | Where it lives |
|---|---|
| `UserRole` enum has values `elder` and `companion`; serialized via `.name` (lowercase string) | `user_model.dart` |
| `Autonomy` enum has values `none`, `independent`, `dependent`; serialized via `.name` | `user_model.dart` |
| `name: String?` is nullable; absent from Firestore map reads as `null`, not an error | `user_model.dart:fromMap` |
| `copyWith` uses an `_unset` sentinel object so passing `name: null` actively clears the field (vs. omitting the arg which leaves it unchanged) | `user_model.dart:copyWith` |
| `linkCode: String?` and `linkedPartnerId: String?` are both nullable with the same sentinel pattern | `user_model.dart:copyWith` |
| `preferences` is a nested `UserPreferences` object; `toMap` serializes it inline (not as a subcollection reference) | `user_model.dart:toMap` |
| `UserPreferences` has three `double` fields: `volume`, `speechRate`, `textSizeMultiplier` | `user_preferences.dart` |
| `UserPreferences` has a `copyWith` with the same sentinel pattern | `user_preferences.dart:copyWith` |

### Tests

- `fromMap` deserializes all fields correctly including nullable ones
- `toMap → fromMap` round-trips without data loss
- `copyWith` with a named field only changes that field
- `copyWith(name: someValue)` updates name; `copyWith()` without name leaves it unchanged
- `copyWith` with `name: null` explicitly clears the field (sentinel in effect)
- `UserPreferences.fromMap → toMap` round-trips
- `UserPreferences.copyWith` changes only the specified field

### Break triggers
- Adding a new non-nullable field to `UserModel` or `UserPreferences` without a default → `fromMap` tests will fail if the test map doesn't include it.
- Changing `copyWith` away from the `_unset` sentinel pattern → null-clearing tests will fail.
- Renaming enum values → serialization round-trip tests will fail.

---

## 2. `test/features/dashboard/dashboard_controller_test.dart`

**Source:** `lib/features/dashboard/domain/dashboard_controller.dart`

### Assumed knowledge

| Assumption | Where it lives |
|---|---|
| `updateElderPreferences` performs an optimistic update: `state.linkedElder` reflects the new prefs **before** the `await saveUser()` call | `dashboard_controller.dart` |
| On `saveUser` error: `state.linkedElder` is reverted to the snapshot taken before the optimistic update, AND `state.errorMessage` is set | `dashboard_controller.dart` |
| If `state.linkedElder == null` when `updateElderPreferences` is called, the method returns early with no state change and no repository call | `dashboard_controller.dart` |
| `dashboardControllerProvider` reads `linkedElderId` from `currentUserProvider.valueOrNull?.linkedElderId` (not from `companionAuthControllerProvider`) | `dashboard_controller.dart:provider` |
| The controller calls `refreshElderData()` in `_init()` if `_elderId != null`; stays in loading state if `_elderId == null` | `dashboard_controller.dart:_init` |
| `saveUser` is the repository method used for persisting preference updates | `auth_repository.dart` |

### Tests

- Happy path: calling `updateElderPreferences` updates `state.linkedElder.preferences` optimistically, and `saveUser` is called exactly once
- Rollback: if `saveUser` throws, `state.linkedElder` reverts to the pre-call value and `errorMessage` is non-null
- No-op: calling `updateElderPreferences` when `state.linkedElder == null` does not call `saveUser` and does not change state

### Break triggers
- Moving the optimistic update to **after** the await → ordering assertion in happy-path test fails.
- Changing the rollback to only set `errorMessage` without reverting `linkedElder` → rollback test fails.
- Switching the provider to read elder ID from a different provider → the test's `ProviderContainer` override stops isolating correctly.

---

## 3. `test/features/onboarding/auth_repository_pairing_test.dart`

**Source:** `lib/features/onboarding/data/auth_repository.dart` — `linkCompanionToElder`

### Assumed knowledge

| Assumption | Where it lives |
|---|---|
| Pairing queries `usersCollection` for a document where `linkCode == code` | `auth_repository.dart:linkCompanionToElder` |
| On match: uses a `WriteBatch` — companion doc gets `linkedPartnerId = elderId`; elder doc gets `linkCode: null` and `linkedPartnerId = companionId` | `auth_repository.dart:linkCompanionToElder` |
| On no match (code not found): throws an exception (check exact type in code — likely a generic `Exception`) | `auth_repository.dart:linkCompanionToElder` |
| `FirestorePaths.usersCollection` is the collection name constant used throughout (never an inline string) | `lib/core/constants/firestore_paths.dart` |
| `updateName(uid, name)` uses Firestore `.update({'name': name})` — field-level write, does not overwrite other fields | `auth_repository.dart:updateName` |
| `signOut()` calls `FirebaseAuth.signOut()` | `auth_repository.dart:signOut` |
| `currentUid()` returns `_auth.currentUser?.uid` synchronously | `auth_repository.dart:currentUid` |

### Tests

- Valid code: `linkCompanionToElder` writes the correct fields to both documents in a single batch, no exception thrown
- Invalid code: `linkCompanionToElder` throws when no document matches the code
- `updateName`: only the `name` field is written; other fields in the document are not touched

### Break triggers
- Changing the batch write fields (e.g. keeping `linkCode` on the elder after linking) → field assertion tests fail.
- Moving from a query-based lookup to a direct doc read → test setup (fake Firestore seeding) stops triggering the match.
- Switching from `.update()` to `.set()` in `updateName` → test verifying no other fields are overwritten may fail depending on fake Firestore behavior.

---

## 4. `test/core/config/router_redirect_test.dart`

**Source:** `lib/core/config/app_router.dart` — `RouterNotifier.redirect()`

### Assumed knowledge

| Assumption | Where it lives |
|---|---|
| Router reads elder state from `elderAuthControllerProvider` AND real-time user data from `currentUserProvider`; `currentUserProvider` has priority | `app_router.dart:RouterNotifier` |
| Router reads companion state from `companionAuthControllerProvider` | `app_router.dart:RouterNotifier` |
| Elder redirect rules (in order): no Firebase user → `/`; user exists but `autonomy == none` → `/onboarding`; `independent` → `/home`; `dependent` with `linkCode != null` (not yet linked) → waiting screen; `dependent` with `linkedPartnerId != null` → `/home` | `app_router.dart:redirect` |
| Companion redirect rules: `status == idle` and no Firebase user → `/`; `status == authenticated` (no elder linked) → `/companion/pairing`; `status == linked` → `/dashboard` | `app_router.dart:redirect` |
| Routes used as redirect targets: `/` (splash), `/onboarding`, `/home`, `/companion/choice`, `/companion/pairing`, `/dashboard` | `app_router.dart:routes` |
| `RouterNotifier` calls `notifyListeners()` when `currentUserProvider` or either auth controller changes | `app_router.dart:RouterNotifier` |

### Tests

- Unauthenticated (no Firebase user) → redirects away from protected routes
- Elder, `autonomy == none` → redirects to `/onboarding`
- Elder, `autonomy == independent` → redirects to `/home`
- Elder, `autonomy == dependent`, `linkCode != null`, `linkedPartnerId == null` → redirects to pairing wait screen
- Elder, `autonomy == dependent`, `linkedPartnerId != null` → redirects to `/home`
- Companion, `status == authenticated` → redirects to `/companion/pairing`
- Companion, `status == linked` → redirects to `/dashboard`

### Break triggers
- Adding a new auth status or autonomy value without updating redirect conditions → new state falls through to an unexpected route, tests catch it.
- Changing the route strings (e.g. `/home` → `/elder/home`) → every redirect assertion that checks the target string fails.
- Changing the priority between `currentUserProvider` and `elderAuthControllerProvider` data → tests that rely on `currentUserProvider` overriding stale controller state fail.

---

## 5. Suite de llamada de emergencia y ajustes (añadida 2026-07-16)

**Source:** `lib/core/models/emergency_contact.dart`, `lib/core/services/emergency_call_service.dart`, `lib/core/config/settings_rows.dart`, `lib/features/emergency/presentation/`, `lib/features/settings/presentation/`

### Assumed knowledge

| Assumption | Where it lives |
|---|---|
| `EmergencyContact.fromMapOrNull` devuelve `null` si falta `phone` (nunca construye contacto inválido); `source` desconocido → `manual` | `emergency_contact.dart` |
| Validación E.164 española: 9 dígitos, primero `[6-9]`, rechaza números de emergencia (112, 091…) | `EmergencyContact.normalizeSpanishPhone` |
| `UserModel.toMap()` **omite** la clave `emergencyContact` cuando es null | `user_model.dart:toMap` |
| El URI de marcación se construye con `Uri(scheme:, path:)` — un `#` se escapa, no trunca | `emergency_call_service.dart:buildTelUri` |
| `EmergencyScreen` para TTS/STT al montar (via providers inyectables) y nunca usa SnackBar para errores | `emergency_screen.dart` |
| La visibilidad del botón de ajustes de `HomeScreen` y las filas de `SettingsScreen` salen de la misma función `visibleSettingsRows` | `settings_rows.dart` |
| `ElevatedButton.icon` construye una subclase privada → en widget tests usar `find.bySubtype<ElevatedButton>()`, no `byType` | `emergency_screen_test.dart` |

### Tests

- `emergency_contact_test.dart` — normalización/rechazo de teléfonos, `fromMapOrNull` defensivo, round-trip, `==`/`hashCode`, integración con `UserModel` (omisión de clave, sentinel `copyWith`).
- `emergency_call_service_test.dart` — construcción del URI `tel:` (regresión del `#`).
- `emergency_screen_test.dart` — render por estado del contacto (companion/manual idénticos, sin contacto → solo 112), marcación vía fake, error persistente sin SnackBar, Cancelar cierra la ruta, TTS/STT parados al montar.
- `settings_screen_test.dart` — `visibleSettingsRows` (función compartida), filas por `source`, navegación a la subpantalla.

### Break triggers
- Añadir una segunda fila a `settingsRows` → los conteos de filas y la visibilidad del botón cambian; revisar asserts de `hasLength(1)`.
- Cambiar los textos de botón ("Llamar al 112", "Cancelar", "Sin configurar") → finders de texto fallan.
- Hacer que la vinculación escriba contacto sin teléfono del familiar → invariante de `fromMapOrNull` deja de cubrir el caso.

---

## Summary table

| Test file | Type | External deps needed | Stable? |
|---|---|---|---|
| `user_model_test.dart` | Pure unit | None | Yes — no planned changes |
| `dashboard_controller_test.dart` | Unit + fake repo | Fake `AuthRepository` | Yes — `updateElderName` is new but isolated |
| `auth_repository_pairing_test.dart` | Unit + fake Firestore | `fake_cloud_firestore` or manual fake | Yes — pairing logic is complete |
| `router_redirect_test.dart` | Unit + provider overrides | `ProviderContainer` | Mostly — re-check if a new role/autonomy value is added |
| `emergency_contact_test.dart` | Pure unit | None | Yes |
| `emergency_call_service_test.dart` | Pure unit (solo URI) | None | Yes — el plugin no se testea |
| `emergency_screen_test.dart` | Widget + fakes | Fakes de `EmergencyCallService`/`TtsService`/`SpeechService` | Yes — servicios inyectables por provider |
| `settings_screen_test.dart` | Widget + función pura | `GoRouter` mínimo en el test de navegación | Re-check al añadir filas de ajustes |

**Not tested yet (intentionally deferred):**
- `GeminiService` — will gain `guardarContexto` function declaration in PLAN.md §D
- `ChatController` — will change when context profile is added
- `DashboardController.updateElderName` — new; worth one more session before locking down
- `AuthRepository.linkCompanionToElder` (2026-07-16) — ahora es `runTransaction` con desnormalización del contacto y precedencia manual-vs-companion. Testearlo de verdad exige `fake_cloud_firestore` (dependencia nueva, no autorizada por el spec) o el emulador. La precedencia se verifica manualmente en dispositivo; el resto de la lógica (modelo, visibilidad) sí está cubierto.
