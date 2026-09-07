# ADR-0005 — Gestión de estado e inyección de dependencias: Riverpod frente a BLoC + GetIt

- **Estado:** Aceptada
- **Fecha:** 2026-03-16 (primeros `StateNotifier`)
- **Ámbito:** *Backbone* reactivo y DI de toda la app. Implementado.
- **Decisores:** Autor del TFG.
- **Evidencia:** `doc/pdfs/Arquitectura Flutter_ FSD vs Feature-First.pdf` (recomienda BLoC + GetIt + fpdart);
  commit `232606f` (prototipo con `chat_controller`/`chat_state`); `CLAUDE.md` (§Stack: `flutter_riverpod
  ^2.5.1`, *"never upgrade to 3.x"*; RNF-12); `lib/core/providers/`, controladores `*_controller.dart`.
- **Relacionada con:** ADR-0004 (CFS), ADR-0003 (Firebase).

---

## Contexto

La arquitectura CFS (ADR-0004) exige separación estricta evento→estado y DI sin acoplar la lógica a
implementaciones concretas. La investigación arquitectónica proponía **BLoC** como gestor de estado y
**GetIt** como localizador de servicios. Había que fijar el *backbone* reactivo antes de construir las
pantallas.

## Decisión

Se usa **Riverpod** (`StateNotifier` + estado inmutable con `copyWith`; `StreamProvider` para las fuentes en
tiempo real) como gestor de estado **y** como mecanismo de inyección de dependencias: servicios y
repositorios se resuelven vía `Provider`, nunca se instancian dentro de las clases (RNF-12). Se descarta la
pila BLoC + GetIt + fpdart de la investigación.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **BLoC + GetIt + fpdart** (recomendado por la investigación) | Más ceremonia (eventos/estados explícitos, `Either`) y DI por localizador de servicios separado del gestor de estado. |
| **`setState` / Provider básico** | Insuficiente para lógica de negocio reactiva y DI testable. |
| **Riverpod (elegida)** | Un solo mecanismo cubre estado reactivo y DI; `StreamProvider` encaja directamente con los *snapshots* de Firestore. |

## Justificación

Según el autor, Riverpod resultó **más sencillo para manejar el estado de las pantallas y para conectar
(envolver) los distintos widgets y features** de forma reactiva, con un único mecanismo para estado y DI.
`StreamProvider` mapea de forma natural los *snapshots* de Firestore, lo que habilita `currentUserProvider`
como *single source of truth* (ADR-0003, HU-4).

> **Nota:** el respaldo bibliográfico formal de la comparación Riverpod vs BLoC queda **pendiente para la
> memoria del TFG**; aquí se registra la razón práctica que guió la decisión.

## Consecuencias

- **Positivas:** DI uniforme (RNF-12); reactividad Firestore→UI directa; menos *boilerplate* que BLoC.
- **Negativas / coste asumido:** **pin bloqueado en `^2.5.1`** — no se puede subir a 3.x por un conflicto con
  `scheduleNewFrame` en el entorno de desarrollo Linux (CLAUDE.md). La decisión diverge de la pila de la
  investigación, por lo que debe justificarse explícitamente ante el tribunal.

## Verificación

Todos los controladores son `StateNotifier`; los servicios se inyectan por provider (migración completada en
la estabilización, INFO.md §8.3). Analizador estático en 0 *warnings*.
