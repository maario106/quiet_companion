# ADR-0022 — La escucha es un turno, no una sesión del reconocedor; y el turno lo cierra el silencio

- **Estado:** Aceptada
- **Fecha:** 2026-09-06
- **Ámbito:** Entrada de voz del mayor (HU-2/HU-3, RF-3).
- **Decisores:** Autor del TFG.
- **Evidencia:** Documentación de `speech_to_text` 7.3.0 (`listen`, `SpeechListenOptions`),
  `lib/core/services/speech_service.dart`, `lib/core/config/speech_config.dart`, observación en
  dispositivo (Xiaomi Mi Note 10 Lite, Android 10).
- **Relacionada con:** ADR-0002 (LLM en la nube), ADR-0017 (TTS en nube), ADR-0013 (interacción sin gestos).

---

## Contexto

Dos fallos observados hablando con la app, ambos de la misma raíz:

1. **Una pausa a media frase mataba la escucha.** El mayor se paraba a pensar, el micrófono dejaba de grabar
   sin avisar y lo que dijera a continuación se perdía. La interfaz seguía diciendo "Te escucho...".
2. **No había respuesta hasta pulsar el botón.** Aunque el mayor hubiera terminado de hablar hacía rato, el
   turno no se cerraba solo. Eso no se parece a una conversación: se parece a una radio.

La causa del primero está documentada en el propio paquete: *"On some systems, notably Android, there is a
system imposed pause of from one to three seconds that cannot be overridden"*. El reconocedor de Android
**termina su sesión** en cuanto detecta ese silencio, y lo anuncia de tres formas distintas (un resultado
`finalResult`, un cambio de estado a `done`/`notListening`, o un `error_no_match` / `error_speech_timeout`).
La configuración anterior trataba cualquiera de las tres como el final de la escucha.

Tres agravantes concretos de esa configuración:

- **`cancelOnError: true`.** `cancel()` **descarta** lo reconocido; `stop()` lo conserva. Como Android
  dispara `error_no_match` en cada pausa y lo marca como permanente, se tiraba a la basura lo que el mayor
  llevaba dicho.
- **`listenMode: ListenMode.dictation`** era la única defensa contra sesiones cortas, y el paquete la
  documenta como *"currently only supported on iOS"*: en Android, la plataforma primaria del proyecto, era
  inerte.
- **Ni `listenFor` ni `pauseFor`**, de modo que todo el criterio temporal quedaba en manos del sistema.

## Decisión

**La sesión del reconocedor deja de ser la unidad de escucha.** La unidad es el *turno* del mayor:

1. Cuando el reconocedor nativo termina —por resultado final, por cambio de estado o por error—, se
   **consolida** lo reconocido y se **abre otra sesión**. El texto se acumula entre sesiones, porque cada
   `listen()` reinicia `recognizedWords` desde cero.
2. Lo que cierra el turno es **un temporizador de silencio propio**, no el criterio del sistema:
   [`kSpeechSilenceTimeout`] = **2 s** sin palabras nuevas.
3. Al cerrarse, el turno **se envía solo** (`onFinal`). El botón deja de ser obligatorio y pasa a significar
   "no esperes, envía ya".
4. **Dos plazos, no uno:** antes de la primera palabra rige [`kSpeechLeadInTimeout`] = 8 s. Entre palabras,
   2 s. Un plazo único de 2 s cerraría el turno en vacío antes de que al mayor le diera tiempo a arrancar.
5. `cancelOnError: false`: un error de pausa ya no descarta nada, solo significa "esta sesión nativa terminó".

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Delegar en `pauseFor` del paquete** | Es la opción evidente y no basta: el paquete solo garantiza que la pausa *no sea más larga* que el valor dado ("it may be shorter"), y sigue **terminando** la escucha. Resuelve el punto 2 y no toca el punto 1, que es el que pierde palabras. |
| **Subir `listenFor` y confiar en la sesión larga** | El límite que corta no es el nuestro, es el de Android. `listenFor` solo puede acortar. |
| **Mantener `cancelOnError: true` y reintentar el turno entero** | Obligaría al mayor a repetir lo ya dicho. Para esta población, repetir por un fallo que no ha causado ni entiende es la peor respuesta posible. |
| **Un único plazo de silencio para todo el turno** | Con 2 s, el turno se cierra vacío antes de empezar a hablar; con 8 s, contestar cuesta ocho segundos siempre. Los dos plazos miden dos cosas distintas y no tienen por qué coincidir. |
| **Detección de fin de turno por energía de audio (VAD propio)** | Requiere capturar el audio en paralelo al reconocedor: otra dependencia, otro permiso de uso continuo del micrófono y una segunda fuente de verdad sobre "hay voz". Desproporcionado frente a un temporizador. |
| **Enviar en cada `finalResult` de Android** | Trocearía la intervención en frases sueltas: el LLM recibiría "he dormido mal" y "pero ya estoy mejor" como dos turnos, y contestaría dos veces. |
| **Quitar el botón, ya que el envío es automático** | Sigue haciendo falta para quien termina y no quiere esperar los 2 s, y como salida cuando el reconocedor no oye. Cambia de significado, no de existencia. |

## Justificación

El fallo era una discrepancia entre dos definiciones de "ha terminado de hablar": la de Android (un silencio
de uno a tres segundos, pensada para dictar comandos cortos) y la de una conversación con una persona mayor,
que hace pausas más largas y no está dictando. Al reconocedor no se le puede cambiar la suya, así que se le
deja de preguntar: se le usa como transcriptor desechable y la decisión se toma arriba.

Los dos plazos van en `speech_config.dart` y no en el servicio porque son exactamente la parte que habrá que
ajustar en las pruebas con personas; el valor de 2 s viene de la petición explícita del autor y es una
hipótesis a validar, no una constante derivada de evidencia.

## Consecuencias

- **Positiva:** una pausa a media frase ya no pierde nada; el turno continúa.
- **Positiva:** la respuesta llega sola. La interacción se parece a hablar con alguien y no a usar un walkie.
- **Positiva:** los plazos son un fichero de configuración, ajustables tras la primera prueba con usuarios.
- **Coste:** entre una sesión nativa y la siguiente hay un hueco de `kSpeechResumeDelay` (250 ms) sin grabar.
  Una palabra que arranque justo ahí puede perderse. Es inherente a reanudar el reconocedor; evitarlo exigiría
  capturar el audio por nuestra cuenta (alternativa rechazada arriba).
- **Coste:** reabrir la sesión repetidamente consume más batería que una sesión única, y en algunos motores
  produce un pitido audible al reiniciar. Pendiente de comprobar en dispositivo.
- **Riesgo:** 2 s puede resultar corto para esta población — quien piensa a media frase más de dos segundos
  verá su turno enviado a medias. Es el primer parámetro a revisar en la prueba.

## Corrección posterior (2026-09-07) — texto duplicado

La primera prueba en dispositivo devolvió cada frase **dos veces** ("hola qué tal hola qué tal"). No era un
fallo de la decisión sino de su implementación, y merece quedar escrito porque la causa no es evidente:

**el reconocedor no ordena sus avisos.** El `error_no_match` de la pausa puede llegar *antes* del resultado
final, y el paquete además arma un final sintético propio (`_notifyFinalTimer`, que instala `stop()`) por si
la plataforma no lo manda. Cada uno de esos avisos consolidaba el texto reconocido, y el siguiente volvía a
rellenar el buffer de la sesión con **las mismas palabras**, que se consolidaban otra vez.

Corregido con un `_sessionOpen`: consolidada una sesión nativa, sus resultados tardíos se ignoran hasta que
se abre la siguiente. Se añadió además el `stop()` previo a cada reanudación que el paquete exige ("When
listening is done always invoke either `cancel` or `stop` to end the session, even if it times out"); sin él,
`isListening` se quedaba en `true` y la reanudación no llegaba a ocurrir — el micrófono seguía encendido sin
transcribir.

Lección para el resto del proyecto: **acumular texto de voz exige una noción explícita de "qué sesión lo
produjo"**. Bastaba con contar palabras para que dos avisos del mismo tramo se contaran dos veces.

## Verificación

`flutter analyze` sin incidencias; la suite existente sigue verde (se actualizó `FakeSpeechService` en
`emergency_screen_test.dart` para la nueva interfaz). **Sin tests nuevos**, por la misma decisión del autor
registrada en ADR-0021: el volumen de pruebas se contiene a lo sostenible en solitario.

La verificación es **manual en dispositivo y está pendiente**. Guion mínimo:

1. Pulsar el micrófono y esperar sin hablar → el turno debe cerrarse solo a los 8 s, sin enviar nada.
2. Decir una frase, callar 1 s, seguir hablando → el texto debe **continuar**, no reiniciarse ni perderse.
3. Decir una frase y callar → a los 2 s debe enviarse solo, sin tocar el botón.
4. Decir una frase y pulsar el botón antes de los 2 s → debe enviarse en el acto.

Diagnóstico en dispositivo: los mensajes `[STT]` en `logcat` registran cada reanudación, cada error del
reconocedor y el cierre del turno (`adb logcat -d | grep "\[STT\]"`).

## Corrección posterior (2026-10-12) — la última palabra y el plazo de 2 s

La primera prueba completa en el móvil sacó dos problemas. Están en ADR-0036:

- **La última palabra de cada frase se perdía.** El `_sessionOpen` de la corrección anterior cerraba la sesión
  con el estado `notListening`, pero Android lo envía *antes* del resultado final, y solo el final trae la
  última palabra. Ahora la sesión termina con su final (o con un tope de 1 s), y cerrar el turno también espera
  a ese final. La lección de arriba se queda corta: además de saber qué sesión produjo cada texto, hay que
  saber cuándo ha dicho ya todo lo que iba a decir.
- **El plazo de 2 s era corto**, como se temía en el riesgo de este ADR. Ahora lo elige el mayor en Ajustes y
  por defecto es de 3 s.
