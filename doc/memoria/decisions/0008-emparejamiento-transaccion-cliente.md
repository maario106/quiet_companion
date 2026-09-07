# ADR-0008 — Emparejamiento elder↔familiar: transacción de cliente (Cloud Function como estado objetivo)

- **Estado:** Superseded by ADR-0024 (2026-09-06)
- **Fecha:** 2026-04-28 (`WriteBatch` inicial; migrado a `runTransaction` en `47fd26c`/`e68b451`, 2026-07-16)
- **Ámbito:** Vinculación de perfiles (HU-1). Implementado en cliente.
- **Decisores:** Autor del TFG.
- **Evidencia:** `lib/features/onboarding/data/auth_repository.dart` (`linkCompanionToElder`),
  `firestore.rules`, HU-1 §5.2, `pending.md` §3/§7, `CLAUDE.md` (§Cross-user writes: Cloud Function only);
  commits `104eeca`, `47fd26c`, `e68b451`.
- **Relacionada con:** ADR-0003 (Firebase), ADR-0014 (proxy de Cloud Functions), ADR-0025 (reglas de
  Firestore), HU-1.

---

## Contexto

Vincular mayor y familiar exige escribir **dos documentos** (uno de cada usuario) de forma atómica.
`CLAUDE.md` y RNF-9 prescriben que las escrituras *cross-user* vivan en un servidor de confianza (Cloud
Function). No hay aún infraestructura de Cloud Functions desplegada.

## Decisión

El emparejamiento se implementa como una **`runTransaction` del cliente**: busca al mayor por `linkCode`, lo
revalida dentro de la transacción y actualiza ambos documentos (más la desnormalización del contacto de
emergencia). Se asume como **estado provisional**; el objetivo declarado es una Cloud Function callable
(hay un `// TODO` explícito en el código).

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **`WriteBatch` de cliente** (original) | Atómico, pero no puede LEER antes de escribir; incompatible con la precedencia del contacto de emergencia. |
| **Cloud Function callable** (objetivo) | Cumpliría RNF-9 (escritura *cross-user* server-side), pero exige desplegar infraestructura no disponible aún. |
| **`runTransaction` de cliente (elegida, provisional)** | Atómico y con lectura previa; desbloquea HU-1 sin infraestructura nueva. |

## Justificación

La transacción de cliente permitió avanzar HU-1 y la feature de emergencia sin bloquearlas a la espera de
Cloud Functions. La migración de `WriteBatch` a `runTransaction` fue necesaria para leer el doc del mayor
antes de escribir (precedencia *manual > companion* del contacto).

## Consecuencias

- **Negativa / reserva crítica:** **contradice las reglas de seguridad desplegadas.** `firestore.rules` solo
  permite escribir el propio doc (`isOwner`) y reserva `/pairings/` al servidor; la escritura del familiar
  sobre el doc del mayor sería **denegada** por esas reglas (HU-1 §5.2, `pending.md` §7). → auditar reglas y
  migrar a Cloud Function antes de usuarios reales.
- **Positiva:** HU-1 y emergencia funcionales sin infraestructura server-side.

## Verificación

Lógica verificada sobre un **espejo** en `auth_repository_pairing_test.dart` (la transacción real exige
emulador o `fake_cloud_firestore`). Reglas committeadas, pero en conflicto con el código.

---

## Epílogo — cómo se cerró (2026-09-06)

Esta decisión queda **superada por ADR-0024**: la vinculación se hace desde una Cloud Function callable,
`validateAndLink`, y el cliente ya no escribe en el documento de otro usuario. La reserva crítica anotada
arriba —reglas y código mutuamente contradictorios— **está resuelta**, y merece la pena dejar dicho *qué*
la resolvió, porque no fue la reserva en sí.

Lo que forzó la migración no fue el requisito incumplido, que llevaba meses escrito sin efecto, sino un
hallazgo concreto al redactar las reglas reales (ADR-0025): **las reglas de Firestore no ven las cláusulas
`where` de una consulta**, así que mientras la búsqueda del mayor por `linkCode` viviera en el cliente,
`/users` tenía que ser enumerable por cualquier sesión autenticada. El coste de esta decisión provisional
no era el que aquí se apuntó —una escritura que las reglas denegarían— sino uno mayor y no detectado: una
lectura que obligaba a dejar el directorio de usuarios abierto.

El ADR se conserva íntegro, con su reserva y su justificación de desbloqueo, porque documenta una decisión
que fue correcta en su momento —permitió cerrar HU-1 y la feature de emergencia sin infraestructura
server-side— y cuya deuda se registró antes de que nadie la cobrase.
