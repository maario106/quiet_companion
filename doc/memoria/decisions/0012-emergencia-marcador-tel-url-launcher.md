# ADR-0012 — Llamada de emergencia: lanzamiento del marcador (`tel:`) frente a marcación directa

- **Estado:** Aceptada
- **Fecha:** 2026-07-16
- **Ámbito:** Feature de emergencia. Implementado.
- **Decisores:** Autor del TFG.
- **Evidencia:** `emergency_call_spec.md`, `hu4-plan.md` §B, `pending.md` §3,
  `lib/core/services/emergency_call_service.dart`, `pubspec.yaml` (`url_launcher`),
  `android/app/src/main/AndroidManifest.xml` (`<queries>` `tel`); commit `c5b19ba`.
- **Relacionada con:** feature de emergencia; RNF-4 (interacción simple).

---

## Contexto

El botón de emergencia debe permitir llamar al 112 o a un contacto. En Flutter hay dos vías: lanzar el
marcador del sistema con el número premarcado (`tel:` vía `url_launcher`) o marcar directamente
(`flutter_phone_direct_caller` + permiso `CALL_PHONE`). Existe incertidumbre sobre si el marco regulatorio
español permite marcación directa sin confirmación, y una llamada accidental a emergencias es un coste real.

## Decisión

Se lanza el **marcador del sistema con el número premarcado** (`tel:` vía `url_launcher`), dejando la
pulsación final de llamada al usuario en la UI del sistema. **No** se solicita el permiso `CALL_PHONE`. Se
añade el bloque `<queries>` con esquema `tel` al manifest (imprescindible en Android 11+).

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Marcación directa (`CALL_PHONE`)** | Incertidumbre regulatoria en España y riesgo de llamada accidental al 112; requiere un permiso peligroso. |
| **Marcador premarcado `tel:` (elegida)** | El usuario confirma en la UI del sistema; sin permiso peligroso; menor superficie de error en plena emergencia. |

## Justificación

El paso de confirmación en la UI del sistema mitiga la llamada accidental (crítico con el 112) y evita la
incertidumbre regulatoria, a cambio de un toque extra. Coherente con la política de UX de la población
objetivo.

## Consecuencias

- **Positiva:** sin permisos peligrosos; sin llamadas accidentales; sin reglas de Firestore nuevas.
- **Negativa / coste:** un toque adicional (confirmar en el marcador). Pendiente verificación en dispositivo
  Android 11+ real (el `<queries>` no falla en todos los emuladores).

## Verificación

`emergency_call_service_test.dart` verifica la construcción del URI `tel:` (regresión del `#`). Verificación
en dispositivo físico pendiente (`pending.md` §3).
