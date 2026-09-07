# ADR-0021 — Escalas discretas con nombre para la accesibilidad local del mayor

- **Estado:** Aceptada
- **Fecha:** 2026-09-06
- **Ámbito:** Ajustes del mayor (HU-3/HU-4). Cierra la deuda abierta en ADR-0013 y el `UNRESOLVED` de
  HU-3 §5.2.
- **Decisores:** Autor del TFG.
- **Evidencia:** `doc/pdfs/Solución Propuesta - Historias de Usuario.pdf` (controles *más/menos*, CU-05),
  RF-5, `CLAUDE.md` (§Accessibility), `lib/core/config/preference_scales.dart`,
  `lib/features/settings/presentation/preference_stepper_screen.dart`.
- **Relacionada con:** ADR-0013 (configuración explícita, que esta materializa), ADR-0010 (deslizadores
  del familiar), ADR-0009 (`currentUserProvider` como SSOT).

---

## Contexto

ADR-0013 decidió que la accesibilidad se configura explícitamente por una persona y nunca por inferencia de
la IA, y previó **dos** rutas: el familiar desde su panel remoto y el mayor desde su propio dispositivo. Solo
se construyó la primera. Durante casi toda la vida del proyecto, `settings_rows.dart` tuvo **una única fila**
(contacto de emergencia), de modo que CU-05/RF-5 —"el mayor independiente ajusta volumen, velocidad y tamaño
de texto con controles grandes de incremento/decremento"— seguía sin implementar.

El obstáculo no era el modelo de datos: `UserPreferences` ya guarda los tres `double` y la interfaz del mayor
ya los honra. Era la **interacción**. El familiar los mueve con `Slider`, y un `Slider` es justo el widget que
la UI del mayor no puede usar: exige arrastre, y `CLAUDE.md` §Accessibility prohíbe deslizar, mantener pulsado
y el doble toque. Hacía falta una representación distinta del mismo `double`.

Se descubrió además un agujero derivado: la fila del contacto de emergencia se oculta cuando el contacto lo
impone la vinculación (`source == companion`). Con una sola fila en el catálogo, eso dejaba la lista vacía y
`home_screen.dart:57` escondía el botón de ajustes **entero**. El mayor vinculado no tenía pantalla de ajustes
en absoluto.

## Decisión

Se introduce `PreferenceScale`: cada ajuste de accesibilidad se declara como una **escala discreta** —unos
pocos peldaños ordenados sobre el mismo `double` de `UserPreferences`, cada uno con un **nombre en castellano**
("Grande", "Muy despacio")— junto con su título, su pregunta guía y, si procede, su frase de escucha.

De ahí se derivan tres consecuencias de diseño:

1. **Una sola subpantalla para las tres escalas** (`PreferenceStepperScreen`), parametrizada por la ruta
   `/settings/preference/:id`. Añadir un cuarto ajuste es añadir una `PreferenceScale`; no añade pantalla ni
   toca el enrutador, igual que `settings_rows.dart` prometía para las filas.
2. **El mayor nunca ve el número**, solo el nombre del peldaño. El valor crudo es un detalle de
   almacenamiento compartido con el panel del familiar.
3. **Redondeo al peldaño más cercano.** El deslizador del familiar escribe valores que no caen en ningún
   peldaño (1,35 de tamaño; 0,5 de velocidad). La escala muestra el nombre más próximo en vez de un hueco, y
   los peldaños cubren el **rango completo** que el panel puede escribir, para que la primera pulsación del
   mayor no recorte en silencio un valor que otro fijó por él.

Las tres filas son visibles para **todo mayor**, vinculado o independiente.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Reutilizar el `Slider` del panel del familiar** | Exige arrastre: prohibido por `CLAUDE.md` §Accessibility y contrario al *"sin necesidad de deslizar"* del PDF de solución. Es la razón por la que la ruta local no existía. |
| **Botones +/− sobre el `double` con un paso fijo (p. ej. ±0,1)** | Obliga a enseñar el número para que la pulsación signifique algo, y diez pulsaciones para cruzar el rango. El nombre del peldaño comunica el estado; "1.4" no. |
| **Una subpantalla escrita a mano por ajuste** | Tres pantallas casi idénticas que divergen a la primera corrección. Contradice la promesa declarativa de `settings_rows.dart`. |
| **Limitar las filas al mayor independiente** (letra de CU-05) | Es lo que dice el caso de uso, pero deja al mayor **vinculado** sin ninguna fila cuando el familiar fija su contacto de emergencia — y por tanto sin botón de ajustes. Ampliar la visibilidad cierra ese agujero sin código extra. |
| **Campo `source` para arbitrar mayor vs. familiar**, como en el contacto de emergencia | Innecesario: en el contacto hay una autoridad que proteger (un teléfono equivocado es un fallo silencioso hasta el peor momento). En el tamaño de la letra no la hay — que el mayor se agrande el texto no es un error que haya que impedir. Gana la última escritura. |
| **Botón "Guardar" al final** | El mayor ya está mirando el resultado: la pantalla entera se redibuja con el tamaño elegido. Pedir que confirme lo que ya ve añade un paso sin información. |
| **Permitir volumen 0** | Un mayor que se silencia la app no encuentra un ajuste apagado, encuentra una app rota, y el fallo es mudo por definición. El peldaño más bajo (0,2) se oye. |

## Justificación

La escala discreta es la traducción entre dos interacciones legítimamente distintas sobre el mismo dato: el
familiar es un adulto con un móvil y un deslizador; el mayor necesita dos botones grandes y una palabra. Que
ambos escriban el mismo campo de Firestore mantiene la propagación en caliente de ADR-0010 intacta y sin
esquema nuevo.

La escritura usa `AuthRepository.updatePreferences`, que actualiza **solo** el campo `preferences`, en vez de
`saveUser` (que reescribe el documento entero y es la vía del familiar): el mayor no debe poder tocar de
rebote su rol, su vinculación ni su contacto de emergencia al subir el tamaño de la letra.

## Consecuencias

- **Positiva:** CU-05/RF-5 queda implementado; se cierra la deuda declarada en ADR-0013 y la desviación de
  HU-3 §5.2.
- **Positiva:** el botón de ajustes deja de desaparecer para el mayor vinculado.
- **Positiva:** añadir un ajuste futuro sigue siendo "añadir una fila", ahora también sin añadir pantalla.
- **Coste:** dos representaciones del mismo dato (continua para el familiar, discreta para el mayor) que hay
  que mantener alineadas en rango. Mitigado porque los peldaños cubren de sobra el rango del deslizador.
- **Coste:** mientras la subpantalla está abierta, el peldaño elegido localmente manda sobre lo que llegue de
  Firestore, para que un cambio simultáneo del familiar no le mueva la elección al mayor bajo el dedo. Es una
  divergencia deliberada y acotada a la vida de la pantalla.

## Verificación

`flutter analyze` sin incidencias. La suite existente (`settings_screen_test.dart`) se actualizó al nuevo
catálogo de filas. **No se añadieron tests nuevos**: decisión explícita del autor de contener el volumen de
pruebas a lo sostenible en un proyecto en solitario. La verificación de esta ADR es, por tanto, **manual en
dispositivo** y queda pendiente: recorrido de las tres escalas, escucha de la vista previa de voz y
comprobación de que el peldaño sobrevive al reinicio de la app.
