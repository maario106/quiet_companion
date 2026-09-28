/**
 * Reglas puras de las conversaciones del mayor: consentimiento, plazos de
 * conservación y análisis (ADR-0029, ADR-0030, ADR-0034).
 *
 * Como `pairing.js`, viven fuera de `index.js` para poder testearlas sin
 * Firestore, sin emulador y sin Gemini: son la parte con criterio, y la que
 * decide cuándo se borran datos de una persona mayor.
 */

const DAY_MS = 24 * 60 * 60 * 1000;

/** Colecciones bajo `users/{elderId}`. Espejo de `FirestorePaths` del cliente. */
const COLLECTIONS = {
  users: "users",
  conversations: "conversations",
  conversationContents: "conversationContents",
  memory: "memory",
};
const MEMORY_PROFILE_DOC = "profile";

/**
 * Plazos de conservación admitidos (ADR-0034). El tope lo pone el servidor:
 * diga lo que diga el documento, nada se guarda más de seis meses.
 */
const RETENTION_DAYS_STEPS = [30, 60, 90, 180];
const DEFAULT_RETENTION_DAYS = 90;

/**
 * Peldaño más cercano; en empate, el más bajo (lo más conservador).
 *
 * @param {number[]} steps peldaños en orden ascendente.
 * @param {number} value valor pedido.
 * @return {number} peldaño elegido.
 */
function nearestStep(steps, value) {
  let best = steps[0];
  for (const step of steps) {
    if (Math.abs(step - value) < Math.abs(best - value)) best = step;
  }
  return best;
}

/**
 * Plazo de conservación vigente para un mayor.
 *
 * @param {object|undefined} conversationSettings campo del documento.
 * @return {number} días, siempre dentro de [30, 180].
 */
function effectiveRetentionDays(conversationSettings) {
  const raw = conversationSettings?.retentionDays;
  if (typeof raw !== "number" || !Number.isFinite(raw)) {
    return DEFAULT_RETENTION_DAYS;
  }
  return nearestStep(RETENTION_DAYS_STEPS, raw);
}

/**
 * Caducidad normal de lo analizado en una conversación.
 *
 * @param {number} endedAtMs fin de la conversación, en milisegundos.
 * @param {number} retentionDays plazo vigente.
 * @return {number} milisegundos de `expireAt`.
 */
function expireAtMs(endedAtMs, retentionDays) {
  return endedAtMs + retentionDays * DAY_MS;
}

/**
 * Fecha de borrado tras retirar el consentimiento: la mitad del plazo de
 * conservación vigente (ADR-0030, epílogo). 45 días con el plazo por defecto.
 *
 * @param {number} revokedAtMs momento de la retirada.
 * @param {number} retentionDays plazo vigente al retirar.
 * @return {number} milisegundos a partir de los que se borra.
 */
function graceDeadlineMs(revokedAtMs, retentionDays) {
  return revokedAtMs + Math.floor(retentionDays / 2) * DAY_MS;
}

/**
 * Caducidad de un documento congelado por una retirada: la que ocurra antes
 * de la suya normal y el fin del periodo de gracia. Retirar el consentimiento
 * nunca alarga la vida de un dato.
 *
 * @param {number|null} currentMs `expireAt` actual, o null si no tiene.
 * @param {number} deadlineMs fin del periodo de gracia.
 * @return {number} nueva caducidad.
 */
function frozenExpireAtMs(currentMs, deadlineMs) {
  if (typeof currentMs !== "number") return deadlineMs;
  return Math.min(currentMs, deadlineMs);
}

/**
 * Valida la petición de `setConversationConsent`.
 *
 * @param {*} data `request.data`.
 * @return {{granted: boolean, textVersion: number}|null} null si no es válida.
 */
function parseConsentRequest(data) {
  if (typeof data?.granted !== "boolean") return null;
  const version = data?.textVersion;
  if (!Number.isInteger(version) || version < 1) return null;
  return {granted: data.granted, textVersion: version};
}

// ─── Análisis al cierre (ADR-0029) ────────────────────────────────────────

/** Espejo de `kMinElderTurnsForAnalysis` del cliente (ADR-0028). */
const MIN_ELDER_TURNS_FOR_ANALYSIS = 3;

/**
 * Versión del prompt de análisis. Se guarda en cada conversación para poder
 * distinguir registros producidos por versiones distintas.
 */
const ANALYSIS_PROMPT_VERSION = 2; // v2: la misma llamada extrae la memoria.

const END_REASONS = ["inactivity", "background"];
const ROLES = ["elder", "assistant"];
const SENTIMENTS = ["positive", "neutral", "negative"];

/** Lista cerrada de señales (ADR-0029). */
const SIGNALS = [
  "loneliness",
  "sadness",
  "worry",
  "physical_discomfort",
  "confusion",
  "risk",
];

/** Topes de tamaño: una conversación de voz real queda muy por debajo. */
const MAX_TURNS = 200;
const MAX_TURN_CHARS = 2000;
const MAX_TOPICS = 5;
const MAX_TOPIC_CHARS = 40;
const MAX_SUMMARY_CHARS = 400;

/** Memoria del mayor (ADR-0032). */
const MAX_MEMORY_FACTS = 30;
const MAX_MEMORY_CHANGES = 10;
const MAX_MEMORY_KEY_CHARS = 30;
const MAX_MEMORY_VALUE_CHARS = 80;
const RECENT_SUMMARIES = 3;

/** Holgura para relojes de dispositivo desajustados. */
const CLOCK_SKEW_MS = 10 * 60 * 1000;
const MAX_CONVERSATION_MS = 24 * 60 * 60 * 1000;

/**
 * Valida y normaliza la petición de `closeConversation`.
 *
 * @param {*} data `request.data`.
 * @param {number} nowMs hora del servidor.
 * @return {object|null} petición normalizada, o null si no es válida.
 */
function parseCloseRequest(data, nowMs) {
  const startedAtMs = data?.startedAt;
  const endedAtMs = data?.endedAt;
  if (!Number.isInteger(startedAtMs) || !Number.isInteger(endedAtMs)) {
    return null;
  }
  if (endedAtMs < startedAtMs) return null;
  if (endedAtMs > nowMs + CLOCK_SKEW_MS) return null;
  if (endedAtMs - startedAtMs > MAX_CONVERSATION_MS) return null;
  if (!END_REASONS.includes(data?.endReason)) return null;
  if (!Number.isInteger(data?.elderTurns) || data.elderTurns < 0) return null;

  let turns = null;
  if (data.turns != null) {
    if (!Array.isArray(data.turns) || data.turns.length > MAX_TURNS) {
      return null;
    }
    turns = [];
    for (const turn of data.turns) {
      if (!ROLES.includes(turn?.role) || typeof turn?.text !== "string") {
        return null;
      }
      const text = turn.text.trim().slice(0, MAX_TURN_CHARS);
      if (text.length > 0) turns.push({role: turn.role, text});
    }
  }

  // El número de turnos del mayor lo cuenta el servidor si tiene el texto: no
  // se fía del que declara el cliente.
  const elderTurns = turns ?
    turns.filter((t) => t.role === "elder").length :
    data.elderTurns;

  return {
    startedAtMs,
    endedAtMs,
    endReason: data.endReason,
    elderTurns,
    turns: turns && elderTurns >= MIN_ELDER_TURNS_FOR_ANALYSIS ? turns : null,
  };
}

/**
 * Transcripción para el modelo. "M:" es la persona mayor y "A:" el asistente.
 *
 * @param {{role: string, text: string}[]} turns turnos validados.
 * @return {string} una línea por turno.
 */
function buildTranscript(turns) {
  return turns
      .map((t) => `${t.role === "elder" ? "M" : "A"}: ${t.text}`)
      .join("\n");
}

/**
 * Mensaje para el modelo: lo que ya se sabe de M y la conversación.
 *
 * @param {{role: string, text: string}[]} turns turnos validados.
 * @param {Object<string, string>} facts memoria actual.
 * @return {string} contenido del mensaje.
 */
function buildAnalysisInput(turns, facts) {
  const known = Object.entries(facts ?? {});
  const memory = known.length === 0 ?
    "(nada todavía)" :
    known.map(([key, value]) => `- ${key}: ${value}`).join("\n");
  return `Lo que ya sé de M:\n${memory}\n\nConversación:\n` +
    buildTranscript(turns);
}

/** Instrucción de sistema del análisis. Versionada con ANALYSIS_PROMPT_VERSION. */
const ANALYSIS_SYSTEM_PROMPT = [
  "Analizas conversaciones entre una persona mayor (M) y un asistente de " +
    "compañía por voz (A). Lo que escribas lo leerá la propia persona y, si " +
    "ella lo permite, un familiar. Devuelve solo el JSON pedido.",
  "",
  "Reglas:",
  "- El texto viene de un reconocedor de voz: puede tener errores, palabras " +
    "cortadas y falta de puntuación. Interpreta con prudencia.",
  "- Evalúa solo lo que dice la persona mayor (M). Lo que dice el asistente " +
    "(A) es contexto: siempre es amable y no dice nada de cómo se siente M.",
  "- sentiment: el ánimo general que expresa M en esta conversación. Si no " +
    "expresa nada claro, neutral.",
  "- signals: solo las que M expresa por sí misma, nunca las que A pregunta o " +
    "sugiere. Lista vacía si no hay ninguna.",
  "  - loneliness: dice sentirse sola, que echa de menos compañía, que nadie " +
    "la visita o la llama.",
  "  - sadness: tristeza, desánimo, pena.",
  "  - worry: preocupación, miedo o nervios por algo concreto.",
  "  - physical_discomfort: dolor, malestar, cansancio físico, mal dormir.",
  "  - confusion: desorientación, no saber dónde está o qué día es.",
  "  - risk: habla de hacerse daño, de no querer vivir o de que sería mejor " +
    "no estar.",
  "- topics: de 0 a 5 temas de los que habló M, de una a tres palabras cada " +
    "uno, en minúscula y en español (\"familia\", \"jardín\", \"médico\"). " +
    "Sin nombres propios.",
  "- summary: una o dos frases en tercera persona sobre de qué habló M y cómo " +
    "estaba. Sin citas literales, sin diagnósticos y sin detalles médicos " +
    "(como mucho, \"mencionó molestias\"). A otras personas, por su relación " +
    "(\"su nieto\", \"una vecina\"), no por su nombre.",
  "- memory: cambios en lo que conviene recordar de M para próximas " +
    "conversaciones (su familia y la relación con cada uno, dónde vive, " +
    "aficiones, rutinas, mascotas, gustos). Recibes lo que ya se sabe en " +
    "\"Lo que ya sé de M\". Devuelve solo cambios: en upsert, datos nuevos " +
    "o corregidos, con una clave corta en minúscula (\"nieto\", \"ciudad\") " +
    "y un valor breve (\"Pablo, 8 años\"); en remove, las claves de datos que " +
    "M ha corregido o ha pedido olvidar. Nunca datos de salud, medicación ni " +
    "diagnósticos. De otras personas, solo nombre y relación. Si no hay nada " +
    "nuevo, listas vacías.",
  "- No inventes. Si la conversación fue breve o trivial, dilo así.",
].join("\n");

/** Esquema de salida para Gemini (tipos en el formato de `@google/genai`). */
const ANALYSIS_RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    sentiment: {type: "STRING", enum: SENTIMENTS},
    signals: {type: "ARRAY", items: {type: "STRING", enum: SIGNALS}},
    topics: {type: "ARRAY", items: {type: "STRING"}},
    summary: {type: "STRING"},
    memory: {
      type: "OBJECT",
      properties: {
        upsert: {
          type: "ARRAY",
          items: {
            type: "OBJECT",
            properties: {key: {type: "STRING"}, value: {type: "STRING"}},
            required: ["key", "value"],
          },
        },
        remove: {type: "ARRAY", items: {type: "STRING"}},
      },
      required: ["upsert", "remove"],
    },
  },
  required: ["sentiment", "signals", "topics", "summary", "memory"],
  propertyOrdering: ["sentiment", "signals", "topics", "summary", "memory"],
};

/**
 * Sanea la respuesta del modelo. El esquema estructurado la hace casi siempre
 * válida, pero lo que se escribe en la base de datos no depende de "casi".
 *
 * @param {*} raw JSON ya parseado.
 * @return {object|null} análisis utilizable, o null si no lo es.
 */
function normalizeAnalysis(raw) {
  if (raw == null || typeof raw !== "object") return null;

  const summary = typeof raw.summary === "string" ?
    raw.summary.trim().slice(0, MAX_SUMMARY_CHARS) :
    "";
  if (summary.length === 0) return null;

  const sentiment = SENTIMENTS.includes(raw.sentiment) ? raw.sentiment : null;

  const signals = Array.isArray(raw.signals) ?
    [...new Set(raw.signals.filter((s) => SIGNALS.includes(s)))] :
    [];

  const topics = [];
  if (Array.isArray(raw.topics)) {
    for (const topic of raw.topics) {
      if (typeof topic !== "string") continue;
      const clean = topic.trim().toLowerCase().slice(0, MAX_TOPIC_CHARS);
      if (clean.length > 0 && !topics.includes(clean)) topics.push(clean);
      if (topics.length === MAX_TOPICS) break;
    }
  }

  return {
    sentiment,
    signals,
    topics,
    summary,
    memory: normalizeMemoryChanges(raw.memory),
  };
}

/**
 * Clave de memoria utilizable: minúsculas, corta, sin símbolos raros.
 *
 * @param {*} raw clave propuesta por el modelo.
 * @return {string} clave limpia, o "" si no sirve.
 */
function cleanMemoryKey(raw) {
  if (typeof raw !== "string") return "";
  const key = raw.trim().toLowerCase().replace(/\s+/g, " ");
  if (key.length === 0 || key.length > MAX_MEMORY_KEY_CHARS) return "";
  return /^[a-z0-9áéíóúüñ _-]+$/.test(key) ? key : "";
}

/**
 * Sanea los cambios de memoria que propone el modelo.
 *
 * @param {*} raw campo `memory` de la respuesta.
 * @return {{upsert: Object<string, string>, remove: string[]}} cambios.
 */
function normalizeMemoryChanges(raw) {
  const upsert = {};
  if (Array.isArray(raw?.upsert)) {
    for (const item of raw.upsert) {
      if (Object.keys(upsert).length === MAX_MEMORY_CHANGES) break;
      const key = cleanMemoryKey(item?.key);
      const value = typeof item?.value === "string" ?
        item.value.trim().slice(0, MAX_MEMORY_VALUE_CHARS) :
        "";
      if (key && value) upsert[key] = value;
    }
  }
  const remove = Array.isArray(raw?.remove) ?
    [...new Set(raw.remove.map(cleanMemoryKey).filter(Boolean))] :
    [];
  return {upsert, remove};
}

/**
 * Aplica los cambios a la memoria actual respetando el tope: las altas que no
 * caben se descartan (y se cuentan), las correcciones de datos ya conocidos
 * siempre entran. Primero se borra y después se añade, para que corregir una
 * clave no la pierda.
 *
 * @param {Object<string, string>} facts memoria actual.
 * @param {{upsert: Object<string, string>, remove: string[]}} changes cambios.
 * @return {{facts: Object<string, string>, dropped: number}} resultado.
 */
function applyMemoryChanges(facts, changes) {
  const next = {...(facts ?? {})};
  for (const key of changes.remove) delete next[key];
  let dropped = 0;
  for (const [key, value] of Object.entries(changes.upsert)) {
    const known = Object.prototype.hasOwnProperty.call(next, key);
    if (!known && Object.keys(next).length >= MAX_MEMORY_FACTS) {
      dropped++;
      continue;
    }
    next[key] = value;
  }
  return {facts: next, dropped};
}

/**
 * Resúmenes recientes que se inyectan al empezar la siguiente conversación.
 *
 * @param {{endedAtMs: number, summary: string}[]} recent los que había.
 * @param {{endedAtMs: number, summary: string}} latest el de esta.
 * @return {{endedAtMs: number, summary: string}[]} los 3 más recientes.
 */
function pushRecentSummary(recent, latest) {
  return [latest, ...(recent ?? [])]
      .sort((a, b) => b.endedAtMs - a.endedAtMs)
      .slice(0, RECENT_SUMMARIES);
}

/**
 * Límite inferior de `endedAt` para lo que aún está dentro del plazo.
 *
 * @param {number} nowMs hora del servidor.
 * @param {number} retentionDays plazo vigente.
 * @return {number} milisegundos: lo que terminó antes se borra.
 */
function retentionCutoffMs(nowMs, retentionDays) {
  return nowMs - retentionDays * DAY_MS;
}

module.exports = {
  DAY_MS,
  COLLECTIONS,
  MEMORY_PROFILE_DOC,
  RETENTION_DAYS_STEPS,
  DEFAULT_RETENTION_DAYS,
  nearestStep,
  effectiveRetentionDays,
  expireAtMs,
  graceDeadlineMs,
  frozenExpireAtMs,
  parseConsentRequest,
  MIN_ELDER_TURNS_FOR_ANALYSIS,
  ANALYSIS_PROMPT_VERSION,
  SENTIMENTS,
  SIGNALS,
  ANALYSIS_SYSTEM_PROMPT,
  ANALYSIS_RESPONSE_SCHEMA,
  parseCloseRequest,
  buildTranscript,
  buildAnalysisInput,
  normalizeAnalysis,
  normalizeMemoryChanges,
  applyMemoryChanges,
  pushRecentSummary,
  retentionCutoffMs,
  MAX_MEMORY_FACTS,
};
