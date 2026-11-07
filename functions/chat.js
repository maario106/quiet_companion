/**
 * Reglas puras del chat en vivo con el mayor (`chatTurn`, ADR-0014).
 *
 * Como `conversation.js`, viven fuera de `index.js` para poder testearlas sin
 * Firestore ni Gemini: el prompt, la memoria que se inyecta y lo que se acepta
 * del cliente.
 */

const {DAY_MS, ROLES, MAX_TURNS, MAX_TURN_CHARS} = require("./conversation");

const MINUTE_MS = 60 * 1000;

/** Desfase horario máximo admitido (UTC±14). */
const MAX_UTC_OFFSET_MINUTES = 14 * 60;

/** Tope del nombre que se guarda: un nombre de verdad queda muy por debajo. */
const MAX_NAME_CHARS = 60;

const GUARDAR_NOMBRE = "guardarNombre";

/**
 * Declaración de la función que el modelo llama al oír el nombre del mayor.
 * "En cuanto lo diga", no "en cuanto lo confirme": con la confirmación como
 * condición, el modelo podía dar por bueno un "Mario" en la conversación sin
 * llegar a guardarlo (ADR-0036).
 */
const GUARDAR_NOMBRE_DECLARATION = {
  name: GUARDAR_NOMBRE,
  description: "Guarda cómo se llama el mayor, o cómo quiere que le llames. " +
    "Llámala en cuanto lo diga, sea cual sea el nombre: solo el de pila, el " +
    "completo o un apodo valen igual. No esperes a que lo confirme ni le " +
    "pidas apellidos. Si más tarde lo corrige o pide que le llames de otra " +
    "forma, vuelve a llamarla con el nombre nuevo.",
  parameters: {
    type: "OBJECT",
    properties: {
      nombre: {
        type: "STRING",
        description: "El nombre tal como lo ha dicho, sin añadir ni quitar " +
          "nada (por ejemplo \"Mario\", \"Mario Rosas\" o \"Lola\").",
      },
    },
    required: ["nombre"],
  },
};

/** Bloquea solo lo de probabilidad alta, como hacía el cliente. */
const CHAT_SAFETY_SETTINGS = [
  "HARM_CATEGORY_HARASSMENT",
  "HARM_CATEGORY_HATE_SPEECH",
  "HARM_CATEGORY_SEXUALLY_EXPLICIT",
  "HARM_CATEGORY_DANGEROUS_CONTENT",
].map((category) => ({category, threshold: "BLOCK_ONLY_HIGH"}));

/**
 * Valida y normaliza la petición de `chatTurn`.
 *
 * @param {*} data `request.data`.
 * @return {object|null} petición normalizada, o null si no es válida.
 */
function parseChatRequest(data) {
  if (typeof data?.message !== "string") return null;
  const message = data.message.trim().slice(0, MAX_TURN_CHARS);
  if (message.length === 0) return null;

  const offset = data?.utcOffsetMinutes;
  if (!Number.isInteger(offset) ||
      Math.abs(offset) > MAX_UTC_OFFSET_MINUTES) {
    return null;
  }

  const raw = data.history ?? [];
  if (!Array.isArray(raw) || raw.length > MAX_TURNS) return null;
  const history = [];
  for (const turn of raw) {
    if (!ROLES.includes(turn?.role) || typeof turn?.text !== "string") {
      return null;
    }
    const text = turn.text.trim().slice(0, MAX_TURN_CHARS);
    if (text.length > 0) history.push({role: turn.role, text});
  }

  return {message, history, utcOffsetMinutes: offset};
}

/**
 * Lo que el asistente recuerda, leído de `memory/profile` como lo leía el
 * cliente (`ElderMemory.fromMapOrNull`): se ignora lo que no tenga forma.
 *
 * @param {object|undefined} data datos del documento.
 * @return {{facts: Object<string, string>,
 *   recent: {endedAtMs: number, summary: string}[]}|null} memoria, o null.
 */
function memoryFromDoc(data) {
  if (data == null) return null;
  const facts = {};
  if (data.facts != null && typeof data.facts === "object") {
    for (const [key, value] of Object.entries(data.facts)) {
      if (typeof value === "string") facts[key] = value;
    }
  }
  const recent = [];
  if (Array.isArray(data.recent)) {
    for (const item of data.recent) {
      if (typeof item?.endedAt?.toMillis === "function" &&
          typeof item?.summary === "string") {
        recent.push({
          endedAtMs: item.endedAt.toMillis(),
          summary: item.summary,
        });
      }
    }
  }
  return {facts, recent};
}

const MONTHS = [
  "enero", "febrero", "marzo", "abril", "mayo", "junio",
  "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
];

/** En el orden de `getUTCDay()`: el 0 es domingo. */
const WEEKDAYS = [
  "domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado",
];

/**
 * Cuándo fue algo, en la hora del teléfono del mayor: "hoy a las 10:05",
 * "ayer a las 18:30", "el lunes", "el 26 de septiembre". Espejo de
 * `relativeSpanish` del cliente; el servidor corre en UTC y por eso recibe el
 * desfase del teléfono.
 *
 * @param {number} dateMs el momento, en milisegundos.
 * @param {number} nowMs ahora, en milisegundos.
 * @param {number} offsetMinutes desfase del teléfono respecto de UTC.
 * @return {string} la fecha relativa.
 */
function relativeSpanish(dateMs, nowMs, offsetMinutes) {
  const date = new Date(dateMs + offsetMinutes * MINUTE_MS);
  const now = new Date(nowMs + offsetMinutes * MINUTE_MS);
  const dayOf = (d) =>
    Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
  const daysAgo = Math.round((dayOf(now) - dayOf(date)) / DAY_MS);
  const pad = (n) => String(n).padStart(2, "0");
  const time = `${pad(date.getUTCHours())}:${pad(date.getUTCMinutes())}`;
  if (daysAgo <= 0) return `hoy a las ${time}`;
  if (daysAgo === 1) return `ayer a las ${time}`;
  if (daysAgo < 7) return `el ${WEEKDAYS[date.getUTCDay()]}`;
  return `el ${date.getUTCDate()} de ${MONTHS[date.getUTCMonth()]}`;
}

/**
 * Lo que el modelo sabe del mayor al empezar el turno (ADR-0032). Vacío si no
 * hay memoria: el bloque se omite, no se dice que no la hay.
 *
 * @param {string|null} name nombre del mayor, si se sabe.
 * @param {object|null} memory memoria normalizada (`memoryFromDoc`).
 * @param {number} nowMs ahora, en milisegundos.
 * @param {number} offsetMinutes desfase del teléfono respecto de UTC.
 * @return {string} el bloque de memoria del prompt.
 */
function memoryContext(name, memory, nowMs, offsetMinutes) {
  const facts = Object.entries(memory?.facts ?? {});
  const recent = memory?.recent ?? [];
  if (facts.length === 0 && recent.length === 0) return "";

  const who = name ?? "la persona con la que hablas";
  let block = "";
  if (facts.length > 0) {
    block += `Lo que sabes de ${who}:\n`;
    for (const [key, value] of facts) block += `- ${key}: ${value}\n`;
    block += "\n";
  }
  if (recent.length > 0) {
    block += "De vuestras últimas conversaciones:\n";
    for (const item of recent) {
      const when = relativeSpanish(item.endedAtMs, nowMs, offsetMinutes);
      block += `- ${when}: ${item.summary}\n`;
    }
    block += "\n";
  }
  return block +
    "Usa esto con naturalidad y solo cuando venga a cuento. No lo recites, " +
    "no digas que tienes notas y no preguntes lo que ya sabes.\n\n";
}

/**
 * Instrucción de sistema del chat. El nombre y la memoria se leen en cada
 * turno: un nombre nuevo vale desde el turno siguiente y, al retirar el
 * consentimiento, la memoria deja de inyectarse en el acto.
 *
 * @param {*} rawName campo `name` del documento del mayor.
 * @param {object|null} memory memoria, o null sin consentimiento.
 * @param {number} nowMs ahora, en milisegundos.
 * @param {number} offsetMinutes desfase del teléfono respecto de UTC.
 * @return {string} la instrucción de sistema.
 */
function buildChatSystemPrompt(rawName, memory, nowMs, offsetMinutes) {
  const name = typeof rawName === "string" && rawName.trim().length > 0 ?
    rawName.trim() :
    null;
  const nameContext = name ?
    `Ya conoces el nombre del mayor: se llama ${name}. ` +
      "Salúdale por su nombre y NO vuelvas a preguntárselo. " +
      "Si te pide que le llames de otra forma, llama a la función " +
      `\`${GUARDAR_NOMBRE}\` con el nombre nuevo.` :
    "Aún no sabes el nombre del mayor. " +
      "Pregúntaselo de forma natural en los primeros turnos de la " +
      "conversación. En cuanto diga cualquier nombre, aunque sea solo el de " +
      `pila, llama en ese mismo turno a la función \`${GUARDAR_NOMBRE}\` ` +
      "con ese nombre, sin pedirle que lo confirme ni que te dé los " +
      "apellidos. Le oyes a través de un reconocedor de voz que a veces se " +
      "come palabras: si su respuesta no trae ningún nombre, pídele con " +
      "naturalidad que te lo repita.";

  return "Eres un acompañante virtual diseñado específicamente para " +
    "conversar con personas mayores y combatir la soledad. Tu objetivo " +
    "principal es hacer compañía, escuchar activamente, y ser muy " +
    "respetuoso y cálido.\n\n" +
    `${nameContext}\n\n` +
    memoryContext(name, memory, nowMs, offsetMinutes) +
    "REGLAS:\n" +
    "1. Respuestas MUY breves (máximo 2 o 3 frases). Van a ser leídas por " +
    "voz.\n" +
    "2. Termina siempre con una pregunta sencilla para mantener la " +
    "conversación.\n" +
    "3. Actúa como un oyente humano empático. No digas que eres una IA.\n" +
    "4. Si el usuario menciona problemas de salud, dile amablemente que lo " +
    "consulte con su familia o médico.\n" +
    "5. Si habla de hacerse daño, de no querer vivir o de que sería mejor no " +
    "estar, responde con calma y cariño, no le quites importancia y anímale " +
    "a hablarlo ahora con alguien de confianza. Recuérdale que puede llamar " +
    "gratis al 024, a cualquier hora, y al 112 si está en peligro.";
}

/**
 * Historial y mensaje nuevo en el formato de Gemini.
 *
 * @param {{role: string, text: string}[]} history turnos validados.
 * @param {string} message lo que acaba de decir el mayor.
 * @return {object[]} `contents` de la petición.
 */
function chatContents(history, message) {
  return [
    ...history.map((turn) => ({
      role: turn.role === "elder" ? "user" : "model",
      parts: [{text: turn.text}],
    })),
    {role: "user", parts: [{text: message}]},
  ];
}

/**
 * Texto de una respuesta del modelo, sin las partes de razonamiento.
 *
 * @param {object|null} content `candidates[0].content` de la respuesta.
 * @return {string|null} el texto, o null si no trae ninguno.
 */
function replyTextOf(content) {
  const text = (content?.parts ?? [])
      .filter((part) => typeof part.text === "string" && part.thought !== true)
      .map((part) => part.text)
      .join("")
      .trim();
  return text.length > 0 ? text : null;
}

/**
 * Llamada a `guardarNombre` en una respuesta del modelo. Si hay varias, vale
 * el último nombre utilizable, como en el cliente.
 *
 * @param {object|null} content `candidates[0].content` de la respuesta.
 * @return {{name: string|null}|null} null si el modelo no la llamó; si la
 *   llamó, el nombre limpio, o null si no traía uno utilizable.
 */
function nameCallOf(content) {
  const calls = (content?.parts ?? [])
      .map((part) => part.functionCall)
      .filter((call) => call?.name === GUARDAR_NOMBRE);
  if (calls.length === 0) return null;
  let name = null;
  for (const call of calls) {
    const raw = call.args?.nombre;
    if (typeof raw !== "string") continue;
    const clean = raw.trim().replace(/\s+/g, " ");
    if (clean.length > 0 && clean.length <= MAX_NAME_CHARS) name = clean;
  }
  return {name};
}

/**
 * Respuesta a `guardarNombre`. Se contesta SIEMPRE, también si no se guardó
 * nada: una llamada sin su respuesta deja la conversación a medias para el
 * modelo.
 *
 * @param {string|null} savedName nombre guardado, o null.
 * @return {object} contenido con la respuesta de la función.
 */
function nameResponseContent(savedName) {
  return {
    role: "user",
    parts: [{
      functionResponse: {
        name: GUARDAR_NOMBRE,
        response: savedName ?
          {guardado: true, nombre: savedName} :
          {guardado: false, motivo: "No se ha guardado ningún nombre."},
      },
    }],
  };
}

module.exports = {
  GUARDAR_NOMBRE_DECLARATION,
  CHAT_SAFETY_SETTINGS,
  MAX_NAME_CHARS,
  parseChatRequest,
  memoryFromDoc,
  relativeSpanish,
  memoryContext,
  buildChatSystemPrompt,
  chatContents,
  replyTextOf,
  nameCallOf,
  nameResponseContent,
};
