# ADR-0024 — La vinculación se hace en el servidor: callable `validateAndLink`

- **Estado:** Aceptada
- **Fecha:** 2026-09-06
- **Ámbito:** Vinculación de perfiles (HU-1, RNF-9). Implementado.
- **Decisores:** Autor del TFG.
- **Evidencia:** `functions/index.js` (`exports.validateAndLink`), `functions/pairing.js`,
  `functions/pairing.test.js`, `lib/features/onboarding/data/auth_repository.dart`
  (`linkCompanionToElder`), `lib/core/config/functions_config.dart`, `firestore.rules`;
  commits `8be3fa9`, `4cbd57f`, `b5093f0`.
- **Supersede a:** ADR-0008 (emparejamiento por transacción de cliente).
- **Relacionada con:** ADR-0018 (codebase de Functions), ADR-0025 (reglas de Firestore), ADR-0014 (proxy
  del LLM, aún sin implementar), HU-1.

---

## Contexto

ADR-0008 dejó por escrito una incoherencia que el proyecto arrastraba desde abril: `CLAUDE.md` y RNF-9
exigen que las escrituras que tocan el documento de otro usuario vivan en un servidor de confianza, y la
vinculación las hacía desde el cliente, en la sesión del familiar. Se aceptó como estado provisional porque
no había infraestructura server-side desplegada.

Al escribir las reglas de seguridad reales (ADR-0025) esa provisionalidad dejó de ser sostenible, y por un
motivo más concreto y más incómodo que «lo dice el requisito»:

**Las reglas de Firestore no pueden acotar una consulta de colección.** No ven las cláusulas `where`: solo
pueden permitir o denegar la operación entera. Encontrar al mayor a partir de su código de cuatro
caracteres es exactamente eso —`where('linkCode', '==', code)`— así que mientras la búsqueda viviera en el
cliente, `/users` tenía que ser **consultable por cualquier usuario autenticado**. Cualquiera con la app
instalada y una sesión anónima podía volcar la colección entera de usuarios. El problema no era el estilo de
la escritura: era que la *lectura* obligaba a dejar la puerta abierta.

## Decisión

La vinculación pasa a una **Cloud Function callable, `validateAndLink`**, en el codebase gen 2 que ya
existía para `synthesizeSpeech` (ADR-0018), misma región `europe-west1`.

1. **El identificador del familiar deja de ser un parámetro**: el servidor lo toma de `request.auth.uid`.
   Nadie puede pedir que se vincule a un tercero, ni siquiera manipulando la petición.
2. **La búsqueda por código corre con el Admin SDK**, que se salta las reglas. El cliente ya no consulta
   `/users`, de modo que `allow list` puede cerrarse (ADR-0025).
3. **La consulta va fuera de la transacción y el código se revalida dentro**, releyendo el documento: las
   transacciones de Firestore no admiten consultas, y entre una cosa y otra otro familiar puede haber usado
   el mismo código.
4. **Guarda nueva que el cliente no podía hacer sobre sí mismo:** se comprueba que quien vincula tiene
   `role == "companion"`. Un mayor anónimo no puede vincularse a otro mayor.
5. **El código es de un solo uso**: la transacción lo borra (`FieldValue.delete()`) al vincular.
6. **La precedencia del contacto de emergencia se conserva** y se extrae a `pairing.js` como función pura
   (`resolveEmergencyContact`): un contacto elegido a mano por el mayor nunca se sobrescribe. Vive fuera de
   `index.js` para poder probarse sin Firestore, sin emulador y sin `initializeApp()`.
7. **Los errores se devuelven redactados** (`not-found`, `permission-denied`, `unauthenticated`) con
   mensajes en es-ES ya presentables; el detalle se queda en el log del servidor, porque puede contener
   identificadores de otra persona.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Mantener la transacción de cliente y abrir `allow list` sobre `/users`** | Es lo que había, y es justamente el agujero: convierte el directorio de usuarios en enumerable por cualquier sesión anónima. Cambiar el requisito para que encaje con el código no es resolver el problema, es dejar de mirarlo. |
| **Colección índice `/linkCodes/{codigo} → elderId`, legible por cualquier autenticado** | Resuelve la lectura sin abrir `/users`: el cliente lee un documento por identificador, no consulta. Pero deja intacta la otra mitad —el cliente sigue escribiendo en el documento del mayor— y obliga a mantener dos fuentes de verdad del código sincronizadas. Se paga complejidad de datos por conservar una arquitectura que igualmente incumple RNF-9. |
| **Reglas que validen la escritura cruzada** (permitir escribir el doc del mayor solo si se aporta el código correcto) | Una regla no puede exigir que el escritor *conozca* un secreto sin que ese secreto viaje en la escritura, y aun así el atacante puede probar códigos: 923 000 combinaciones son pocas para un bucle. Convierte la vinculación en un espacio de búsqueda. |
| **Esperar a HU-5 y migrar todo el backend de una vez** | El codebase de Functions ya estaba desplegado y probado desde ADR-0018. El coste marginal de una segunda callable era bajo, y el coste de instalar la app a usuarios reales con `/users` enumerable era inaceptable. |

## Justificación

La decisión que ADR-0008 aplazó se vuelve barata en el momento en que existe el codebase de Functions: es
la misma pieza que `synthesizeSpeech`, con otra lógica dentro. Y deja de ser opcional en el momento en que
las reglas se escriben de verdad, porque el precio de mantener la búsqueda en el cliente no era un requisito
incumplido en abstracto, sino una colección de usuarios enumerable por cualquiera.

Merece señalarse el orden en que ocurrió, porque es el argumento de proceso: **primero se escribieron las
reglas, y fueron las reglas las que obligaron a mover el código.** No al revés. Escribir la política de
seguridad como artefacto verificable (ADR-0026) es lo que convirtió una deuda declarada en una tarea con
límites.

## Consecuencias

- **Positiva:** RNF-9 se cumple. Las escrituras cruzadas viven en un entorno de confianza y el cliente no
  puede reclamar a un mayor por su cuenta, ni siquiera a uno con código libre.
- **Positiva:** `/users` deja de ser enumerable (`allow list: if false`, `b5093f0`).
- **Positiva:** el repositorio del cliente adelgaza —101 líneas menos en `auth_repository.dart`— y pasa de
  orquestar una transacción a llamar a una callable y traducir sus errores.
- **Positiva:** aparecen dos comprobaciones que en el cliente no eran posibles: el rol de quien vincula y el
  consumo del código en la misma transacción que lo valida.
- **Coste:** la vinculación pasa a depender de que la Function esté desplegada y accesible. Sin red, o con
  la Function caída, no se puede vincular. Antes fallaba igual, pero por otro motivo.
- **Coste:** primera llamada con arranque en frío. En un flujo que ocurre una vez por usuario, aceptable.
- **Coste:** se borra `test/features/onboarding/auth_repository_pairing_test.dart` (`4cbd57f`). Aquel test
  probaba un espejo en Dart de la lógica que ahora vive en Node; mantenerlo habría sido probar una copia que
  ya no ejecuta nadie. Su cobertura se reemplaza por `functions/pairing.test.js` (10 casos, sin emulador) y
  por el grupo de reglas «la vinculación ya no se hace desde el cliente» (ADR-0026).
- **Follow-on:** la misma pieza resuelve ADR-0014 (clave de Gemini). Queda pendiente y es hoy el único
  incumplimiento de seguridad declarado del proyecto.

## Verificación

- `functions/pairing.test.js`: **10 casos** sobre las reglas puras —precedencia del contacto de emergencia y
  normalización del código— ejecutables con `cd functions && npm test`, sin emulador.
- `firestore-tests/rules.test.js`: el grupo «la vinculación ya no se hace desde el cliente» comprueba que un
  familiar autenticado **no** puede escribir el documento de un mayor, ni siquiera con código libre, y que
  `/users` no se puede enumerar (ADR-0026).
- Recorrido manual extremo a extremo contra el emulador, documentado paso a paso en
  `firestore-tests/README.md` §«Recorrido de extremo a extremo»: el paso «meter el código en el panel del
  familiar» es el que ejercita la callable.
- Pendiente: ejecución del recorrido completo contra el proyecto real con dos dispositivos.
