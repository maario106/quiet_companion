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
| vinculación por código | Solo se reclama a un mayor **con código libre**, solo para uno mismo, sin colar campos extra |
| un autenticado cualquiera | No lee ni escribe datos ajenos, no vuelca la colección |
| sin autenticar | No toca nada |
| colecciones que no existen | El deny por defecto cubre `/pairings` y `/alerts` |
| **HUECO TEMPORAL** | Comprueba que los permisos abiertos a propósito **siguen abiertos** |

El último grupo es deliberado. La búsqueda por `linkCode` obliga a permitir
consultas sobre `/users`, y las reglas no pueden inspeccionar cláusulas `where`
(solo `request.query.limit`). Esos tres casos son el recordatorio ejecutable de
lo que la callable `validateAndLink` tiene que cerrar (RNF-9, ADR-0008): cuando
exista, se invierten a `assertFails` y las dos líneas marcadas en
`firestore.rules` desaparecen.
