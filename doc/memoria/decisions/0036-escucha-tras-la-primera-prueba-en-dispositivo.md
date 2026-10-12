# ADR-0036 — Escucha tras la primera prueba en dispositivo: la última palabra, la pausa del mayor y el nombre

- **Estado:** Aceptada. Implementada el 2026-10-12 en la rama `feat/modo-teclado`. `flutter analyze` y
  `flutter test` en verde; pendiente de verificar en dispositivo.
- **Fecha:** 2026-10-12
- **Ámbito:** HU-2 (conversación por voz), HU-3 (accesibilidad configurada por el mayor), RF-3.
- **Decisores:** Autor del TFG.
- **Evidencia:** primera prueba completa en el móvil del autor (más de tres turnos, 2026-10-12): *"a veces se
  corta demasiado rápido"*, *"la última palabra que dice el usuario nunca se redacta"* y *"la función de coger
  mi nombre no ha funcionado en varias ocasiones, hasta que [...] le he dado un nombre completo"*. Código de
  `speech_to_text` 7.3.0 (`SpeechToTextPlugin.kt`: `onEndOfSpeech`, `notifyListening`, `updateResults`;
  `speech_to_text.dart`: `_onNotifyStatus`, `_stop`, `listen`). Implementación:
  `core/services/speech_service.dart`, `core/config/speech_config.dart`, `core/models/user_preferences.dart`,
  `core/config/preference_scales.dart`, `core/services/gemini_service.dart`, `chat_controller.dart`,
  `emergency_screen.dart`. Commits: SHA pendiente.
- **Relacionada con:** ADR-0022 (escucha por turno; este ADR corrige su implementación y su plazo de 2 s),
  ADR-0021 (escalas discretas), ADR-0034 (plazos con número), ADR-0013 (accesibilidad configurada).

---

## Contexto

La prueba en dispositivo sacó tres fallos. Dos tienen la misma causa.

**1. La última palabra se perdía siempre.** El plugin de Android avisa de que ha dejado de grabar
(`onEndOfSpeech` → estado `notListening`) **antes** de entregar el resultado final (`onResults`). Los
resultados parciales van por detrás de la voz, así que la última palabra solo llega en ese final.
`SpeechService` trataba `notListening` como el fin de la sesión nativa: consolidaba el último parcial y cerraba
`_sessionOpen`. El final, que llegaba justo después con la frase completa, se descartaba por tardío. El
`_sessionOpen` se había puesto para evitar texto duplicado (ADR-0022, corrección del 2026-09-07), y era él el
que tiraba la palabra.

El botón del micrófono también perdía la última palabra: `stopListening()` devolvía el texto en el acto, sin
esperar al final que el propio `stop()` pide al reconocedor.

**2. El nombre no se guardaba.** El mayor suele decir el nombre al final de la frase (*"me llamo Mario"*). Con
el fallo 1, al modelo le llegaba *"me llamo"*. Además, la herramienta `guardarNombre` pedía llamarla *"en
cuanto el mayor confirme su nombre"*, y la instrucción de sistema decía *"confirma el nombre y llama a la
función"*. Con eso el modelo podía dar el nombre por bueno en la conversación sin guardarlo. Al decir el
nombre completo, la última palabra perdida era el segundo apellido, y lo demás llegaba.

**3. Dos segundos de pausa se quedan cortos.** ADR-0022 ya lo daba como el primer riesgo: *"quien piensa a
media frase más de dos segundos verá su turno enviado a medias"*. La prueba lo confirma.

## Decisión

1. **Una sesión nativa termina con su resultado final, no al apagarse el micrófono.** `notListening` solo
   arma un tope (`kSpeechFinalResultWait`, 1 s) por si el final no llega. Lo que cierra la sesión es el final,
   el `done` que el paquete deja pasar después del final, un error sin palabras pendientes o ese tope. Los
   resultados de una sesión sobrescriben su propio texto y solo se consolidan una vez. Así un final que llega
   tarde completa la frase y no la duplica.
2. **Cerrar el turno también espera al final.** Por silencio o con el botón, el servicio llama a `stop()` y
   espera al final, con el mismo tope de 1 s. El envío sale siempre por `onFinal`. `stopListening()` se cambia
   por `finishListening()`, que no devuelve texto. La pantalla de emergencia pasa a `cancelListening()`:
   cerrar el turno ahí enviaría lo dicho al asistente, y la respuesta sonaría encima de esa pantalla.
3. **La pausa la elige el mayor.** Hay una cuarta escala en Ajustes, *"Tiempo que te espero"*, con 2, 3, 4, 6
   y 10 segundos. El valor por defecto pasa de 2 a 3 s. Se guarda en `preferences.listenPauseSeconds`. El
   controlador la recibe en vivo y la aplica en el turno siguiente. La espera antes de la primera palabra
   (8 s) nunca es menor que la pausa elegida. Los peldaños llevan el número, como los plazos de ADR-0034:
   aquí el número sí significa algo para quien lo lee.
4. **Vale cualquier nombre, en cuanto se dice.** La herramienta y la instrucción de sistema piden llamar a
   `guardarNombre` en el mismo turno con cualquier nombre (de pila, completo o apodo), sin pedir que se
   confirme ni pedir apellidos. También piden volver a llamarla si el mayor pide que le llamen de otra forma, y
   pedir que lo repita si la transcripción llega sin nombre. La llamada se contesta siempre, también si no
   trae un nombre utilizable, para no dejar el historial de la sesión a medias.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Opción para quitar el cierre automático** (solo el botón envía) | Vuelve al walkie-talkie que ADR-0022 retiró, y obliga al mayor a acordarse de pulsar. Para quien necesita más tiempo están los 10 s, y el botón sigue enviando en el acto. |
| **Solo subir la constante a 3–4 s** | Arregla la media y no la persona: el plazo es exactamente lo que ADR-0022 dejó pendiente de ajustar con usuarios. |
| **Reanudar el reconocedor en cuanto llega `notListening`** | Acorta el hueco sin micrófono, pero `listen()` reinicia el estado del paquete y el final pendiente se pierde: es el mismo fallo por otro camino. |
| **Pedir resultados finales por frase y no usar parciales** | La pantalla dejaría de enseñar lo que se va oyendo, que es como el mayor sabe que le escuchan. |
| **Extraer el nombre por expresión regular ("me llamo X")** | Frágil en español hablado (*"soy de Jaén"*, *"me llamo como mi padre"*). Con la última palabra recuperada, el modelo tiene la frase entera. |

## Consecuencias

- **Positiva:** la frase llega entera al modelo, también la que se cierra con el botón.
- **Positiva:** cada mayor ajusta cuánto se le espera, sin tocar código.
- **Coste:** el hueco sin micrófono entre dos sesiones crece lo que tarde el final, normalmente unos cientos
  de milisegundos y como mucho 1 s. Mientras tanto Android ya no está grabando, así que no se pierde más audio
  que antes.
- **Coste:** desde que vence la pausa o se pulsa el botón hasta el envío pasa lo que tarde el final, como
  mucho 1 s.
- **Neutra:** el panel del familiar no tiene este ajuste. Lo mueve el mayor. Si en las pruebas resulta que lo
  necesita quien le acompaña, se añade al panel como los otros deslizadores.

## Verificación

- `test/core/services/speech_service_test.dart` (nuevo): un reconocedor falso emite los avisos en el orden del
  plugin. Cubre la palabra que llega en el final después de `notListening`, el botón que espera al final, el
  tope cuando el final no llega, el error que se adelanta al final sin duplicar, la pausa a media frase que
  acumula, el micrófono que no se queda sordo sin final, la pausa elegida que manda, la espera inicial y la
  cancelación.
- `chat_controller_test.dart`, grupo *escucha (ADR-0036)*: el turno se abre con la pausa elegida, el botón
  espera a `onFinal` y, si otra pantalla canceló la escucha, el botón devuelve a reposo.
- `settings_screen_test.dart` y `user_model_test.dart` actualizados para la cuarta escala y el campo nuevo.
- Manual en el móvil:
  1. Decir *"me llamo Mario"* y callar. Debe aparecer *"Mario"* en pantalla y guardarse el nombre (cabecera
     *"Hola, Mario"*).
  2. Decir una frase y pulsar el micrófono justo después de la última palabra. Debe enviarse entera.
  3. Ajustes → *"Tiempo que te espero"* → 6 segundos. Hacer una pausa de 4 s a media frase. El turno debe
     seguir.
  4. Con un nombre guardado, decir *"prefiero que me llames Mari"*. La cabecera debe cambiar.
  5. Abrir Emergencia con el micrófono escuchando y volver. No debe enviarse nada ni sonar ninguna respuesta.
