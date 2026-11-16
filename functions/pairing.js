/** Lógica pura de la vinculación mayor-familiar, separada para testearla. */

/** Longitud del código. Alfabeto A-Z sin O ni I, más 2-9. */
const LINK_CODE_LENGTH = 4;

/**
 * Contacto de emergencia del mayor tras vincular, o null si no se toca.
 * Un contacto puesto a mano por el mayor nunca se sobrescribe.
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

/** Código en mayúsculas y sin espacios, o "" si no es utilizable. */
function normalizeLinkCode(raw) {
  if (typeof raw !== "string") return "";
  const code = raw.trim().toUpperCase();
  return code.length === LINK_CODE_LENGTH ? code : "";
}

module.exports = {LINK_CODE_LENGTH, resolveEmergencyContact, normalizeLinkCode};
