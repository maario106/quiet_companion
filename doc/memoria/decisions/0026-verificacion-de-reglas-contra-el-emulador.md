# ADR-0026 — Las reglas se verifican contra el emulador, desde un paquete propio

- **Estado:** Aceptada
- **Fecha:** 2026-09-06
- **Ámbito:** Verificación de la política de acceso (RNF-9, RNF-13). Implementado.
- **Decisores:** Autor del TFG.
- **Evidencia:** `firestore-tests/` (`package.json`, `rules.test.js`, `README.md`), `firebase.json`,
  `functions/pairing.test.js`; commits `6efdb3a`, `b5093f0`, `8be3fa9`.
- **Relacionada con:** ADR-0025 (las reglas), ADR-0024 (la callable), ADR-0023 (JDK 21 fijado fuera del
  IDE).

---

## Contexto

Las reglas de Firestore son código: tienen condicionales, funciones y un modelo de evaluación propio, y
cuando fallan **no lanzan ningún error visible al desarrollador**. Fallan en el dispositivo de un usuario,
como un «Error al guardar» sin causa aparente. Una política de seguridad que nadie ejecuta es una hipótesis,
no una garantía — y el proyecto ya había pasado meses con reglas que contradecían su propio código sin que
nada lo advirtiera (ADR-0008).

## Decisión

Verificación en dos niveles, ninguno de los cuales toca la nube ni cuesta dinero:

1. **Reglas contra el emulador de Firestore**, con `@firebase/rules-unit-testing`, en un paquete npm propio
   en `firestore-tests/`: **29 casos** agrupados por sujeto (el dueño, el familiar vinculado, un autenticado
   cualquiera, un no autenticado, las colecciones que no existen y la no enumerabilidad de `/users`).
2. **Lógica de negocio pura sin emulador**, en `functions/pairing.test.js`: 10 casos sobre la precedencia
   del contacto de emergencia y la normalización del código. Vive separada de `index.js` precisamente para
   poder probarse sin Firestore ni `initializeApp()`.

Complementadas por un **guion de recorrido manual extremo a extremo** contra el emulador
(`firestore-tests/README.md`), con la tabla de qué regla ejercita cada paso de la app real.

Dos decisiones de fontanería que forman parte de la decisión y no de su implementación:

- **El paquete vive fuera de `functions/`.** `functions/` es lo que se despliega; meter ahí `firebase` y
  `@firebase/rules-unit-testing` engordaría cada despliegue con dependencias que el servidor no ejecuta.
- **El JDK 21 se antepone solo para el emulador.** El emulador exige Java 21 o superior; el build de Android
  del proyecto está fijado a Java 11. Cambiar el JDK por defecto del sistema arregla una cosa y rompe la
  otra, así que el script `test` antepone la ruta al PATH —`firebase-tools` mira el `java` del PATH, no
  `JAVA_HOME`, y poner solo `JAVA_HOME` no basta— y se puede sobreescribir con la variable `JDK21`. Es la
  misma tensión de versiones de Java que documenta ADR-0023.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **No probar las reglas** (estado anterior) | Es lo que permitió que reglas y código se contradijeran durante meses sin que nadie lo notara. |
| **Probarlas a mano desde la consola de Firebase** | El simulador de reglas de la consola prueba una operación cada vez y no queda registrado: no es repetible, no se ejecuta en cada cambio y no documenta nada. |
| **Meter los tests en `functions/`** | Engorda el artefacto desplegado con dependencias de test. Separar cuesta un `package.json` más. |
| **Probar contra el proyecto real de Firebase** | Escribe datos reales, cuesta dinero y exige credenciales en el entorno de test. El emulador da el mismo veredicto gratis y sin efectos. |
| **Cambiar el JDK por defecto del sistema a 21** | Rompe el build de Android, fijado a Java 11. La solución barata es acotar el cambio al comando que lo necesita. |

## Justificación

Un test de reglas responde a una pregunta que ninguna otra prueba del proyecto responde: *¿puede este
usuario hacer esto?* Los tests de Dart prueban que el cliente pide lo correcto; estos prueban que el
servidor **niega lo incorrecto**, incluso cuando quien pide no es el cliente del proyecto. Sin ellos, la
afirmación «RNF-9 se cumple» sería una lectura del código y no una comprobación.

Escribirlos tuvo además un efecto no previsto que conviene registrar: los primeros 29 casos se escribieron
*incluyendo los huecos* —casos que documentaban lo que las reglas todavía permitían— y fue eso lo que hizo
evidente que la vinculación desde el cliente obligaba a dejar `/users` enumerable. La reescritura posterior
(`b5093f0`) cerró el hueco y convirtió esos casos en aserciones de denegación. El test se escribió antes que
la solución y sirvió para encontrarla.

## Consecuencias

- **Positiva:** la política de seguridad es ejecutable y su incumplimiento se ve al ejecutar los tests, no
  en el móvil de un mayor.
- **Positiva:** el recorrido manual documentado convierte una comprobación que dependía de recordar los
  pasos en un guion con tabla de correspondencias regla ↔ paso.
- **Coste:** el repositorio tiene ahora **tres** ejecutores de pruebas —`flutter test`, `npm test` en
  `functions/` y `npm test` en `firestore-tests/`— y ninguna orquestación que los lance juntos.
- **Coste:** el emulador necesita un JDK distinto del que compila la app. Está documentado en el README,
  pero es un escalón de entrada para cualquiera que clone el repositorio.
- **Follow-on:** es el argumento más fuerte a favor de montar la integración continua pendiente
  (`pending.md` §5): tres suites que nadie ejecuta a la vez acabarán divergiendo.

## Verificación

`cd firestore-tests && npm test` (con el emulador arrancando desde el propio script) y
`cd functions && npm test`. El recorrido manual completo contra el proyecto real está **pendiente**.
