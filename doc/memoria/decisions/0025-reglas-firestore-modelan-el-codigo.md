# ADR-0025 — Las reglas de Firestore modelan lo que el código hace hoy, y niegan todo lo demás

- **Estado:** Aceptada
- **Fecha:** 2026-09-06
- **Ámbito:** Política de acceso a Firestore (RNF-9, transversal a HU-1 y HU-4). Implementado.
- **Decisores:** Autor del TFG.
- **Evidencia:** `firestore.rules`, `firebase.json`, `firestore-tests/rules.test.js`;
  commits `c66d365`, `b5093f0`, `9e740aa`.
- **Relacionada con:** ADR-0024 (vinculación en el servidor), ADR-0026 (verificación contra el emulador),
  ADR-0009 (`currentUserProvider` como SSOT), ADR-0010 (escritura de preferencias).

---

## Contexto

`pending.md` §1 marcaba las reglas de Firestore como *«sin auditar — probablemente en modo dev»*: la
casilla más peligrosa de todo el documento, porque una base de datos en modo desarrollo deja leer y escribir
cualquier documento a cualquiera con la app instalada, y el proyecto guarda el nombre, el teléfono del
contacto de emergencia y las preferencias de una persona mayor.

Escribir reglas plantea una pregunta que no es obvia: **¿qué se modela, el sistema que se quiere o el que
existe?** La documentación de diseño describía una arquitectura con la vinculación en el servidor y una
colección `/pairings/`. El código no tenía ni lo uno ni lo otro.

## Decisión

Las reglas modelan **el código de hoy**, operación por operación, y todo lo que no corresponda a una
operación real está denegado.

1. **Lectura solo por identificador.** `allow get` para el dueño (`getUser`, `watchUser`) y para el familiar
   vinculado (panel). Nada más.
2. **`allow list: if false`.** Nadie consulta la colección. Buscar al mayor por su código era lo único que
   lo exigía, y eso se movió al servidor (ADR-0024). Esta línea es la que impide enumerar `/users`.
3. **Alta del propio documento** (`allow create: if isOwner`) para el mayor anónimo en el onboarding y el
   familiar en el registro.
4. **Borrado siempre denegado.** Borrar una cuenta es una acción explícita de datos, nunca un efecto
   colateral de la app; si algún día hace falta, irá por Cloud Function.
5. **Escritura acotada por campo para el familiar:** `changed().hasOnly(['preferences', 'name'])`. El panel
   edita exactamente esas dos cosas. No puede cambiar el rol del mayor, romperle el vínculo ni reescribirle
   el contacto de emergencia.
6. **La vinculación no aparece en las reglas a propósito**, porque la escribe el Admin SDK, que se las
   salta. Su ausencia es la afirmación de que ningún cliente puede vincular.
7. **Deny por defecto** en `match /{document=**}`, que cubre las colecciones que aún no existen.

Dos detalles de implementación que costaron depuración y quedan escritos porque no son evidentes:

- **`changed()` compara valores, no claves enviadas.** `request.resource.data.diff(resource.data).affectedKeys()`
  devuelve solo los campos que *cambian de valor*. Por eso el `saveUser` del panel, que reenvía el documento
  entero pero altera un campo, pasa el filtro sin necesidad de reescribir el cliente.
- **Leer un campo ausente con notación de punto deniega la operación entera.** `linkedCompanionId` no existe
  hasta que hay vínculo, así que se lee defensivamente con `resource.data.get('linkedCompanionId', null)`.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Dejarlas en modo desarrollo hasta después de las pruebas con usuarios** | Las pruebas con usuarios son exactamente el momento en que hay datos reales de personas mayores en la base. Es el peor momento posible para no tener reglas. |
| **Escribir las reglas de la arquitectura pretendida** (con `/pairings/`, escrituras cruzadas mediadas) | Es lo que había: reglas que describían un sistema que no existe. Una regla para algo que nadie escribe es una afirmación que nadie verifica, y su efecto real fue enmascarar durante meses que el código las contradecía (ADR-0008). |
| **Permitir `list` con condiciones sobre los campos consultados** | Técnicamente imposible: las reglas no ven las cláusulas `where` de una consulta, solo pueden permitir o denegar la operación entera. Esta imposibilidad es la que forzó ADR-0024. |
| **Validar además el *tipo* y el rango de cada campo escrito** (esquema completo en las reglas) | Descartado por proporción: multiplica la superficie de reglas y de tests para proteger de errores que hoy solo puede cometer el propio código del proyecto. Las reglas acotan *quién* toca *qué documento y qué campo*; la forma de los datos la garantizan los modelos y sus tests. |

## Justificación

Modelar el código real tiene una propiedad que modelar el diseño no tiene: **falla en voz alta**. Si una
operación del repositorio cambia y las reglas no la contemplan, la app enseña «Error al guardar» y los
tests de ADR-0026 lo señalan al ejecutarse. Las reglas anteriores, escritas para una arquitectura futura,
llevaban meses siendo falsas sin que nada lo dijera.

El coste asumido es que estas reglas hay que tocarlas cada vez que cambie una operación. Es el precio
correcto: obliga a que un cambio de acceso a datos sea una decisión consciente y no un efecto lateral.

## Consecuencias

- **Positiva:** `/users` deja de ser legible en bloque; el contacto de emergencia y el teléfono del familiar
  dejan de estar al alcance de cualquier sesión anónima.
- **Positiva:** cierra la divergencia «reglas de seguridad sin auditar» de `pending.md` §1 y la
  contradicción reglas-vs-código declarada en ADR-0008.
- **Positiva:** el fichero de reglas documenta, en castellano y junto a cada permiso, qué operación del
  repositorio lo justifica. Es la política de seguridad y su trazabilidad en el mismo sitio.
- **Coste:** cada nueva operación sobre Firestore exige tocar reglas y tests. Ya ocurrió una vez: las
  escalas locales de accesibilidad (ADR-0021) escriben `preferences` desde el dispositivo del mayor, y eso
  está cubierto por el permiso del dueño.
- **Coste asumido:** no hay validación de esquema en las reglas. Un cliente comprometido puede escribir
  basura en *su propio* documento.

## Verificación

29 casos contra el emulador (ADR-0026), organizados por sujeto: el dueño, el familiar vinculado, un
autenticado cualquiera, un no autenticado, las colecciones inexistentes y la no enumerabilidad de `/users`.
El despliegue de las reglas se hace con `firebase deploy --only firestore:rules` sobre el alias de proyecto
definido en `9e740aa`.
