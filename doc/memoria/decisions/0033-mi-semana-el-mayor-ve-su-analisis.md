# ADR-0033 — "Mi semana": el mayor ve su propio análisis, con los mismos datos y otra pantalla

- **Estado:** Propuesta — la vista para el mayor independiente la decidió el autor; su extensión al mayor
  vinculado está pendiente de confirmación (ver `UNRESOLVED` al final)
- **Fecha:** 2026-09-26
- **Ámbito:** HU-6 (RF-8: *"presentar el agregado en una vista accesible al mayor independiente y al
  familiar, según el modo"*).
- **Decisores:** Autor del TFG.
- **Evidencia:** decisión del autor del 2026-09-26 (*"deberían poder visualizarlo ellos mismos para ver cómo se
  sienten y poder darse cuenta de qué les preocupa más"*); `doc/pdfs/Solución Propuesta - Historias de
  Usuario.pdf` (pantalla "Mi semana", refuerzo positivo; citado en `scope.md`);
  `lib/core/config/app_router.dart` (`RouterNotifier.redirect`); `CLAUDE.md` (sin acoplamiento horizontal).
  Commits: pendientes.
- **Relacionada con:** ADR-0007 (un núcleo, autonomía como configuración), ADR-0021 (visibilidad para todo
  mayor), ADR-0029, ADR-0030, ADR-0031, ADR-0013 (accesibilidad explícita).

---

## Contexto

El diseño anterior pensaba el análisis solo para el familiar. Al mayor independiente, que no tiene familiar
vinculado, eso no le aportaba nada. El autor decidió que el mayor pueda ver su propio análisis, y preguntó si
la separación de pantallas por perfil lo dificulta.

**No lo dificulta.** `RouterNotifier.redirect` solo encierra al **familiar**: lo manda a `/dashboard` desde
cualquier otra ruta. Un mayor ya dado de alta puede navegar a cualquier ruta suya (`/home`, `/settings/*`,
`/emergency`). Una ruta nueva para él es un `GoRoute` más y un punto de entrada.

El único ajuste está en el lado del familiar. La condición actual es
`location == '/dashboard' ? null : '/dashboard'`, así que cualquier subpantalla del panel, como el detalle de
una conversación, rebotaría a `/dashboard`. Hay que cambiarla por `startsWith('/dashboard')` y cubrirla en
`router_redirect_test.dart`.

## Decisión

1. **Mismos datos, dos pantallas.** Por la regla de no acoplar *features*, lo compartido va en `core/`:
   - el modelo de lectura: `ConversationRecord` (nivel `wellbeing`) y `ConversationContent` (nivel `full`);
   - sus providers de lectura, con las rutas en `FirestorePaths`;
   - la agregación semanal, como **función pura con tests**: días con conversación, ánimo predominante, temas
     más repetidos, recuento de señales. Si cada pantalla calculara por su cuenta acabarían divergiendo, que es
     la lección de `settings_rows.dart`.

   Cada lado tiene su pantalla y su sistema de diseño: "Mi semana" en una *feature* nueva del mayor, con las
   reglas de accesibilidad del mayor; y las secciones nuevas del panel en `features/dashboard`.
2. **Qué ve el mayor**: frases, no gráficas; texto grande; solo toques; un botón "Escuchar" que lo lee en voz
   alta.
   - Cuántos días ha hablado esta semana.
   - Cómo se ha sentido, en palabras ("Casi todos los días te has sentido bien").
   - De qué ha hablado más y qué le ha rondado la cabeza (temas de las conversaciones con la señal `worry`).
   - **Transparencia:** una línea "Tu familiar ve: …" con acceso directo a cambiarlo (ADR-0031). Así "Mi
     semana" es también la ventana del mayor a lo que se guarda de él (derecho de acceso, art. 15 RGPD).
3. **Sin etiquetas clínicas.** Las señales `loneliness`, `sadness` y `risk` **no** se muestran como etiquetas
   al mayor. El tono es de refuerzo positivo, como en el documento de solución. El apoyo en un momento de
   crisis corresponde al chat en vivo (ADR-0029), no a un resumen semanal.
4. **Punto de entrada** en `HomeScreen`, visible solo con el consentimiento activo y al menos una conversación
   analizada. La posición exacta se decide al implementar: la fila inferior ya tiene tres botones, uno de
   ellos inerte ("¿Teclado?").
5. **Quién la ve:** el mayor independiente (decisión del autor). Se **propone** extenderla a todo mayor con
   consentimiento, también al vinculado, por dos motivos:
   - los datos son suyos y debería ver al menos lo mismo que su familiar;
   - ADR-0021 ya mostró que limitar algo al independiente deja al vinculado sin nada.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Reutilizar la pantalla del panel para el mayor** | Incumple la accesibilidad del mayor: gráficas, texto pequeño y el tema visual del familiar. |
| **Que el análisis lo vea solo el familiar** (diseño anterior) | El mayor independiente no obtiene nada, y el vinculado no sabe qué se sabe de él. |
| **Mostrar las señales al mayor tal cual** ("soledad", "riesgo") | Ponerle etiquetas clínicas en su propia pantalla, lo contrario del refuerzo positivo. |
| **Que el asistente le cuente su semana por voz, dentro de la conversación** | Encaja con una app que prioriza la voz, pero mezclaría el análisis con la charla y lo haría aparecer sin pedirlo. Queda como posible extensión. |
| **Duplicar la agregación en cada *feature*** | Dos cálculos del mismo dato acaban dando números distintos. |

## Justificación

El análisis se hace sobre lo que dice el mayor. Si solo lo ve un tercero, el mayor queda como objeto de
seguimiento y no como destinatario. "Mi semana" invierte eso sin coste de arquitectura: comparte el modelo y
el cálculo, y separa solo la presentación, que es lo único que de verdad difiere entre los dos perfiles.

## Consecuencias

- **Positiva:** el mayor independiente obtiene valor directo del análisis.
- **Positiva:** transparencia; el mayor puede ver qué se guarda y qué ve su familiar.
- **Coste:** una pantalla accesible más que diseñar y probar, y el cambio en el enrutador para las
  subpantallas del familiar.

## Verificación

Criterio de cierre:

- Tests puros de la agregación semanal: semana vacía, un solo día, empate de ánimos, señales ausentes.
- `router_redirect_test.dart`: el familiar llega a `/dashboard/…`, y el mayor llega a su nueva ruta.
- Manual: con tres conversaciones analizadas, "Mi semana" las resume, se lee en voz alta y enseña qué ve el
  familiar.

> **UNRESOLVED — requiere decisión del autor:** ¿"Mi semana" es solo para el mayor independiente, o para todo
> mayor con consentimiento (también el vinculado)?
