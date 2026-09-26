# Tests de las reglas de Firestore

Verifican `../firestore.rules` contra el emulador. Sin nube, sin coste, sin
tocar los datos reales.

```bash
cd firestore-tests
npm install     # solo la primera vez
npm test
```

## Por qué esto vive fuera de `functions/`

`functions/` es el código que se despliega. Meter aquí `firebase` y
`@firebase/rules-unit-testing` engordaría cada despliegue con dependencias que
el servidor no ejecuta nunca.

## El detalle del JDK

El emulador de Firestore exige **Java 21 o superior**, pero el build de Android
de este proyecto está fijado a **Java 11** (`CLAUDE.md` §Stack). Cambiar el JDK
por defecto del sistema arreglaría una cosa y rompería la otra, así que el
script `test` antepone el 21 solo para el emulador:

    JAVA_HOME=${JDK21:-/usr/lib/jvm/java-21-openjdk-amd64} PATH="…/bin:$PATH"

Si tu JDK 21 está en otra ruta, exporta `JDK21` y no toques nada más. Ojo:
`firebase-tools` mira el `java` del **PATH**, no `JAVA_HOME` — poner solo
`JAVA_HOME` no basta.

## Qué se está comprobando

| Grupo | Qué demuestra |
|---|---|
| el dueño gobierna su documento | Mayor y familiar pueden con lo suyo, y solo con lo suyo |
| el familiar vinculado y su mayor | El panel escribe `preferences` y `name`; no toca rol, autonomía ni contacto de emergencia |
| la vinculación ya no se hace desde el cliente | Nadie puede reclamar a un mayor desde la app, ni con código libre |
| un autenticado cualquiera | No lee ni escribe datos ajenos, no vuelca la colección |
| sin autenticar | No toca nada |
| colecciones que no existen | El deny por defecto cubre `/pairings` y `/alerts` |
| `/users` no es enumerable | La búsqueda por `linkCode` está denegada desde cualquier cliente |

## La vinculación

`allow list: if false`. La búsqueda por código era lo único que obligaba a
dejar `/users` consultable, y desde la fase 2 la hace `validateAndLink` con el
Admin SDK, que se salta estas reglas. Las reglas puras de esa función (qué
contacto de emergencia gana, cómo se normaliza el código) se testean aparte,
sin emulador:

```bash
cd functions && npm test
```

---

## Recorrido de extremo a extremo contra el emulador

Los tests de aquí verifican las reglas, y los de `functions/` la lógica de
vinculación. Ninguno ve a la app hablar con las reglas de verdad. Eso se hace
arrancando la suite y apuntando la app a ella.

**1. Levantar los emuladores** (desde la raíz del repo):

```bash
firebase emulators:start --only auth,firestore,functions
```

Si sale `no longer supports Java version before 21`, es el JDK del PATH — mira
la sección del JDK más arriba.

**2. Redirigir los puertos al móvil** (solo con dispositivo por USB; el
`127.0.0.1` del teléfono no es el del portátil):

```bash
adb reverse tcp:9099 tcp:9099   # auth
adb reverse tcp:8080 tcp:8080   # firestore
adb reverse tcp:5001 tcp:5001   # functions
```

**3. Arrancar la app apuntando ahí:**

```bash
flutter run --dart-define=USE_EMULATOR=true
```

En un emulador de Android (AVD) no hace falta `adb reverse`; se añade
`--dart-define=EMULATOR_HOST=10.0.2.2`.

### Qué recorrer, y qué se está probando en cada paso

| Paso | Verifica |
|---|---|
| Alta del mayor (onboarding → independiente) | `allow create` sobre el propio documento |
| Ajustes del mayor: subir letra, volumen, velocidad | `allow update` del dueño (`updatePreferences`) |
| Contacto de emergencia desde ajustes | `allow update` del dueño (`updateEmergencyContact`) |
| Alta del mayor dependiente → sale el código | Escritura del `linkCode` por su dueño |
| Registro del familiar (nombre + teléfono) | `ensureCompanionUserDoc` |
| Meter el código en el panel del familiar | **`validateAndLink`**: la callable, no el cliente |
| El panel enseña al mayor | `allow get` del familiar vinculado |
| Mover los deslizadores del panel | `allow update` acotado a `preferences` |
| Cambiar el nombre del mayor desde el panel | `allow update` acotado a `name` |

La UI en `localhost:4000` enseña cada denegación con la regla que la produjo:
es el sitio donde mirar si algo sale como "Error al guardar".

Los datos del emulador son efímeros: al pararlo desaparecen. Para reiniciar el
recorrido desde cero, basta con reiniciar la suite.
