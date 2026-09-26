# ADR-0027 — El panel del familiar escucha al mayor en tiempo real y escribe solo el campo que cambia

- **Estado:** Aceptada — pendiente de implementación
- **Fecha:** 2026-09-26
- **Ámbito:** Panel del familiar (HU-4). Requisito previo de HU-5 y HU-6: sin él, ningún campo nuevo del
  documento del mayor sobrevive a un deslizador.
- **Decisores:** Autor del TFG.
- **Evidencia:** `lib/features/dashboard/domain/dashboard_controller.dart` (`_init` → `refreshElderData` →
  `getUser`, una única lectura; `updateElderPreferences` → `saveUser`),
  `lib/features/onboarding/data/auth_repository.dart` (`saveUser` = `set(user.toMap())`), `firestore.rules`
  (regla 2 de `update`), observación del autor (*"la UI no muestra el valor que hay"*). Commits: pendientes.
- **Relacionada con:** ADR-0009 (SSOT), ADR-0010 (escritura optimista con *rollback*), ADR-0021 (escalas
  locales del mayor), ADR-0023 (misma lección: dependencia más gruesa de lo pretendido), ADR-0025 (reglas).

---

## Contexto

El panel del familiar lee el documento del mayor **una sola vez**, al construirse `DashboardController`, y lo
guarda como `state.linkedElder`. Nada vuelve a leerlo: `refreshElderData` no tiene más llamante que `_init`.
Cada deslizador escribe después con `saveUser`, que es un `set()` del documento **entero** a partir de esa
copia.

Mientras el familiar era el único que escribía en el documento del mayor, la copia no envejecía. Ya no es así:

- el mayor mueve sus propias escalas de accesibilidad desde Ajustes (ADR-0021);
- el mayor edita su contacto de emergencia (`updateEmergencyContact`);
- Gemini aprende su nombre a mitad de conversación (`guardarNombre` → `updateName`).

Consecuencias observables, todas con el panel ya abierto:

1. **El familiar no ve los cambios del mayor.** Es el síntoma que el autor describe como que la interfaz no
   muestra el valor real.
2. **El siguiente deslizador los revierte.** `saveUser` reescribe `preferences` y `name` con los valores de la
   copia. Las reglas lo permiten —son justo los dos campos que el familiar puede tocar— y nadie se entera: el
   mayor vuelve a tener la letra pequeña, o deja de tener nombre.
3. **O la escritura falla entera.** Si el mayor cambió su contacto de emergencia, el `set()` lo devuelve al
   valor antiguo, `changed()` incluye `emergencyContact`, la regla deniega y el panel enseña "Error al
   guardar". El familiar no puede ajustar nada hasta reiniciar la app.
4. **Todo campo nuevo del mayor cae en el caso 3.** HU-5 y HU-6 añaden el consentimiento, el nivel de lo
   que ve el familiar y los plazos de la conversación (ADR-0030, ADR-0031, ADR-0034). Con este camino de
   escritura, cada uno sería una fuente nueva de "Error al guardar" en los deslizadores.

## Decisión

1. **Una fuente de verdad del mayor en el lado del familiar.** Un `linkedElderProvider`
   (`StreamProvider<UserModel?>` en `core/providers/`), derivado del `linkedElderId` que emite
   `currentUserProvider`, escucha `users/{elderId}`. Es al familiar lo que `currentUserProvider` es al propio
   usuario (ADR-0009). Las reglas ya lo permiten: `allow get` cubre la escucha de un documento concreto.
2. **El panel pinta desde el *stream*, no desde una copia.** `DashboardController` deja de guardar
   `linkedElder`; conserva solo estado de la vista (errores de guardado).
3. **Cada control escribe solo su campo**, con `update()` y ruta de punto (`preferences.volume`), de modo que
   dos escrituras simultáneas sobre magnitudes distintas no se pisan. `saveUser` queda solo para **crear** el
   documento (onboarding del mayor, registro del familiar).
4. **La honestidad de ADR-0010 se conserva y cambia de mecanismo.** Con un *stream* delante, la compensación
   de latencia de Firestore ya enseña el valor escrito al instante y, si el servidor rechaza la escritura,
   revierte la caché local y emite el valor real. El *rollback* manual del controlador sobra; el controlador
   solo tiene que mostrar el mensaje de error. La mitad `onChangeEnd` de ADR-0010 no cambia.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Refrescar la copia al volver al panel o con *pull-to-refresh*** | Acorta la ventana en la que la copia está vieja, pero no la cierra, y el `set()` completo sigue revirtiendo lo que otro escribió entretanto. Trata el síntoma. |
| **`set(..., SetOptions(merge: true))`** | Fusionar sigue escribiendo **todos** los campos que se envían, con sus valores viejos. Solo deja de borrar los que no se envían. |
| **Ampliar la lista de campos que el familiar puede escribir** | Haría pasar la escritura del caso 3 a cambio de dar al familiar poder sobre el contacto de emergencia y los campos de privacidad. Es lo contrario de ADR-0025. |
| **Transacción de lectura-modificación-escritura en cada deslizador** | Correcta, pero pesada para un ajuste de volumen. Con datos frescos y escritura por campo, no hay nada que arbitrar. |
| **Que `DashboardController` abra su propio *stream*** | Prohibido por ADR-0009: los controladores no abren *streams*; los datos llegan por providers. |

## Justificación

El defecto no es de la interfaz sino del modelo de escritura: una copia de lectura única usada como base de
una escritura completa solo es correcta si nadie más escribe, y desde ADR-0021 el mayor escribe. Es la misma
lección que ADR-0023 dejó para las dependencias de lectura —observar solo lo que se necesita—, aplicada a
las escrituras: **escribir solo lo que se ha cambiado.**

## Consecuencias

- **Positiva:** el familiar ve en vivo lo que el mayor ajusta, y un deslizador ya no deshace nada.
- **Positiva:** añadir campos al documento del mayor vuelve a ser seguro. Es el requisito previo de
  ADR-0030, ADR-0031 y ADR-0034.
- **Positiva:** `_SettingSlider.didUpdateWidget` (reconciliar un cambio externo cuando no se arrastra) por
  fin tiene cambios externos que reconciliar.
- **Coste:** una escucha permanente más en el dispositivo del familiar.
- **Coste:** `dashboard_controller_test.dart` cuenta llamadas a `saveUser` y prueba el *rollback* manual; esos
  casos se reescriben contra el nuevo camino de escritura.

## Verificación

Criterio de cierre, manual con dos dispositivos (o dos emuladores contra el emulador de Firebase):

1. Con el panel abierto, el mayor cambia el tamaño de letra en Ajustes → el deslizador del familiar se mueve
   solo en un segundo o menos.
2. A continuación el familiar mueve el volumen → el tamaño de letra del mayor **no** cambia.
3. El mayor edita su contacto de emergencia; el familiar mueve un deslizador → se guarda sin error.
4. Contra el emulador, con las reglas modificadas para denegar la escritura del familiar, este mueve un
   deslizador → el deslizador vuelve al valor real y aparece el mensaje de error. (Sin red la escritura no
   se rechaza: queda en cola y se aplica al reconectar. No es el mismo caso.)

Automático: `flutter analyze` sin incidencias y los tests del controlador reescritos en verde.
