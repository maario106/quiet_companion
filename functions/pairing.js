/**
 * Reglas puras de la vinculación mayor ↔ familiar.
 *
 * Viven fuera de `index.js` para poder testearlas sin Firestore, sin
 * emulador y sin `initializeApp()`: son la parte con criterio de negocio, y
 * la que más caro sale equivocar.
 */

/** Longitud del código. Alfabeto A-Z sin O ni I, más 2-9. */
const LINK_CODE_LENGTH = 4;

/**
 * Decide qué contacto de emergencia queda en el mayor tras vincular.
 *
 * **Un contacto elegido a mano por el mayor nunca se sobrescribe.** La
 * vinculación desnormaliza el teléfono del familiar solo cuando el mayor no
 * había decidido ya, y solo si el familiar tiene teléfono: las cuentas de
 * familiar anteriores a que el registro lo pidiera no lo tienen, y en ese caso
 * el mayor se queda sin contacto impuesto y puede ponerlo desde sus ajustes.
 *
 * @param {object} elderData datos actuales del mayor.
 * @param {object} companionData datos del familiar que vincula.
 * @return {object|null} contacto a escribir, o null si no se toca.
 */
function resolveEmergencyContact(elderData, companionData) {
  const existing = elderData?.emergencyContact;
  if (existing?.source === "manual") return null;

  const phone = companionData?.phoneNumber;
  if (typeof phone !== "string" || phone.length === 0) return null;

  const name = companionData?.name;
  return {
    name: typeof name === "string" && name.length > 0 ? name : "Mi familiar",
    phone,
    source: "companion",
  };
}

/**
 * Normaliza el código tal y como lo teclea el familiar. Mayúsculas y sin
 * espacios: el alfabeto del código es A-Z/2-9, así que escribirlo en minúscula
 * es un error de tecleo, no un código distinto.
 *
 * @param {*} raw lo que llega en `request.data.code`.
 * @return {string} código normalizado, o "" si no es utilizable.
 */
function normalizeLinkCode(raw) {
  if (typeof raw !== "string") return "";
  const code = raw.trim().toUpperCase();
  return code.length === LINK_CODE_LENGTH ? code : "";
}

module.exports = {LINK_CODE_LENGTH, resolveEmergencyContact, normalizeLinkCode};
