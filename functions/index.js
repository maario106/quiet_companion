/**
 * Cloud Functions de Quiet Companion: síntesis de voz, vinculación,
 * consentimiento, análisis al cierre y chat en vivo.
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const textToSpeech = require("@google-cloud/text-to-speech");
const {GoogleGenAI} = require("@google/genai");
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
  ANALYSIS_PROMPT_VERSION,
  ANALYSIS_SYSTEM_PROMPT,
  ANALYSIS_RESPONSE_SCHEMA,
  parseCloseRequest,
  buildAnalysisInput,
  normalizeAnalysis,
  applyMemoryChanges,
  pushRecentSummary,
  retentionCutoffMs,
} = require("./conversation");
const {
  GUARDAR_NOMBRE_DECLARATION,
  CHAT_SAFETY_SETTINGS,
  parseChatRequest,
  memoryFromDoc,
  buildChatSystemPrompt,
  chatContents,
  replyTextOf,
  nameCallOf,
  nameResponseContent,
} = require("./chat");

initializeApp();

/** Región de despliegue. Debe coincidir con `kFunctionsRegion` del cliente. */
const REGION = "europe-west1";

/**
 * Voces Chirp 3: HD que el mayor puede elegir. El cliente envía solo la clave,
 * que coincide con ttsVoices (lib/core/config/tts_voices.dart).
 */
const VOICES = {
  sulafat: "es-ES-Chirp3-HD-Sulafat",
  vindemiatrix: "es-ES-Chirp3-HD-Vindemiatrix",
  achird: "es-ES-Chirp3-HD-Achird",
  algieba: "es-ES-Chirp3-HD-Algieba",
};

/** Voz por defecto; masculina para distinguirla de oído de la voz del móvil. */
const DEFAULT_VOICE = "achird";
const LANGUAGE_CODE = "es-ES";

/** Nombre completo de la voz; el de la voz por defecto si la clave no existe. */
function voiceNameFor(key) {
  // hasOwn evita propiedades heredadas como "constructor".
  return typeof key === "string" && Object.hasOwn(VOICES, key) ?
    VOICES[key] :
    VOICES[DEFAULT_VOICE];
}

/** Ritmo neutro: la velocidad del mayor se aplica en el reproductor del cliente. */
const SPEAKING_RATE = 1.0;

/** Tope por llamada; el troceado por frases lo hace el cliente. */
const MAX_TEXT_LENGTH = 900;

// Cliente reutilizado entre invocaciones de la misma instancia.
let client;

function ttsClient() {
  if (!client) client = new textToSpeech.TextToSpeechClient();
  return client;
}

/** Sintetiza una frase con la voz elegida. Devuelve { audioContent } en MP3 base64. */
exports.synthesizeSpeech = onCall(
    {
      region: REGION,
      memory: "256MiB",
      timeoutSeconds: 30,
      // Tope de coste ante un bucle en el cliente.
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

      const voiceName = voiceNameFor(request.data?.voice);

      try {
        const [response] = await ttsClient().synthesizeSpeech({
          // Siempre texto plano, nunca SSML.
          input: {text},
          voice: {languageCode: LANGUAGE_CODE, name: voiceName},
          audioConfig: {audioEncoding: "MP3", speakingRate: SPEAKING_RATE},
        });

        return {
          audioContent: Buffer.from(response.audioContent).toString("base64"),
        };
      } catch (error) {
        // Al cliente solo le llega un error genérico, nunca el texto.
        logger.error("Fallo de síntesis", {
          voice: voiceName,
          textLength: text.length,
          error: error.message,
        });
        throw new HttpsError("internal", "No se ha podido sintetizar la voz.");
      }
    },
);

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

      // La consulta no cabe en la transacción; el código se revalida dentro.
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

          // Un mayor no puede vincularse a otro mayor.
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
        // El detalle solo va al log.
        logger.error("Fallo de vinculación", {
          companionId,
          error: error.message,
        });
        throw new HttpsError("internal", "No se ha podido vincular.");
      }

      return {elderId: elderRef.id};
    },
);

/** Escrituras por lote (Firestore admite 500). */
const BATCH_SIZE = 400;

/** Aplica change(doc) a cada documento de una subcolección, en lotes. */
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

function millisOf(value) {
  return value instanceof Timestamp ? value.toMillis() : null;
}

/**
 * Congela lo guardado tras una retirada: adelanta su caducidad al fin del
 * periodo de gracia. El borrado lo hace la política TTL de Firestore.
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

/** Deshace el congelado si el mayor vuelve a consentir dentro del plazo. */
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
 * Registra la respuesta del mayor al consentimiento. Retirarlo congela lo
 * guardado, que se borra a mitad de plazo salvo que vuelva a consentir.
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

/** Modelo del análisis; se guarda con cada conversación. */
const ANALYSIS_MODEL = "gemini-2.5-flash";

/** Región de Vertex AI para el análisis. */
const GEMINI_LOCATION = "europe-west1";

let genai;

/** Cliente de Gemini sobre Vertex AI con credenciales del entorno (ADC). */
function geminiClient() {
  if (!genai) {
    const project = process.env.GCLOUD_PROJECT ||
      process.env.GOOGLE_CLOUD_PROJECT ||
      JSON.parse(process.env.FIREBASE_CONFIG || "{}").projectId;
    genai = new GoogleGenAI({vertexai: true, project, location: GEMINI_LOCATION});
  }
  return genai;
}

/** Una sola llamada estructurada: resumen, ánimo, señales, temas y memoria. */
async function analyzeConversation(turns, facts) {
  const response = await geminiClient().models.generateContent({
    model: ANALYSIS_MODEL,
    contents: [{
      role: "user",
      parts: [{text: buildAnalysisInput(turns, facts)}],
    }],
    config: {
      systemInstruction: ANALYSIS_SYSTEM_PROMPT,
      temperature: 0.2,
      responseMimeType: "application/json",
      responseSchema: ANALYSIS_RESPONSE_SCHEMA,
    },
  });

  try {
    return normalizeAnalysis(JSON.parse(response.text ?? ""));
  } catch (_) {
    return null;
  }
}

/** Borra lo que quede fuera del plazo vigente, por si se acortó después. */
async function deleteOutsideRetention(userRef, cutoffMs) {
  const cutoff = Timestamp.fromMillis(cutoffMs);
  for (const name of [
    COLLECTIONS.conversations,
    COLLECTIONS.conversationContents,
  ]) {
    const old = await userRef.collection(name)
        .where("endedAt", "<", cutoff)
        .get();
    for (let i = 0; i < old.docs.length; i += BATCH_SIZE) {
      const batch = userRef.firestore.batch();
      old.docs.slice(i, i + BATCH_SIZE).forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }
  }
}

/**
 * Analiza una conversación terminada y guarda solo el resultado; la
 * transcripción se descarta. Sin turns solo se registra la actividad.
 */
exports.closeConversation = onCall(
    {
      region: REGION,
      memory: "512MiB",
      timeoutSeconds: 60,
      maxInstances: 10,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Se requiere sesión iniciada.");
      }

      const nowMs = Date.now();
      const input = parseCloseRequest(request.data, nowMs);
      if (!input) {
        throw new HttpsError("invalid-argument", "Conversación no válida.");
      }

      const uid = request.auth.uid;
      const userRef = getFirestore().collection(COLLECTIONS.users).doc(uid);
      const snap = await userRef.get();
      if (!snap.exists || snap.get("role") !== "elder") {
        throw new HttpsError("permission-denied", "Solo para personas mayores.");
      }
      // Sin consentimiento no se analiza ni se guarda nada.
      if (snap.get("conversationConsent.granted") !== true) {
        throw new HttpsError(
            "failed-precondition",
            "No hay consentimiento para guardar conversaciones.",
        );
      }

      const retentionDays =
        effectiveRetentionDays(snap.get("conversationSettings"));
      const conversationRef =
        userRef.collection(COLLECTIONS.conversations).doc();
      const expireAt =
        Timestamp.fromMillis(expireAtMs(input.endedAtMs, retentionDays));
      const endedAt = Timestamp.fromMillis(input.endedAtMs);

      const memoryRef =
        userRef.collection(COLLECTIONS.memory).doc(MEMORY_PROFILE_DOC);

      let status = "too_short";
      let analysis = null;
      let memory = null;
      if (input.turns) {
        try {
          memory = (await memoryRef.get()).data() ?? {};
          analysis = await analyzeConversation(input.turns, memory.facts);
          status = analysis ? "analyzed" : "failed";
        } catch (error) {
          status = "failed";
          // Solo metadatos, nunca el texto.
          logger.error("Fallo del análisis", {
            uid,
            conversationId: conversationRef.id,
            turns: input.turns.length,
            chars: input.turns.reduce((n, t) => n + t.text.length, 0),
            error: error.message,
          });
        }
      }

      const batch = userRef.firestore.batch();
      batch.set(conversationRef, {
        startedAt: Timestamp.fromMillis(input.startedAtMs),
        endedAt,
        elderTurns: input.elderTurns,
        endReason: input.endReason,
        status,
        sentiment: analysis?.sentiment ?? null,
        signals: analysis?.signals ?? [],
        promptVersion: ANALYSIS_PROMPT_VERSION,
        model: ANALYSIS_MODEL,
        expireAt,
      });
      if (analysis) {
        batch.set(
            userRef.collection(COLLECTIONS.conversationContents)
                .doc(conversationRef.id),
            {
              endedAt,
              topics: analysis.topics,
              summary: analysis.summary,
              expireAt,
            },
        );

        // Se aplican cambios sobre la memoria, no un perfil reescrito, y con tope.
        const {facts, dropped} =
          applyMemoryChanges(memory?.facts, analysis.memory);
        if (dropped > 0) {
          logger.info("Memoria llena: altas descartadas", {uid, dropped});
        }
        const recent = pushRecentSummary(
            (memory?.recent ?? []).map((r) => ({
              endedAtMs: millisOf(r.endedAt) ?? 0,
              summary: r.summary,
            })),
            {endedAtMs: input.endedAtMs, summary: analysis.summary},
        );
        batch.set(memoryRef, {
          facts,
          recent: recent.map((r) => ({
            endedAt: Timestamp.fromMillis(r.endedAtMs),
            summary: r.summary,
          })),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      await deleteOutsideRetention(
          userRef, retentionCutoffMs(nowMs, retentionDays));

      return {conversationId: conversationRef.id, status};
    },
);

const CHAT_MODEL = "gemini-2.5-flash";

/** candidates[0].content de la respuesta, o null. */
async function generateChatReply(contents, config) {
  const response = await geminiClient().models.generateContent({
    model: CHAT_MODEL,
    contents,
    config,
  });
  return response.candidates?.[0]?.content ?? null;
}

/**
 * Un turno de la conversación con el mayor. Lee nombre y memoria en cada
 * turno y no guarda nada entre llamadas. Devuelve { text }.
 */
exports.chatTurn = onCall(
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

      const input = parseChatRequest(request.data);
      if (!input) {
        throw new HttpsError("invalid-argument", "Turno no válido.");
      }

      const uid = request.auth.uid;
      const userRef = getFirestore().collection(COLLECTIONS.users).doc(uid);
      const snap = await userRef.get();
      if (!snap.exists || snap.get("role") !== "elder") {
        throw new HttpsError("permission-denied", "Solo para personas mayores.");
      }

      // Sin consentimiento la memoria ni se lee.
      const memory = snap.get("conversationConsent.granted") === true ?
        memoryFromDoc((await userRef.collection(COLLECTIONS.memory)
            .doc(MEMORY_PROFILE_DOC).get()).data()) :
        null;

      const config = {
        systemInstruction: buildChatSystemPrompt(
            snap.get("name"), memory, Date.now(), input.utcOffsetMinutes),
        tools: [{functionDeclarations: [GUARDAR_NOMBRE_DECLARATION]}],
        safetySettings: CHAT_SAFETY_SETTINGS,
      };
      const contents = chatContents(input.history, input.message);

      try {
        const first = await generateChatReply(contents, config);
        let text = replyTextOf(first);

        const call = nameCallOf(first);
        if (call) {
          let saved = null;
          if (call.name) {
            try {
              await userRef.update({name: call.name});
              saved = call.name;
            } catch (error) {
              logger.error("Fallo al guardar el nombre", {
                uid,
                error: error.message,
              });
            }
          }
          // La respuesta de la función va junto a la llamada tal cual llegó.
          contents.push(first, nameResponseContent(saved));
          text = replyTextOf(await generateChatReply(contents, config)) ?? text;
        }

        return {text};
      } catch (error) {
        // Solo metadatos, nunca el texto.
        logger.error("Fallo del chat", {
          uid,
          turns: input.history.length,
          error: error.message,
        });
        throw new HttpsError("internal", "No se ha podido responder.");
      }
    },
);
