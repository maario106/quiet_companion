# ADR-0003 — Backend: Firebase (Backend-as-a-Service) frente a un servidor propio

- **Estado:** Aceptada
- **Fecha:** 2026-03-17
- **Ámbito:** Persistencia, autenticación y (diseñada) capa server-side. Firestore + Auth **implementados**;
  Cloud Functions **diseñado, no implementado**.
- **Decisores:** Autor del TFG.
- **Evidencia:** `doc/pdfs/Justificación del Stack Tecnológico.pdf` §2 (fuente de confianza del autor);
  commits `a642d44` (*Firebase configurado*, 2026-03-17) y `d05ef03` (*configuración inicial de firebase*);
  `firestore.rules`, `firestore.indexes.json`, `lib/firebase_options.dart`; `pubspec.yaml`
  (`firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`); `CLAUDE.md` (§Stack, plan Blaze).
- **Relacionada con:** ADR-0002 (LLM en la nube); ADR pendiente sobre **proxy de Cloud Functions**; ADR
  pendiente sobre **emparejamiento por transacción de cliente frente a Cloud Function** (tensión con las
  reglas de seguridad, ver HU-1 §5.2).

---

## Contexto

Un único desarrollador con un plazo fijo no puede permitirse construir y operar un backend tradicional
(servidor, base de datos, cifrado de credenciales) desde cero. Al mismo tiempo, el sistema **necesita
sincronización en la nube**: las preferencias de accesibilidad que el familiar edita desde su dispositivo
deben propagarse en tiempo real al del mayor (HU-4), y el modelo de auth es **dual** —anónimo para el mayor
(identidad ligada al dispositivo), correo y contraseña para el familiar—. Hay presupuesto cero para
infraestructura; el proyecto opera sobre el plan Blaze de Firebase con las capas gratuitas.

## Decisión

Se adopta **Firebase como Backend-as-a-Service (BaaS)**, descartando *"el desarrollo de un servidor backend
tradicional desde cero (ej. Spring Boot o Django)"*. Se usan **Cloud Firestore** (base de datos en tiempo
real) para preferencias y contexto conversacional, **Firebase Auth** (anónima + email/contraseña) para el
modelo dual de usuarios, y se prevén **Cloud Functions** para las operaciones sensibles a seguridad (proxy
del LLM y escrituras cross-user).

## Alternativas consideradas

| Alternativa | Motivo de rechazo |
|---|---|
| **Backend propio** (Spring Boot / Django + BBDD) | Exige programar y operar servidor, persistencia y *"la lógica de encriptación de credenciales desde cero"*; inviable para un desarrollador único con plazo fijo. |
| **Solo almacenamiento local** (sin backend) | Imposible: mayor y familiar están en dispositivos distintos y necesitan sincronización remota bidireccional (HU-4). |
| **Firebase BaaS (elegida)** | Base de datos en tiempo real gestionada, autenticación lista para usar y despliegue de Cloud Functions sobre el mismo proyecto GCP que el LLM. |

## Justificación

Citas literales de la fuente del autor (§2):

- **Gestión ágil de la base de datos:** *"Se utilizará Firestore para almacenar en tiempo real las
  preferencias de accesibilidad del usuario y el historial básico de conversaciones."*
- **Autenticación simplificada:** *"Permite gestionar el 'Modo Familiar/Tutor' y el 'Modo Independiente' de
  forma segura sin tener que programar la lógica de encriptación de credenciales desde cero."*
- **Seguridad de la Arquitectura (Cloud Functions):** *"Firebase permite desplegar Cloud Functions. Esto es
  un requisito de seguridad crítico: la aplicación móvil (Frontend) nunca se conectará directamente a la
  Inteligencia Artificial."*

La elección de Firestore como base en tiempo real es la que hace posible el patrón `currentUserProvider`
(*single source of truth* reactivo) sobre el que se apoyan HU-1 y HU-4.

## Consecuencias

**Positivas:**
- Columna vertebral reactiva: `currentUserProvider` (`StreamProvider` sobre `users/{uid}`) alimenta la
  propagación en caliente de preferencias (HU-4) y el desbloqueo automático del onboarding (HU-1).
- Autenticación dual gestionada sin código de cifrado propio.
- Misma cuenta y proyecto GCP que el LLM (ADR-0002) y el TTS: sin superficie adicional de credenciales.

**Negativas / coste asumido:**
- **Cloud Functions es hoy diseño, no realidad.** No existe una carpeta `functions/` con código desplegado;
  la clave de Gemini vive en `.env` en el cliente. El proxy que la fuente califica de *"requisito de
  seguridad crítico"* está **diseñado, no implementado** (RNF-8). → ADR dedicado + `scope.md` tabla 3.
- **Reglas de seguridad y código de emparejamiento en conflicto.** `firestore.rules` solo permite a un
  usuario escribir su **propio** documento (`isOwner`) y reserva `/pairings/` al servidor (`allow write: if
  false`), pero la vinculación se implementa como una **transacción de cliente** que escribe en el documento
  del mayor desde la sesión del familiar (ver HU-1 §5.2). Tensión sin resolver.
- Dependencia de conectividad para toda persistencia y sincronización (RNF-14).

## Verificación

Firestore y Firebase Auth funcionan y sostienen el onboarding, el dashboard en tiempo real y el
emparejamiento. Las reglas (`firestore.rules`) están committeadas, **pero en tensión con el código de
vinculación**. Cloud Functions no está desplegado: no hay artefacto que verificar.
