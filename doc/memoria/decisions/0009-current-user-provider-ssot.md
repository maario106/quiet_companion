# ADR-0009 — `currentUserProvider` como *Single Source of Truth* reactivo

- **Estado:** Aceptada
- **Fecha:** 2026-04-28 (creado en `96cfd57`; consolidado en `c117166`, 2026-05-13)
- **Ámbito:** Lectura del documento de usuario en toda la app. Implementado.
- **Decisores:** Autor del TFG.
- **Evidencia:** `lib/core/providers/current_user_provider.dart`, `hu4-plan.md` §2.1, INFO.md §4/§8.5,
  `CLAUDE.md` (§Reactive Backbone); commits `96cfd57`, `c117166`.
- **Relacionada con:** ADR-0005 (Riverpod), ADR-0003 (Firebase).

---

## Contexto

Varias partes de la app necesitan el documento `users/{uid}` en tiempo real (TTS, tamaño de texto, router,
dashboard). Si cada controlador abre su propio stream a Firestore, se duplican escuchas y se viola la
responsabilidad única. De hecho, `ElderAuthController` mantenía su propia suscripción en paralelo.

## Decisión

Un único `currentUserProvider` (`StreamProvider<UserModel?>`) sobre `users/{uid}` (derivando el uid de
`firebaseAuthUserProvider`) es la **única fuente de verdad** del documento de usuario. Cualquier widget hace
`ref.watch(currentUserProvider)`; **los controladores dejan de mantener streams propios** —
`ElderAuthController` pasa a reaccionar solo a `authStateChanges()` con una lectura puntual inicial—.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Stream propio por controlador** | Escuchas duplicadas al mismo doc; viola SRP; el router usaba datos obsoletos del controlador. |
| **Provider único SSOT (elegida)** | Una sola escucha; cualquier consumidor la comparte; el router prioriza el dato en vivo. |

## Justificación

El patrón encaja con Riverpod (ADR-0005): un `StreamProvider` reconstruye solo a sus observadores cuando
Firestore emite. Efecto observable: al vincular al mayor (borrado de `linkCode`), el router redirige a
`/home` automáticamente sin acción del mayor (INFO §8.5).

## Consecuencias

- **Positiva:** propagación en caliente de preferencias (HU-4) y desbloqueo reactivo del onboarding (HU-1),
  sin duplicación de escuchas.
- **Negativa / deuda:** la ruta `'users'` está hardcodeada en `current_user_provider.dart` en vez de usar
  `FirestorePaths` (`pending.md` §7).

## Verificación

`router_redirect_test.dart` cubre la prioridad de `currentUserProvider` sobre el estado del controlador.
`_userSubscription` eliminado de `ElderAuthController` (INFO §8.5).

## Epílogo — la misma idea, del lado del familiar (2026-09-26)

ADR-0027 extiende el patrón al documento que el familiar observa: un `linkedElderProvider` en `core/providers/`
escuchará `users/{linkedElderId}` y será la fuente de verdad del mayor en el panel. Sustituye a la lectura
única de `DashboardController`, que es una copia fuera de esta fuente de verdad. ADR-0032 añade un tercer
provider del mismo tipo, `elderMemoryProvider`, sobre `users/{uid}/memory/profile`. En los tres casos se
mantiene la regla de este ADR: los controladores no abren *streams*, los reciben.
