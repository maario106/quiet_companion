# ADR-0019 — Volumen y velocidad del mayor se aplican en el reproductor del cliente, no en la síntesis

- **Estado:** Aceptada
- **Fecha:** 2026-07-25
- **Ámbito:** Preferencias de voz (HU-4) en el camino de síntesis en la nube.
- **Decisores:** Autor del TFG.
- **Evidencia:** `dashboard_screen.dart` (deslizadores de volumen y velocidad), `UserPreferences`,
  `doc/plan/ACTIVE.md` §4 ("las sobrescrituras opcionales NO se aceptan del cliente"),
  `cloud_tts_service.dart` (`playerSpeedFor`), `flutter_tts` 4.2.5 Android (`setSpeechRate(rate * 2.0f)`).
- **Relacionada con:** ADR-0017 (TTS en la nube), ADR-0010 (preferencias optimistas), ADR-0018 (codebase de
  Functions).

---

## Contexto

El familiar regula desde el dashboard el volumen y la velocidad de la voz del mayor, y el cambio se propaga
en caliente por Firestore (HU-4, ADR-0009/0010). Es una capacidad terminada y probada en dos dispositivos.

La especificación del TTS en la nube fija que el cliente envía **solo texto**: voz, idioma y ritmo son
constantes de servidor, para reducir la superficie de abuso de la callable. Aplicado literalmente, los dos
deslizadores dejarían de hacer nada en cuanto la síntesis pasara a la nube: seguirían moviéndose, seguirían
escribiéndose en Firestore, y la voz no cambiaría. Una regresión silenciosa en la única palanca que el
familiar tiene sobre la experiencia del mayor.

## Decisión

La síntesis se pide siempre a ritmo neutro (`SPEAKING_RATE = 1.0` en el servidor) y las preferencias se
aplican en la **reproducción**: `player.setSpeed(playerSpeedFor(prefs.speechRate))` y
`player.setVolume(prefs.volume)`.

La equivalencia de escalas vive en una única función pura, `playerSpeedFor`:

```
velocidad_reproductor = clamp(speechRate × 2.0, 0.25, 2.0)
```

El factor 2.0 no es arbitrario: es exactamente el que `flutter_tts` aplica en Android
(`setSpeechRate(rate * 2.0f)`). Con él, `speechRate = 0.5` significa "ritmo natural" en las dos voces y el
deslizador del familiar conserva su significado tras la migración. Los extremos se recortan al rango que
admiten tanto el reproductor como Chirp 3: HD.

El servicio de nube reenvía además las preferencias al respaldo de dispositivo, que las sigue interpretando
en su escala original.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Enviar `speakingRate` a la callable** | Es lo que la API espera y suena mejor que estirar el audio, pero abre la puerta a que el cliente dicte parámetros de síntesis: contradice la decisión de superficie mínima y obliga a validar rangos en el servidor. Además cada cambio de velocidad invalidaría cualquier reutilización futura del audio. |
| **Ignorar las preferencias en el camino de nube** | La opción barata: los deslizadores solo afectarían al respaldo. Regresa una capacidad ya entregada y deja al familiar moviendo controles que no hacen nada — el peor fallo posible en un panel de cuidados, porque es invisible. |
| **Fijar la velocidad en el servidor a un valor "bueno para mayores"** | Sustituye una preferencia individual por una media. La accesibilidad de este proyecto se sostiene en configuración explícita, no en suposiciones sobre el usuario (ADR-0013). |
| **Reproducir a velocidad nativa y re-sintetizar al cambiar la preferencia** | Coste y latencia por cada movimiento del deslizador, sin beneficio audible frente al cambio de velocidad del reproductor (que preserva el tono en Android). |

## Justificación

Es la única opción que satisface a la vez las dos restricciones que parecían incompatibles: el cliente no
envía parámetros de voz y el familiar conserva el control. El coste es una función pura de cinco líneas y
un factor de escala documentado, frente a una regresión funcional o una credencial de comportamiento en la
callable.

## Consecuencias

- **Positiva:** HU-4 no se toca. Los deslizadores hacen exactamente lo mismo que antes, con las dos voces.
- **Positiva:** la conversión vive en un solo sitio, es pura y está testeada (`playerSpeedFor`); si algún
  día cambia la escala de `flutter_tts`, se corrige una línea.
- **Negativa:** cambiar la velocidad estira el audio ya sintetizado en vez de sintetizarlo a ese ritmo. En
  los extremos del deslizador puede sonar menos natural que una síntesis nativa a esa velocidad. Aceptado:
  el rango habitual (0.3–0.7) es indistinguible en escucha.
- **Negativa:** el volumen del mayor pasa a depender del reproductor, no del motor del sistema. El volumen
  físico del dispositivo sigue mandando por encima.

## Verificación

`cloud_tts_service_test.dart` (grupo *preferencias*): la velocidad llega al reproductor y no a la síntesis,
la escala se traduce (0.5 → 1.0, 0.4 → 0.8) y los extremos se recortan. Verificación manual pendiente: mover
el deslizador desde el dashboard con el mayor hablando y comprobar que la locución siguiente cambia de
ritmo.
