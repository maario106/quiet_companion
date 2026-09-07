# ADR-0011 — Alineación de FlutterFire a `firebase_core` 3.x

- **Estado:** Aceptada
- **Fecha:** 2026-03-17 (configuración inicial de Firebase; pin documentado en `CLAUDE.md`)
- **Ámbito:** Dependencias del ecosistema Firebase. Implementado.
- **Decisores:** Autor del TFG.
- **Evidencia:** `pubspec.yaml`, `CLAUDE.md` (§Stack — *locked*); commits `a642d44`/`d05ef03`.
- **Relacionada con:** ADR-0003 (Firebase), ADR-0005 (pin de Riverpod 2.x).

---

## Contexto

Los paquetes de FlutterFire (`firebase_auth`, `cloud_firestore`, `cloud_functions`) comparten la dependencia
transitiva de `firebase_core`. Versiones desalineadas entre ellos producen conflictos de resolución en
`pub get`.

## Decisión

Se fija todo el ecosistema a **`firebase_core` 3.x** (`^3.15.2`), con las versiones correspondientes de
`firebase_auth ^5.7.0`, `cloud_firestore ^5.6.0` y `cloud_functions ^5.4.0` alineadas entre sí. El stack
queda **bloqueado** en `CLAUDE.md`.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Versiones mixtas sin alinear** | Conflicto de resolución de dependencias; build roto. |
| **Alinear todo a `firebase_core` 3.x (elegida)** | Resolución consistente; matriz de versiones conocida y reproducible. |

## Justificación

Alinear una única línea mayor de `firebase_core` es la vía estándar para resolver el conflicto transitivo.
Junto con el pin de Riverpod 2.x (ADR-0005), forma parte de una política de **versiones bloqueadas** para la
reproducibilidad del build del TFG.

## Consecuencias

- **Positiva:** `pub get` reproducible; sin sorpresas de resolución.
- **Negativa / coste:** subir de versión mayor obliga a revalidar toda la matriz FlutterFire.

## Verificación

El proyecto compila con la matriz fijada; el stack figura como *locked* en `CLAUDE.md`.
