# HU-3 — Interfaz Accesible y Comprensible

- **Estado:** Completada (estabilizada; con desviaciones registradas en §5–§6).
- **Ámbito:** Implementado. HU **transversal**: no genera casos de uso propios (tab:trazabilidad),
  sino restricciones de accesibilidad que se materializan como RNF-1 a RNF-5 y como el indicador visual de
  estado (RF-4, compartido con HU-2).
- **Requisitos cubiertos:** RNF-1 (WCAG 2.2 AA), RNF-2 (áreas táctiles ≥ 80×80), RNF-3 (tipografías mínimas
  con multiplicador), RNF-4 (interacción por pulsación simple), RNF-5 (idioma es-ES), RF-4 (indicación
  visual del estado del asistente).
- **Evidencia (commits):** `f400e3c` (primer `app_theme.dart`), `104eeca` (`user_preferences.dart`),
  `c117166` (expansión mayor de `app_theme.dart` con constantes WCAG y tema dual, rediseño de `home_screen`),
  `708d71a` (aplicación de `textScale` en home/dashboard), `a5756de` (shell de ajustes accesible),
  `53e6dbd` (pantalla de emergencia con tokens de contraste AAA).
- **Evidencia (código):** `lib/core/theme/app_theme.dart`, `lib/core/models/user_preferences.dart`,
  `lib/features/conversation/presentation/home_screen.dart`, `lib/features/settings/presentation/settings_screen.dart`,
  `lib/core/config/settings_rows.dart`, `lib/features/emergency/presentation/emergency_screen.dart`.
- **Evidencia (fuentes documentales):** `INFO.md §9.1` (elección de paleta cálida), `INFO.md §9.3`
  (rediseño accesible de `HomeScreen`), TFG `04-Analisis-y-Especificacion-del-Sistema.tex` (RNF-1–5, RF-4,
  §tab:trazabilidad y su nota sobre HU-3).

---

## 1. Qué entregó la HU

HU-3 no es una pantalla ni un flujo: es el **sistema de diseño accesible** que envuelve todo lo que ve el
mayor. Se materializa en cuatro decisiones sostenidas a lo largo del código:

1. **Un tema separado y deliberadamente accesible para el mayor** (`elderTheme`), distinto del tema del
   familiar (`companionTheme`, Material 3 convencional). La interfaz del mayor usa tipografías grandes de
   piso fijo, botones de gran superficie, colores cálidos de alto contraste y una única forma de
   interacción: la pulsación.
2. **Parámetros de accesibilidad configurables** (`UserPreferences`) que la interfaz honra en caliente
   (tamaño de texto, volumen y velocidad de voz).
3. **Indicación multicanal del estado del asistente** (RF-4): el estado *Escuchando / Pensando / Hablando*
   se comunica simultáneamente por texto, por color y por icono, no por un único canal.
4. **Idioma español (es-ES)** en todos los textos, entradas y salidas de voz.

El valor de HU-3 es que estas propiedades no dependen de la disciplina del desarrollador pantalla a
pantalla: están **centralizadas en `core/theme` y `core/models`**, de modo que cualquier pantalla del
mayor las hereda por construcción.

---

## 2. Criterios de aceptación (RNF-1 a RNF-5 + RF-4)

| Req. | Criterio | Estado | Evidencia |
|---|---|---|---|
| RNF-1 | Cumplimiento WCAG 2.2 AA: perceptibilidad (contraste, tamaño) y operabilidad. | **Cumplido** (contraste verificado en la pantalla de emergencia; ver §6 para el resto). | `app_theme.dart:20-25` documenta contrastes AAA ≥ 7:1 (`emergency112` 7.6:1, `emergencyContactCall` 7.5:1) sobre `elderBackground`. |
| RNF-2 | Áreas táctiles ≥ 80×80 px lógicos. | **Cumplido** | `emergencyButtonMinHeight = 88.0` (`app_theme.dart:29`, comentado como "doble del mínimo WCAG"); botón de micrófono 200/260 px (`micButtonSize`); `_KeyboardButton` `minWidth/minHeight: 80` (`home_screen.dart:284-285`); filas de ajustes `minHeight: 88` (`settings_screen.dart:81-83`); botones elevados `minimumSize: Size(∞, 88)` (`app_theme.dart:94`). |
| RNF-3 | Cuerpo ≥ 20 sp, títulos ≥ 28 sp, escalados por multiplicador de usuario. | **Cumplido** | Pisos fijos `fontButton = 20`, `fontMedium = 24`, `fontLarge = 32`, `fontHuge = 40` (`app_theme.dart:40-43`, comentario "WCAG — do not go below these"); multiplicador aplicado como `AppTheme.font* * textScale` en `home_screen.dart:112,131,145` y `settings_screen.dart:27,100,111`. |
| RNF-4 | Solo pulsación simple: sin doble toque, pulsación prolongada ni deslizamiento. | **Cumplido** | Toda interacción del mayor es `onTap`: `GestureDetector.onTap` del micrófono (`home_screen.dart:155-168`), `InkWell.onTap` de filas de ajustes (`settings_screen.dart:77-79`), `IconButton` de acciones. No hay `onLongPress`, `onDoubleTap` ni gestos de *swipe* en las pantallas del mayor. |
| RNF-5 | Idioma es-ES en interfaz, entrada y salida de voz. | **Cumplido** | Todos los literales de UI del mayor están en español; STT/TTS operan en locale `es-ES` (ver CU-04, HU-2). |
| RF-4 | Indicación visual y textual del estado *Escuchando / Pensando / Hablando*. | **Cumplido** | `home_screen.dart:66-104` mapea `ChatStatus` a etiqueta (`'Te escucho...'`, `'Pensando...'`, `'Respondiendo...'`), color (rojo/naranja/verde) e icono (`mic`/`hourglass_empty`/`volume_up`) simultáneamente. |

---

## 3. Trazabilidad

HU-3 **no produce casos de uso propios** (tab:trazabilidad, TFG cap. 4). La memoria del proyecto lo
justifica: sus criterios son restricciones transversales de accesibilidad que se realizan como RNF y como
condiciones de diseño aplicables a *todos* los casos de uso, evitando la duplicación de casos de uso
ficticios. RF-4 es el único requisito funcional que la especificación atribuye (parcialmente) a HU-3, y se
comparte con HU-2 (ver §5.1).

---

## 4. Implementación real

### 4.1 Tema del mayor: pisos tipográficos y superficies grandes
`AppTheme.elderTheme` (`app_theme.dart:68-111`) fija botones elevados de 88 px de alto mínimo, radio 16,
tipografía de botón de 20 sp en negrita, e iconos de 40–48 px. Las cuatro constantes de tamaño
(`fontHuge/Large/Medium/Button`) llevan el comentario normativo *"WCAG — do not go below these"*: son
**pisos**, no valores por defecto ajustables a la baja.

### 4.2 Preferencias de accesibilidad (`UserPreferences`)
`user_preferences.dart` define tres `double`: `volume` (por defecto 1.0), `speechRate` (0.4 — voz más lenta
para mayor claridad) y `textSizeMultiplier` (1.2 — texto ligeramente ampliado de base). Los valores por
defecto ya están sesgados hacia la accesibilidad. `HomeScreen` y `SettingsScreen` leen
`textSizeMultiplier` desde `currentUserProvider` y multiplican cada tamaño de fuente por él; el resultado
es que **la letra del mayor cambia en tiempo real** cuando el parámetro cambia (propagación descrita en
HU-4, `INFO.md §2`).

### 4.3 Indicación multicanal de estado (RF-4)
El acierto de accesibilidad de RF-4 es que el estado nunca depende de un solo canal sensorial: hay texto
grande (*"Te escucho…"*), color del anillo del micrófono (rojo al escuchar, naranja al pensar, verde al
hablar) y forma del icono. Un usuario con daltonismo lee el texto; uno con baja agudeza percibe el cambio
de icono y de grosor del borde (`width: 6` al escuchar vs. `3` en reposo, `home_screen.dart:186-189`).

### 4.4 Filas de ajustes accesibles y "vacío accionable"
`SettingsScreen` (`a5756de`) renderiza filas grandes (`minHeight: 88`) con `Semantics(button: true, label:
'<título>: <valor>')` para lectores de pantalla (`settings_screen.dart:71-73`), chevron de 48 px y, cuando
un ajuste no está configurado, el texto **"Sin configurar"** en lugar de una fila en blanco o deshabilitada
(`settings_screen.dart:106-114`): el vacío es explícito y accionable, no ambiguo.

### 4.5 Contraste verificado en el camino crítico
La pantalla de emergencia (`53e6dbd`) introdujo tokens de color con **contraste calculado y anotado**
(`app_theme.dart:20-25`): `emergency112` (rojo profundo) y `emergencyContactCall` (verde, convención
universal de "llamar"), ambos con ratio AAA ≥ 7:1 sobre el fondo y visualmente distinguibles entre sí. Es
el único punto del código donde el contraste está numéricamente documentado.

### 4.6 Elección de paleta cálida (decisión de diseño)
`INFO.md §9.1` registra la evaluación de cuatro tonos cálidos alternativos al teal original, motivada por
la psicología del color en mayores (el amarilleamiento del cristalino con la edad hace percibir mejor los
tonos cálidos). El valor finalmente adoptado es Canela `Color(0xFFA0522D)` (`app_theme.dart:5`,
`elderPrimary`), la opción 2 de esa tabla. La sombra se deriva sustituyendo `FF` por `4D` sobre los mismos
dígitos RGB (`app_theme.dart:90`).

---

## 5. Desviaciones y retrabajo

### 5.1 Inconsistencia de trazabilidad de RF-4 en el propio documento fuente
La tabla de trazabilidad (TFG cap. 4) asigna a HU-3 la fila `RF: ---` (sin requisitos funcionales), pero la
ficha de RF-4 declara `Origen: HU-2, HU-3`. Es una inconsistencia **interna del documento de
especificación**, no del código. Esta memoria adopta el criterio de que RF-4 pertenece a ambas HU y lo
documenta bajo HU-3 por su naturaleza de accesibilidad.
> **UNRESOLVED — requiere decisión del autor:** unificar el documento de especificación (o RF-4 aparece en
> la fila de HU-3, o se retira su origen HU-3), para que memoria y TFG no se contradigan ante el tribunal.

### 5.2 El mayor no podía ajustar tamaño/voz desde su dispositivo — **resuelta el 2026-09-06**
CU-05 (HU-4) y RF-5 describen que el mayor **independiente** ajusta volumen, velocidad de voz y tamaño de
texto desde su propio dispositivo mediante controles grandes de incremento/decremento. Durante casi todo el
proyecto, `settings_rows.dart` contuvo **una sola fila** ("Contacto de emergencia"): no existía UI en el
dispositivo del mayor para modificar `volume`, `speechRate` ni `textSizeMultiplier`, que solo se editaban
desde el panel del familiar (dashboard, HU-4). La interfaz del mayor **honraba** los tres parámetros sin
ofrecer cómo cambiarlos localmente.

Esta desviación pertenecía formalmente a HU-4/RF-5, pero se registró aquí porque afectaba directamente a la
autonomía accesible del mayor y un lector de HU-3 esperará encontrar esos controles.

**Resolución (ADR-0021).** Se implementan las tres escalas locales. El obstáculo real no era el modelo de
datos —`UserPreferences` ya guardaba los tres `double`— sino la interacción: el `Slider` del panel del
familiar exige arrastre, prohibido por `CLAUDE.md` §Accessibility, así que no era reutilizable. La solución
es `PreferenceScale`: peldaños discretos con **nombre en castellano** ("Grande", "Muy despacio") sobre el
mismo `double`, con dos botones grandes y una subpantalla única parametrizada por ruta.

Al hacerlo se descubrió y cerró un **agujero derivado no documentado hasta ahora**: como la fila del contacto
de emergencia se oculta cuando el contacto lo impone la vinculación (`source == companion`), un catálogo de
una sola fila dejaba la lista vacía y `home_screen.dart:57` escondía el botón de ajustes **entero**. El mayor
vinculado no tenía pantalla de ajustes en absoluto. Por eso las tres escalas son visibles para **todo mayor**
y no solo para el independiente, apartándose deliberadamente de la letra de CU-05 (ADR-0021, tabla de
alternativas).

### 5.3 Rediseño accesible de `HomeScreen`
`INFO.md §9.3` (`708d71a`) documenta el rediseño que reforzó la accesibilidad de la pantalla principal: el
saludo pasó al `AppBar` liberando el cuerpo para el texto de respuesta; la etiqueta de estado solo aparece
en estados activos; se añadió auto-scroll del texto durante la locución; y el botón de teclado pasó a un
`_KeyboardButton` compacto con `minWidth/minHeight: 80`. El botón de ajustes se envolvió en
`Visibility(maintainSize: true)` para que su ocultación (mayor vinculado) no descoloque el resto de la fila.

### 5.4 Corrección de color inválido
`INFO.md §9.1` detectó `Color(0xD90429)` (7 dígitos hex, sin canal alfa) como valor a compilar. El código
vigente ya usa el valor válido `Color(0xFFD90429)` para `elderEmergency` (`app_theme.dart:8`). Corregido.

---

## 6. Deuda técnica y cuestiones abiertas

- **Verificación WCAG incompleta:** solo el contraste de la pantalla de emergencia está numéricamente
  verificado (§4.5). El resto de combinaciones texto/fondo del `elderTheme` (`elderTextPrimary` y
  `elderTextSecondary` sobre `elderBackground`) no tienen ratio documentado.
  > **UNRESOLVED — requiere acción del autor:** calcular y anotar los ratios de contraste del resto de la
  > paleta del mayor para poder afirmar cumplimiento AA/AAA de forma defendible.
- **`_KeyboardButton` sin acción:** el botón "¿Teclado?" tiene `onPressed: () {}` (`home_screen.dart:210-211`):
  la entrada por teclado como alternativa a la voz aún no está implementada. Es un afordance accesible
  anunciado pero inerte.
- **Semántica de lector de pantalla parcial:** solo las filas de ajustes declaran `Semantics` explícito
  (`settings_screen.dart:71`). El resto de pantallas dependen de la semántica por defecto de los widgets;
  conviene auditar `HomeScreen` y el onboarding con TalkBack antes de las pruebas de usuario.
- ~~Controles de accesibilidad locales del mayor~~ — implementados (ADR-0021); pendiente el recorrido manual en dispositivo. Ver §5.2.

---

## 7. Verificación

- `test/features/settings/settings_screen_test.dart` — `visibleSettingsRows` como función pura, render por
  `source` del contacto, navegación a subpantalla, conteo de filas.
- `test/features/emergency/emergency_screen_test.dart` — render por estado del contacto; los servicios
  (`TtsService`, `SpeechService`, `EmergencyCallService`) son inyectables por provider y falseables; se
  verifica que la pantalla no usa `SnackBar` para errores (patrón de UX accesible).
- `test/core/models/user_model_test.dart` — round-trip de `UserPreferences` (los tres parámetros de
  accesibilidad) y del patrón `copyWith`.
- **Verificación manual pendiente:** contraste del resto de la paleta (§6), y recorrido con lector de
  pantalla (TalkBack) de `HomeScreen` y onboarding en dispositivo real.
