# ADR-0034 — Los plazos de la conversación los fija el familiar o el mayor independiente, dentro de márgenes que impone el servidor

- **Estado:** Aceptada — implementada el 2026-09-26, pendiente de verificación en dispositivo
- **Fecha:** 2026-09-26
- **Ámbito:** HU-5 y HU-6. Configuración del cierre por inactividad (ADR-0028) y del plazo de conservación
  (ADR-0029); RNF-10 (limitación del plazo de conservación).
- **Decisores:** Autor del TFG.
- **Evidencia:** decisión del autor del 2026-09-26 (*"los plazos me parecen correctos, pero que sean
  parametrizables en ajustes, bien por el companion, o por el elder independiente"*); TFG cap. 4, RNF-10 (nota
  pendiente: *"documentar […] periodos de retención"*); `lib/core/config/preference_scales.dart` y
  `settings_rows.dart`. Implementación: `core/models/conversation_settings.dart`, `core/config/settings_rows.dart`,
  `features/privacy/presentation/choice_screen.dart`, `dashboard/presentation/conversation_settings_card.dart`,
  `auth_repository.dart` (`updateConversationSettingField`), `firestore.rules`. Commits: fase 4 de `doc/plan/ACTIVE.md`, SHA pendiente.
- **Relacionada con:** ADR-0007 (revelación progresiva según `autonomy`), ADR-0021 (escalas con nombre; aquí
  se decide lo contrario sobre la visibilidad), ADR-0027 (escritura por campo desde el panel), ADR-0028,
  ADR-0029, ADR-0030, ADR-0025 (reglas).

---

## Contexto

El diseño fija dos plazos: **5 minutos** sin turnos para cerrar una conversación y **90 días** de
conservación de lo analizado. El autor los aceptó como valores por defecto y pidió que se puedan configurar,
desde el panel del familiar o, si el mayor es independiente, desde sus propios Ajustes.

Los dos plazos no son de la misma naturaleza. La inactividad es un parámetro de **experiencia**, de la familia
del volumen o la velocidad de la voz. La conservación es un parámetro de **gobierno de los datos del mayor**.

## Decisión

1. **Dos valores en un mapa propio del documento del mayor**, `conversationSettings`, con peldaños con nombre
   (patrón de ADR-0021):
   - `inactivityMinutes` ∈ {2, **5**, 10, 15}: "Muy poco", "Normal", "Un rato", "Mucho rato";
   - `retentionDays` ∈ {30, 60, **90**, 180}: "Un mes", "Dos meses", "Tres meses", "Seis meses".

   Van en un mapa aparte y no en `preferences` porque `preferences` significa accesibilidad de percepción
   (ADR-0013, ADR-0021): la leen el TTS y el tamaño de texto. Mezclar ahí el gobierno de datos haría que el
   mismo campo significara dos cosas.
2. **Quién los cambia** (revelación progresiva, ADR-0007):
   - **mayor vinculado:** su familiar, desde el panel, con un selector de los mismos peldaños. Las reglas
     amplían la lista del familiar a `['preferences', 'name', 'conversationSettings']`. La escritura es por
     campo, como exige ADR-0027;
   - **mayor independiente:** él mismo, desde dos filas nuevas de Ajustes visibles solo con
     `autonomy == independent`.

   El mayor vinculado **ve** los valores vigentes, en la pantalla de detalle de "Guardar mis conversaciones",
   pero no los cambia.
3. **Márgenes del servidor.** `closeConversation` acota la conservación a **[30, 180] días** diga lo que diga
   el documento. El cliente acota la inactividad a [2, 15] minutos. Un valor fuera de la lista de peldaños se
   redondea al más cercano, como en ADR-0021.
4. **Cuándo surten efecto:**
   - la inactividad, en el siguiente temporizador;
   - la conservación, en las conversaciones nuevas (su `expireAt`) **y** en las existentes en el siguiente
     cierre, que borra lo que quede fuera del plazo vigente (ADR-0029). Acortar el plazo borra de verdad sin
     esperar a que caduque lo antiguo.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Constantes fijas en el código** | El autor quiere poder ajustarlas tras las pruebas y según cada mayor. |
| **Que los cambie solo el mayor, también el vinculado** | Coherente con que los datos son suyos, pero el autor asigna la gestión al familiar en modo vinculado, como las preferencias de voz. El mayor conserva los controles fuertes (retirar el consentimiento, que lo borra todo, y decidir qué ve su familiar), así que el familiar gestiona la duración pero no el acceso. |
| **Visibles para todo mayor**, como las escalas de ADR-0021 | Allí se trataba de lo que el mayor ve y oye, y ocultárselo le dejaba sin control sobre su propia percepción. Aquí, mostrárselo al vinculado crearía dos personas escribiendo el mismo parámetro de gobierno de datos, con la última escritura ganando en silencio. |
| **Guardarlos dentro de `preferences`** | Ahorraría tocar las reglas, a cambio de que un campo mezclara accesibilidad y gobierno de datos. |
| **Conservación sin tope superior** | El familiar podría conservar indefinidamente los datos de otra persona. El tope es la protección mínima de RNF-10. |
| **Aplicar un cambio de plazo solo a lo nuevo** | Quien acorta el plazo espera que lo antiguo se borre. Con solo el TTL, podría seguir ahí hasta seis meses. |

## Justificación

Se respeta la asignación de papeles que el autor ya estableció en HU-4: en modo vinculado, el familiar
gestiona la configuración, y en modo independiente la gestiona el mayor. La diferencia de este caso es que uno
de los parámetros afecta a datos personales. Por eso lleva un tope que ningún papel puede superar, y por eso
el mayor, aunque no lo cambie, siempre puede verlo.

## Consecuencias

- **Positiva:** los dos plazos se ajustan tras las pruebas sin publicar la app.
- **Positiva:** RNF-10 gana un plazo de conservación concreto, visible y acotado, que la memoria del TFG puede
  citar.
- **Coste:** una clave más en la lista de campos del familiar en las reglas, con sus tests; dos filas de
  Ajustes y un selector nuevo en el panel.
- **Tensión declarada:** el mayor vinculado consiente con el plazo vigente en ese momento (ADR-0030), y su
  familiar puede alargarlo después, hasta 180 días. El texto del consentimiento lo advierte ("entre uno y seis
  meses; lo decide tu familiar"), y la pantalla de detalle muestra siempre el valor actual.

## Verificación

Criterio de cierre:

- Reglas contra el emulador: el familiar vinculado escribe `conversationSettings` y sigue sin poder escribir
  `conversationConsent` ni `companionSharing`.
- `node --test` sobre el acotado de la conservación y el corte de borrado.
- Test de visibilidad de las filas de Ajustes: independiente sí, vinculado no.
- Manual: cambiar la inactividad a 2 minutos desde el panel → la siguiente conversación del mayor se cierra a
  los 2 minutos.

## Implementación (2026-09-26)

- Las etiquetas de la inactividad son **minutos concretos** ("5 minutos") y no los nombres previstos ("Normal",
  "Un rato"): a diferencia del volumen o la velocidad, aquí el número significa algo para quien lo lee. La
  conservación mantiene sus nombres ("Tres meses"), que ya eran concretos.
- Las dos filas de Ajustes del mayor independiente solo aparecen con el consentimiento activo: sin él no hay
  nada que cerrar ni que conservar.
