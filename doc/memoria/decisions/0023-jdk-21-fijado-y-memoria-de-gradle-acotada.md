# ADR-0023 — JDK de compilación fijado en 21 y memoria de los daemons de Gradle acotada

- **Estado:** Aceptada
- **Fecha:** 2026-09-07
- **Ámbito:** Entorno de compilación Android. No altera el código de la app ni el nivel de bytecode.
- **Decisores:** Autor del TFG.
- **Evidencia:** Actualización de Android Studio 2025.2.1 → 2026.1.3 el 2026-09-07.
  Fallo 1: `java.io.IOException: error=0, Failed to exec spawn helper: pid: 56391, exit value: 1`,
  envuelto por Gradle como `A problem occurred starting process 'command '.../flutter''`.
  Fallo 2: `FAILURE: Build failed with an exception. * What went wrong: 25.0.2`.
  `android/app/build.gradle.kts:14-21`; `android/gradle/wrapper/gradle-wrapper.properties`;
  commit `78ed34f` (2026-09-07), que fija los `jvmargs` de Gradle y del daemon de Kotlin.
- **Relacionada con:** ADR-0026 (el emulador de Firestore exige JDK 21, misma tensión de versiones).

---

## Contexto

La actualización de Android Studio se instala extrayendo el tarball sobre `~/programas/android-studio`,
que contiene el JDK empaquetado (`jbr/`). La versión 2026.1.3 subió ese JDK de **JBR 21 a JBR 25**. La
compilación, que funcionaba, dejó de funcionar por dos causas encadenadas que se presentaban como una sola.

**Primera:** dos daemons —Gradle arrancado a las 19:30 del día anterior y el de Kotlin a las 00:36—
seguían vivos ejecutando el JVM antiguo desde una ruta cuyos ficheros ya habían sido reemplazados. Al
lanzar un proceso hijo, el JVM ejecuta `$JAVA_HOME/lib/jspawnhelper` y negocia versión con él; padre
viejo contra ayudante nuevo hace fallar el saludo. Gradle lo reporta como un genérico "problema al
arrancar el proceso", que apunta al binario equivocado —`flutter`— y esconde la causa.

**Segunda,** una vez reiniciados los daemons: Gradle 8.10.2 es anterior a Java 25 y no sabe interpretar
esa versión. El mensaje de error es literalmente la cadena `25.0.2`, sin más texto.

Conviene separar dos cosas que se confunden: el **JDK que ejecuta Gradle** y el **nivel de bytecode al que
compila la app**. Son independientes. `app/build.gradle.kts` fija `sourceCompatibility`,
`targetCompatibility` y `jvmTarget` en `VERSION_11`, y eso no cambia por ejecutar Gradle sobre otro JDK.
El stack bloqueado del proyecto sigue intacto.

## Decisión

Se fija el JDK de compilación en **21** mediante `flutter config --jdk-dir=/usr/lib/jvm/java-21-openjdk-amd64`,
ajuste de usuario que no toca el repositorio, y se alinea `JAVA_HOME` en `~/.bashrc` con ese mismo 21 para
que la línea de órdenes y `flutter run` coincidan.

Se reduce además la memoria de los daemons en `android/gradle.properties`:

    org.gradle.jvmargs=-Xmx3G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError
    kotlin.daemon.jvmargs=-Xmx1536m

El techo anterior era `-Xmx8G` con `MaxMetaspaceSize=4G`, y el daemon de Kotlin heredaba esos mismos
argumentos: 16 GB de techo de heap declarados en una máquina de 7,6 GB. La consecuencia observada no era
un fallo de compilación sino el equipo bloqueándose al intentar tener emulador, Chrome y dispositivo
físico a la vez.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Subir el wrapper a Gradle 9.x**, que sí admite Java 25 | Resuelve la causa de raíz, pero cambia una pieza mayor del build en plena estabilización de HU-1→HU-4, con AGP 8.7.0 y Kotlin 2.1.0 detrás. El build ya avisa de `Deprecated Gradle features ... incompatible with Gradle 9.0`: la migración no es gratuita y merece su propio ciclo. |
| **Apuntar a JBR 25 y aguantar** | No es una opción: Gradle 8.10.2 no arranca sobre Java 25. |
| **Dejar `JAVA_HOME` en 11** | AGP 8.7.0 exige JDK 17 o superior *para ejecutarse*; `./gradlew` directo desde el terminal fallaba con `Android Gradle plugin requires Java 17 to run`. Mantener 11 obligaba a recordar exportar otro JDK en cada sesión. |
| **Usar el JBR de Android Studio, sea cual sea** | Es lo que había, y es precisamente lo que rompió el build sin que nadie tocara el proyecto. Un JDK que cambia de versión mayor cuando se actualiza el IDE no es una base estable para un TFG que debe compilar durante la defensa. |
| **Dejar `-Xmx8G`** | Compilar más rápido no sirve si el equipo no puede sostener a la vez el emulador y la sesión de pruebas. Medido tras el cambio: APK de depuración completa en 89 s con pico de 6,1 GB de RAM del sistema. |

## Consecuencias

- **Positiva:** el build deja de depender de qué JDK empaquete la versión de Android Studio instalada.
  La próxima actualización del IDE ya no puede romper la compilación por esta vía.
- **Positiva:** margen de memoria suficiente para emulador y navegador durante las pruebas de HU-1→HU-4.
- **Neutra:** el bytecode sigue siendo Java 11. Nada del stack bloqueado cambia.
- **Negativa:** el proyecto arrastra una deuda explícita —Gradle 8.10.2 con avisos de incompatibilidad
  con 9.0— que habrá que pagar cuando se suba AGP.
- **Riesgo residual:** `flutter config` es ajuste de máquina, no del repositorio. Quien clone el proyecto
  en otro equipo no lo hereda. Queda anotado en `INFO.md` como requisito de entorno.

## Verificación

`flutter doctor -v` debe mostrar `Java binary at: /usr/lib/jvm/java-21-openjdk-amd64/bin/java` con la nota
`This JDK is specified in your Flutter configuration`. `flutter build apk --debug` debe terminar en
`✓ Built build/app/outputs/flutter-apk/app-debug.apk`. Comprobado el 2026-09-07: 89 s, pico de 6,1 GB.
