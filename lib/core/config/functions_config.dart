/// Parámetros compartidos por las llamadas a Cloud Functions.
///
/// Separados de `tts_config.dart` desde que hay más de una callable: la región
/// no es un detalle del TTS, es de dónde vive el backend.
library;

/// Región de despliegue de las Cloud Functions. Debe coincidir con la del
/// despliegue real (`REGION` en `functions/index.js`): el SDK apunta a
/// `us-central1` por defecto y una región distinta da un 404 silencioso.
/// Europa por cercanía y por coherencia con Firestore (`eur3`).
const String kFunctionsRegion = 'europe-west1';

/// Vinculación mayor ↔ familiar. Vive en el servidor porque la búsqueda por
/// código es una consulta de colección que las reglas de Firestore no pueden
/// acotar (RNF-9, ADR-0008).
const String kValidateAndLinkCallable = 'validateAndLink';

/// Respuesta del mayor a guardar sus conversaciones (ADR-0030). La hora del
/// registro la pone el servidor: es la prueba del consentimiento, y las reglas
/// no dejan que ningún cliente lo escriba.
const String kSetConversationConsentCallable = 'setConversationConsent';
