/**
 * Cloud Functions de Quiet Companion.
 *
 * Codebase creado para ADR-0018: hasta ahora el proxy de Cloud Functions
 * estaba solo diseñado (ADR-0014, "Propuesta").
 *
 * Contiene la síntesis de voz (`synthesizeSpeech`) y la vinculación
 * (`validateAndLink`). La clave de Gemini sigue viviendo en el cliente y su
 * migración es trabajo aparte.
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const textToSpeech = require("@google-cloud/text-to-speech");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {resolveEmergencyContact, normalizeLinkCode} = require("./pairing");

initializeApp();

/** Región de despliegue. Debe coincidir con `kFunctionsRegion` del cliente. */
const REGION = "europe-west1";

/**
 * Voz de síntesis. Constante de servidor: el cliente NUNCA envía parámetros
 * de voz (menor superficie de abuso y una sola fuente de verdad del timbre).
 *
 * Chirp 3: HD sigue el patrón `<locale>-Chirp3-HD-<Nombre>`. Elegida
 * `Sulafat` porque es la única del catálogo que Google describe literalmente
 * como *Warm* — el registro que pide un acompañante para personas mayores.
 * Alternativas femeninas del mismo catálogo, por si en la escucha real suena
 * mal para la persona: Vindemiatrix (*Gentle*), Achernar (*Soft*),
 * Despina (*Smooth*), Gacrux (*Mature*), Leda (*Youthful*), Kore (*Firm*).
 *
 * Cambiar de voz = cambiar esta constante y redesplegar. Nada más.
 *
 * Verificación: `npm run list-voices` enumera las voces realmente disponibles
 * en el proyecto (requiere la API de Cloud Text-to-Speech habilitada y ADC).
 */
const VOICE_NAME = "es-ES-Chirp3-HD-Sulafat";
const LANGUAGE_CODE = "es-ES";

/**
 * Ritmo neutro. La preferencia de velocidad del mayor NO se aplica aquí sino
 * en el reproductor del cliente (ADR-0019): así el audio sintetizado es
 * independiente de la preferencia y el cliente sigue sin enviar parámetros de
 * voz. Rango admitido por Chirp 3: HD si algún día se moviera: 0.25 – 2.0.
 */
const SPEAKING_RATE = 1.0;

/**
 * Tope de seguridad por llamada. El troceado por frases lo hace el cliente;
 * esto solo evita que una petición anómala sintetice un texto enorme.
 */
const MAX_TEXT_LENGTH = 900;

// Cliente perezoso a nivel de módulo: se reutiliza entre invocaciones de una
// misma instancia caliente y evita pagar el arranque en cada llamada.
let client;

/** @return {textToSpeech.TextToSpeechClient} cliente ADC reutilizable. */
function ttsClient() {
  if (!client) client = new textToSpeech.TextToSpeechClient();
  return client;
}

/**
 * Sintetiza una frase en español con la voz Chirp 3: HD del proyecto.
 *
 * Entrada: `{ text: string }`. Salida: `{ audioContent: string }` (MP3 en
 * base64). Autenticación obligatoria; la anónima es válida (los mayores usan
 * Firebase Auth anónimo).
 */
exports.synthesizeSpeech = onCall(
    {
      region: REGION,
      memory: "256MiB",
      timeoutSeconds: 30,
      // Guardarraíl de coste para un proyecto sin financiación: una fuga o un
      // bucle en el cliente no puede escalar a cientos de instancias.
      maxInstances: 10,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Se requiere sesión iniciada.",
        );
      }

      const text = typeof request.data?.text === "string" ?
        request.data.text.trim() :
        "";

      if (text.length === 0) {
        throw new HttpsError("invalid-argument", "Texto vacío.");
      }
      if (text.length > MAX_TEXT_LENGTH) {
        throw new HttpsError(
            "invalid-argument",
            `Texto demasiado largo (máximo ${MAX_TEXT_LENGTH} caracteres).`,
        );
      }

      try {
        const [response] = await ttsClient().synthesizeSpeech({
          // Texto plano siempre: nunca se envuelve en SSML. La respuesta del
          // LLM es texto libre y un `<` suelto rompería el marcado.
          input: {text},
          voice: {languageCode: LANGUAGE_CODE, name: VOICE_NAME},
          audioConfig: {audioEncoding: "MP3", speakingRate: SPEAKING_RATE},
        });

        return {
          audioContent: Buffer.from(response.audioContent).toString("base64"),
        };
      } catch (error) {
        // El detalle se queda en el log; al cliente solo le llega un error
        // genérico y nunca el texto de entrada (es contenido conversacional).
        logger.error("Fallo de síntesis", {
          voice: VOICE_NAME,
          textLength: text.length,
          error: error.message,
        });
        throw new HttpsError("internal", "No se ha podido sintetizar la voz.");
      }
    },
);

// ─── Vinculación mayor ↔ familiar (RNF-9, ADR-0008) ──────────────────────

exports.validateAndLink = onCall(
    {
      region: REGION,
      memory: "256MiB",
      timeoutSeconds: 30,
      maxInstances: 10,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Se requiere sesión iniciada.");
      }

      const code = normalizeLinkCode(request.data?.code);

      if (code.length === 0) {
        throw new HttpsError(
            "invalid-argument",
            "El código no es válido o ya ha caducado.",
        );
      }

      const companionId = request.auth.uid;
      const db = getFirestore();
      const users = db.collection("users");

      // La query va fuera de la transacción (las transacciones no admiten
      // consultas) y el código se revalida dentro leyendo el documento: entre
      // una cosa y otra otro familiar puede haberlo usado.
      const found = await users
          .where("linkCode", "==", code)
          .where("role", "==", "elder")
          .limit(1)
          .get();

      if (found.empty) {
        throw new HttpsError(
            "not-found",
            "El código no es válido o ya ha caducado.",
        );
      }

      const elderRef = found.docs[0].ref;
      const companionRef = users.doc(companionId);

      try {
        await db.runTransaction(async (tx) => {
          const [elderSnap, companionSnap] = await Promise.all([
            tx.get(elderRef),
            tx.get(companionRef),
          ]);

          if (!elderSnap.exists || elderSnap.data().linkCode !== code) {
            throw new HttpsError(
                "not-found",
                "El código no es válido o ya ha caducado.",
            );
          }

          // Guarda nueva: el cliente no podía comprobarlo sobre sí mismo. Un
          // mayor anónimo no puede vincularse a otro mayor.
          const companionData = companionSnap.data();
          if (!companionSnap.exists || companionData.role !== "companion") {
            throw new HttpsError(
                "permission-denied",
                "Solo un familiar registrado puede vincularse.",
            );
          }

          const elderUpdate = {
            linkedCompanionId: companionId,
            autonomy: "dependent",
            linkCode: FieldValue.delete(), // El código es de un solo uso.
          };

          const contact =
            resolveEmergencyContact(elderSnap.data(), companionData);
          if (contact) elderUpdate.emergencyContact = contact;

          tx.update(elderRef, elderUpdate);
          tx.update(companionRef, {
            linkedElderId: elderRef.id,
            autonomy: "linked",
          });
        });
      } catch (error) {
        if (error instanceof HttpsError) throw error;
        // El detalle se queda en el log: al familiar no le sirve de nada y
        // puede contener identificadores de otra persona.
        logger.error("Fallo de vinculación", {
          companionId,
          error: error.message,
        });
        throw new HttpsError("internal", "No se ha podido vincular.");
      }

      return {elderId: elderRef.id};
    },
);
