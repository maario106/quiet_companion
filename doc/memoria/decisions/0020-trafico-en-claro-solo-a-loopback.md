# ADR-0020 — Tráfico en claro permitido solo hacia loopback, para reproducir el audio sintetizado

- **Estado:** Aceptada
- **Fecha:** 2026-07-27
- **Ámbito:** Configuración de red de la app Android. Consecuencia directa de ADR-0017.
- **Decisores:** Autor del TFG.
- **Evidencia:** `logcat` del Mi Note 10 Lite (Android 10) el 2026-07-27:
  `java.io.IOException: Cleartext HTTP traffic to 127.0.0.1 not permitted` →
  `[TTS] Reproducción fallida: (0) Source error` → `[TTS] Respaldo al dispositivo en el fragmento 0`;
  `android/app/src/main/res/xml/network_security_config.xml`.
- **Relacionada con:** ADR-0017 (TTS en la nube), ADR-0018 (callable desplegada).

---

## Contexto

`just_audio` no reproduce bytes directamente: levanta un **servidor HTTP local en `127.0.0.1`** y le pasa a
ExoPlayer una URL de ese servidor. Desde Android 9 el tráfico en claro está prohibido por defecto, y la
prohibición no distingue entre un servidor remoto y el del propio proceso.

Resultado en el primer despliegue real: la síntesis en la nube funcionaba —los registros de la Function
muestran cuatro invocaciones con `auth: VALID` y ninguna con error—, el MP3 de Chirp 3: HD llegaba al
dispositivo, y ExoPlayer se negaba a leerlo de la memoria del propio proceso. El respaldo hacía su trabajo y
la voz sonaba igual que antes, sin ningún error visible: exactamente el modo de fallo silencioso que ADR-0018
advertía.

La especificación del cambio afirmaba que no harían falta cambios en el manifest. Era falso.

## Decisión

Se declara un `network-security-config` que permite tráfico en claro **exclusivamente** hacia `127.0.0.1` y
`localhost`, y se referencia desde `<application android:networkSecurityConfig=...>`.

El resto de la app conserva el bloqueo por defecto: Firestore, Auth y la callable de síntesis siguen
exigiendo TLS. La excepción no habilita ni un solo byte en claro fuera del dispositivo.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **`android:usesCleartextTraffic="true"`** | Una línea en vez de un fichero, pero abre el tráfico en claro a **cualquier** destino. Degrada la postura de seguridad de toda la app —incluidos los datos conversacionales de una persona mayor— para resolver un problema de loopback. |
| **Escribir cada fragmento a un fichero temporal y reproducir por `file://`** | Evita el manifest, pero deja audio de la conversación en el almacenamiento del dispositivo. Contradice la política de minimización de datos del proyecto (ADR-0015): el audio no se persiste en ningún punto del camino. |
| **Cambiar `just_audio` por `audioplayers`** (`BytesSource` reproduce sin servidor local) | Evitaría el problema de raíz, pero cambia la dependencia de reproducción después de que el pipeline ya está implementado y testeado, por un fichero XML de doce líneas. Anotado como alternativa si `just_audio` diera más problemas. |
| **Renunciar al TTS en la nube** | Desproporcionado: el fallo era de configuración de plataforma, no de la decisión de ADR-0017. |

## Consecuencias

- **Positiva:** el audio de Chirp 3: HD se reproduce. El respaldo vuelve a ser lo que debía ser —una red de
  seguridad— en vez del camino permanente.
- **Positiva:** la excepción está acotada a loopback y documentada en el propio XML; una auditoría del
  manifest encuentra el porqué sin salir del fichero.
- **Negativa:** el `AndroidManifest.xml` gana una línea que hay que conservar en futuras migraciones de
  plantilla de Flutter. Si desaparece, el síntoma no es un error sino la voz robótica de siempre.
- **Riesgo residual:** cualquier otro componente de la app podría, en teoría, hablar en claro con
  `127.0.0.1`. En una app sin servidores locales propios más allá del de `just_audio`, es aceptable.

## Verificación

Reproducción real en el Mi Note 10 Lite: la voz debe ser la de nube y `logcat` no debe contener
`[TTS] Respaldo al dispositivo`. Ausencia de `CleartextNotPermittedException` en `E/ExoPlayerImplInternal`.
