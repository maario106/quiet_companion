# ADR-0001 — Framework de cliente: Flutter (Dart) para desarrollo multiplataforma

- **Estado:** Aceptada
- **Fecha:** 2026-03-10
- **Ámbito:** Cliente móvil completo (frontend). Implementado.
- **Decisores:** Autor del TFG.
- **Evidencia:** `doc/pdfs/Justificación del Stack Tecnológico.pdf` §1 (fuente de confianza del autor);
  commit `6479d15` (*Initializing Flutter Project*, 2026-03-10); `pubspec.yaml`; `CLAUDE.md` (§Stack —
  *locked*); `README.md`.
- **Relacionada con:** ADR-0002 (LLM en la nube), ADR-0003 (Firebase BaaS); ADR pendiente sobre arquitectura
  Clean Feature-Sliced; ADR pendiente sobre gestión de estado con Riverpod.

---

## Contexto

El proyecto es un TFG desarrollado por **una sola persona**, con fecha de entrega fija y en paralelo a un
empleo a tiempo completo. El público objetivo son personas mayores con posible brecha digital y limitaciones
visuales, lo que convierte el **control total sobre la interfaz** (botones de gran tamaño, alto contraste,
tipografía dinámica) en un requisito de primer orden, no en un detalle estético. La plataforma prioritaria
es Android de gama media-baja (`minSdk 24`, Android 7.0), habitual en el segmento de la *Silver Economy*.

Tres restricciones dominan la elección: (1) el coste de oportunidad de un único desarrollador, que no puede
mantener dos bases de código nativas; (2) la necesidad de una capa de presentación moldeable a mano, sin
depender de los componentes rígidos del sistema operativo; y (3) la curva de aprendizaje frente a un plazo
inamovible.

## Decisión

Se desarrolla el cliente con **Flutter (lenguaje Dart)**, como una única base de código que compila a
binario nativo Android (y, potencialmente, iOS). Es el primer pilar de la propuesta de stack de tres capas
—Flutter (frontend), Firebase (BaaS) y Cloud LLM API (IA)— documentada en la fuente del autor.

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Desarrollo nativo por plataforma** (Kotlin/Android + Swift/iOS) | Duplica el esfuerzo de un único desarrollador; inviable con el plazo. |
| **React Native** | Multiplataforma, pero con menor control fino de UI y sin la familiaridad previa con Dart que capitaliza Flutter. |
| **Aplicación web / PWA** | Menor control sobre el hardware (micrófono, permisos) y sobre la experiencia táctil accesible; peor integración con la síntesis y el reconocimiento de voz nativos. |
| **Flutter (elegida)** | Compilación nativa desde un solo código base; permite el *"Control absoluto de la Accesibilidad (UI/UX)"*; aprovecha experiencia previa en el ecosistema Dart. |

## Justificación

La fuente del autor fundamenta la elección en tres puntos, citados de forma literal:

- **Eficiencia de recursos:** *"Al ser un único desarrollador, Flutter permite compilar de forma nativa
  tanto para Android como para iOS desde un único código base, optimizando el tiempo de desarrollo."*
- **Control absoluto de la Accesibilidad (UI/UX):** *"Flutter destaca por su flexibilidad para construir
  interfaces personalizadas, permitiendo implementar fácilmente botones de gran tamaño, alto contraste y
  tipografías dinámicas sin depender de los componentes estándar rígidos del sistema operativo."*
- **Curva de aprendizaje mitigada:** *"Capitaliza el conocimiento y la experiencia previa adquirida en
  proyectos académicos anteriores utilizando el ecosistema Dart."*

El segundo punto es el decisivo para este proyecto: la accesibilidad (HU-3) exige poder redefinir por
completo el sistema de diseño. El código posterior lo confirma —los pisos tipográficos y las superficies
táctiles ≥ 88 px de `lib/core/theme/app_theme.dart` son exactamente el tipo de control que Flutter habilita.

## Consecuencias

**Positivas:**
- Una sola base de código para toda la interfaz; el sistema de diseño accesible se construye a medida (HU-3).
- Sienta la base técnica sobre la que se apoyan el resto de decisiones de stack (BaaS, LLM, arquitectura).

**Negativas / coste asumido:**
- Acopla el proyecto al ecosistema Flutter/Dart y a sus fijaciones de versión (p. ej., el conflicto entre
  `firebase_core` y Riverpod que motivó un pin de versiones; ver ADR de alineación de dependencias, pendiente).
- iOS queda como plataforma **potencial pero no probada**: el proyecto es *Android-primary* y no se ha
  verificado el binario iOS.

## Verificación

La aplicación compila y se ejecuta en Android. El sistema de diseño accesible está implementado sobre widgets
Flutter (HU-3). No existe verificación en iOS.
