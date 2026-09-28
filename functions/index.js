/**
 * Cloud Functions de Quiet Companion.
 *
 * Codebase creado para ADR-0018: hasta ahora el proxy de Cloud Functions
 * estaba solo diseñado (ADR-0014, "Propuesta").
 *
 * Contiene la síntesis de voz (`synthesizeSpeech`), la vinculación
 * (`validateAndLink`) y el consentimiento sobre las conversaciones
 * (`setConversationConsent`). La clave de Gemini del chat en vivo sigue en el
 * cliente y su migración es trabajo aparte (ADR-0014).
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const textToSpeech = require("@google-cloud/text-to-speech");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, Timestamp} =
  require("firebase-admin/firestore");
const {resolveEmergencyContact, normalizeLinkCode} = require("./pairing");
const {
  COLLECTIONS,
  MEMORY_PROFILE_DOC,
  effectiveRetentionDays,
  expireAtMs,
  graceDeadlineMs,
  frozenExpireAtMs,
  parseConsentRequest,
} = require("./conversation");

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

// ─── Consentimiento sobre las conversaciones (ADR-0030) ──────────────────

/** Escrituras por lote: Firestore admite 500 por batch; se deja margen. */
const BATCH_SIZE = 400;

/**
 * Aplica `change(doc)` a todos los documentos de una subcolección del mayor,
 * en lotes. `change` devuelve el objeto a fusionar, o null para no tocarlo.
 *
 * @param {FirebaseFirestore.DocumentReference} userRef documento del mayor.
 * @param {string} name subcolección.
 * @param {function} change doc → cambios | null.
 */
async function updateEach(userRef, name, change) {
  const db = userRef.firestore;
  const docs = (await userRef.collection(name).get()).docs;
  for (let i = 0; i < docs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    for (const doc of docs.slice(i, i + BATCH_SIZE)) {
      const update = change(doc);
      if (update) batch.update(doc.ref, update);
    }
    await batch.commit();
  }
}

/**
 * @param {*} value campo leído de un documento.
 * @return {number|null} milisegundos si es un Timestamp, o null.
 */
function millisOf(value) {
  return value instanceof Timestamp ? value.toMillis() : null;
}

/**
 * Congela lo guardado tras una retirada: adelanta la caducidad de cada
 * documento al fin del periodo de gracia. El borrado lo hace la política TTL
 * de Firestore sobre `expireAt`; no hace falta ninguna tarea programada.
 *
 * @param {FirebaseFirestore.DocumentReference} userRef documento del mayor.
 * @param {Timestamp} deadline fin del periodo de gracia.
 */
async function freezeForDeletion(userRef, deadline) {
  const deadlineMs = deadline.toMillis();
  const freeze = (doc) => ({
    expireAt: Timestamp.fromMillis(
        frozenExpireAtMs(millisOf(doc.get("expireAt")), deadlineMs)),
  });
  await updateEach(userRef, COLLECTIONS.conversations, freeze);
  await updateEach(userRef, COLLECTIONS.conversationContents, freeze);

  const memoryRef =
    userRef.collection(COLLECTIONS.memory).doc(MEMORY_PROFILE_DOC);
  if ((await memoryRef.get()).exists) {
    await memoryRef.update({expireAt: deadline});
  }
}

/**
 * Deshace el congelado si el mayor vuelve a consentir dentro del periodo de
 * gracia: cada conversación recupera su caducidad normal y la memoria deja de
 * caducar.
 *
 * @param {FirebaseFirestore.DocumentReference} userRef documento del mayor.
 * @param {number} retentionDays plazo vigente.
 */
async function restoreExpiry(userRef, retentionDays) {
  const restore = (doc) => {
    const endedAtMs = millisOf(doc.get("endedAt"));
    if (endedAtMs === null) return null;
    return {
      expireAt: Timestamp.fromMillis(expireAtMs(endedAtMs, retentionDays)),
    };
  };
  await updateEach(userRef, COLLECTIONS.conversations, restore);
  await updateEach(userRef, COLLECTIONS.conversationContents, restore);

  const memoryRef =
    userRef.collection(COLLECTIONS.memory).doc(MEMORY_PROFILE_DOC);
  if ((await memoryRef.get()).exists) {
    await memoryRef.update({expireAt: FieldValue.delete()});
  }
}

/**
 * Registra la respuesta del mayor a "¿guardo un resumen de nuestras
 * conversaciones?".
 *
 * Entrada: `{ granted: boolean, textVersion: number }`. Solo la puede llamar
 * el propio mayor sobre sí mismo: el identificador sale de la sesión, así que
 * un familiar no puede consentir por él (ADR-0030).
 *
 * - Conceder: guarda el registro con la hora del servidor y, si está
 *   vinculado y aún no eligió, deja que su familiar lo vea todo (ADR-0031).
 *   Si venía de una retirada pendiente, recupera lo congelado.
 * - Retirar (tras haber concedido): lo guardado queda congelado y se borra
 *   pasada la mitad del plazo de conservación, salvo que vuelva a consentir.
 * - "Ahora no" sin haber concedido nunca: solo se registra, para no volver a
 *   preguntar.
 */
exports.setConversationConsent = onCall(
    {
      region: REGION,
      memory: "256MiB",
      timeoutSeconds: 60,
      maxInstances: 10,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Se requiere sesión iniciada.");
      }

      const input = parseConsentRequest(request.data);
      if (!input) {
        throw new HttpsError("invalid-argument", "Respuesta no válida.");
      }

      const userRef =
        getFirestore().collection(COLLECTIONS.users).doc(request.auth.uid);
      const snap = await userRef.get();
      if (!snap.exists || snap.get("role") !== "elder") {
        throw new HttpsError(
            "permission-denied",
            "Solo la persona mayor puede decidir sobre sus conversaciones.",
        );
      }

      const data = snap.data();
      const previous = data.conversationConsent;
      const wasGranted = previous?.granted === true;
      const pendingDeletion = !wasGranted && previous?.deleteAfter != null;
      const retentionDays = effectiveRetentionDays(data.conversationSettings);

      const record = {
        granted: input.granted,
        answeredAt: FieldValue.serverTimestamp(),
        textVersion: input.textVersion,
      };

      try {
        if (input.granted) {
          const update = {conversationConsent: record};
          if (data.linkedCompanionId && !data.companionSharing) {
            update.companionSharing = "full";
          }
          await userRef.update(update);
          if (pendingDeletion) await restoreExpiry(userRef, retentionDays);
        } else if (wasGranted) {
          const deadline = Timestamp.fromMillis(
              graceDeadlineMs(Date.now(), retentionDays));
          record.revokedAt = FieldValue.serverTimestamp();
          record.deleteAfter = deadline;
          await userRef.update({conversationConsent: record});
          await freezeForDeletion(userRef, deadline);
        } else {
          // Un "no" repetido no reinicia un borrado ya en marcha.
          if (pendingDeletion) {
            record.revokedAt = previous.revokedAt ?? null;
            record.deleteAfter = previous.deleteAfter;
          }
          await userRef.update({conversationConsent: record});
        }
      } catch (error) {
        logger.error("Fallo al registrar el consentimiento", {
          uid: request.auth.uid,
          granted: input.granted,
          error: error.message,
        });
        throw new HttpsError(
            "internal",
            "No se ha podido guardar tu respuesta.",
        );
      }

      return {granted: input.granted};
    },
);
