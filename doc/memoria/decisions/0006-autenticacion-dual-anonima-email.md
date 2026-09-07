# ADR-0006 — Autenticación dual: anónima ligada al dispositivo (mayor) y email/contraseña (familiar)

- **Estado:** Aceptada
- **Fecha:** 2026-03-17
- **Ámbito:** Identidad y sesión de ambos roles. Implementado.
- **Decisores:** Autor del TFG.
- **Evidencia:** `doc/pdfs/Justificación del Stack Tecnológico.pdf` §2; commits `00dcc61` (lógica de user y
  auth), `a642d44` (Firebase configurado), `c117166` (`SignOutButton`, fix re-login); `lib/features/
  onboarding/data/auth_repository.dart`, `lib/core/widgets/sign_out_button.dart`; `CLAUDE.md` (§Auth
  strategy); INFO.md §8.1, §9.4.
- **Relacionada con:** ADR-0003 (Firebase), ADR-0007 (revelación progresiva).

---

## Contexto

Los dos actores tienen necesidades opuestas. El mayor debe poder usar la app **sin fricción de registro**
(recordar correo y contraseña es una barrera real para el público objetivo). El familiar sí necesita una
cuenta portable entre dispositivos para gestionar al mayor en remoto.

## Decisión

Autenticación **dual**: el mayor usa **Firebase Anonymous Auth** (identidad ligada al dispositivo, cero
registro); el familiar usa **email/contraseña**. Corolario arquitectónico: **el mayor no tiene logout** —
cerrar sesión generaría un UID nuevo y perdería su perfil—; por eso `SignOutButton` solo se monta en
pantallas del familiar.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Email/contraseña también para el mayor** | Barrera de registro y de memoria para personas mayores; contradice la UX *voice-first*. |
| **Sin autenticación (solo local)** | Imposible sincronizar mayor↔familiar entre dispositivos (HU-4). |
| **Dual anónima + email (elegida)** | Registro nulo para el mayor; cuenta portable para el familiar; ambos sobre Firebase Auth sin cifrado propio. |

## Justificación

PDF §2: la autenticación de Firebase gestiona *"el 'Modo Familiar/Tutor' y el 'Modo Independiente' de forma
segura sin tener que programar la lógica de encriptación de credenciales desde cero."* La prohibición de
logout del mayor deriva directamente de la naturaleza *device-bound* de la identidad anónima.

## Consecuencias

- **Positivas:** onboarding del mayor sin fricción; el familiar entra desde cualquier dispositivo.
- **Negativas / coste asumido:** la identidad del mayor es **frágil** — una reinstalación genera un UID nuevo
  (en producción el usuario real no reinstala; en desarrollo obligó a un script de borrado masivo de cuentas
  anónimas, INFO.md §9.5)—. No hay migración de la cuenta del mayor entre dispositivos. Un *reset* del mayor
  debe ser una acción explícita de borrado de datos, no un logout.

## Verificación

`signInAnonymously` (mayor) y `signInWithEmail`/`registerWithEmail` (familiar) operativos; `SignOutButton`
ausente en `HomeScreen`. Bug de re-login del familiar (vinculado enviado a la pantalla de código) corregido
en `c117166` (INFO.md §9.4).
