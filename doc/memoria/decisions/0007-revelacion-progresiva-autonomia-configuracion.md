# ADR-0007 — Revelación Progresiva: la autonomía es configuración, no identidad

- **Estado:** Aceptada
- **Fecha:** 2026-04-28
- **Ámbito:** Modelo de usuario y topología de pantallas del mayor. Implementado.
- **Decisores:** Autor del TFG.
- **Evidencia:** `doc/pdfs/Solución Propuesta - Historias de Usuario.pdf` (§"Onboarding Inteligente y
  Revelación Progresiva"); commit `104eeca` (onboarding dual + `HomeScreen` compartida); `lib/core/models/
  user_model.dart` (`autonomy`), `lib/features/conversation/presentation/home_screen.dart` (`showSettings`),
  `lib/core/config/app_router.dart`; TFG cap. 4 (modelo conceptual de dominio).
- **Relacionada con:** ADR-0006 (auth dual), HU-1, HU-3.

---

## Contexto

Existen dos perfiles de mayor (Independiente y Vinculado), pero construir dos aplicaciones o dos jerarquías
de pantallas duplicaría el esfuerzo de un desarrollador único. La diferencia entre ambos es de capacidad de
gestión, no de naturaleza.

## Decisión

Un **único núcleo** (la pantalla de chat por voz) sirve a ambos perfiles; la diferencia se resuelve con un
**condicional sobre el atributo `autonomy`** del `UserModel`, que **muestra u oculta** capacidades (el botón
de Ajustes) en lugar de bifurcar la app. La autonomía es un dato de configuración, no una identidad distinta
("Revelación Progresiva").

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Dos apps / dos flujos separados por perfil** | Duplica UI y lógica; inviable con el plazo. |
| **Jerarquías de pantalla distintas por rol** | Mismo problema de duplicación y divergencia futura. |
| **Núcleo compartido + condicional sobre `autonomy` (elegida)** | El núcleo es idéntico para ambos; solo se oculta/muestra el botón de Ajustes. |

## Justificación

PDF (cita literal): *"Ya que el núcleo de la app (la pantalla de chat por voz) será exactamente la misma para
ambos usuarios. Solo se oculta o muestra el botón de 'Ajustes' mediante un simple condicional if
(isIndependentMode == true) en el código."* En la implementación, `home_screen.dart` deriva `showSettings` de
`visibleSettingsRows(user)` y el router deriva el estado *onboarded* de `autonomy`; un mismo `UserModel`
cubre ambos perfiles (TFG cap. 4: *"la diferencia entre ambos es de configuración, no de identidad"*).

## Consecuencias

- **Positivas:** una sola superficie de UI que mantener; coherencia entre perfiles; base de HU-1.
- **Negativas / coste asumido:** el enum `AutonomyStatus` acabó con cuatro valores (`independent/dependent/
  linked/none`), que exceden los dos de RF-1 (deuda de modelado, HU-1 §6). Los controles de accesibilidad
  locales del mayor independiente (botones *más/menos* descritos en el PDF) siguen **sin implementar**
  (HU-3 §5.2).

## Verificación

Una única `HomeScreen` sirve a ambos perfiles; `showSettings` y el *gating* del router dependen de
`autonomy`; verificado por `test/core/config/router_redirect_test.dart`.
