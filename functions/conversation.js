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
};
