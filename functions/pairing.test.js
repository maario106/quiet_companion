/**
 * Tests de las reglas puras de vinculación (`pairing.js`).
 *
 * Sustituyen a `test/features/onboarding/auth_repository_pairing_test.dart`:
 * la lógica se mudó al servidor con `validateAndLink`, y el test se mudó con
 * ella. Los casos son los mismos que había en Dart, más los del código.
 *
 *   cd functions && npm test
 */

const {test, describe} = require("node:test");
const assert = require("node:assert/strict");
const {resolveEmergencyContact, normalizeLinkCode} = require("./pairing");

const familiar = {name: "María", phoneNumber: "+34600111222"};

describe("resolveEmergencyContact — precedencia del contacto", () => {
  test("mayor sin contacto: hereda el del familiar", () => {
    assert.deepEqual(resolveEmergencyContact({}, familiar), {
      name: "María",
      phone: "+34600111222",
      source: "companion",
    });
  });

  test("contacto MANUAL del mayor: no se toca nunca", () => {
    const elder = {
      emergencyContact: {name: "Ana", phone: "+34611000111", source: "manual"},
    };
    assert.equal(resolveEmergencyContact(elder, familiar), null);
  });

  test("contacto previo de otro familiar: sí se reemplaza", () => {
    const elder = {
      emergencyContact: {name: "Luis", phone: "+34622", source: "companion"},
    };
    assert.equal(resolveEmergencyContact(elder, familiar).name, "María");
  });

  test("familiar sin teléfono (cuenta antigua): no se escribe contacto", () => {
    assert.equal(resolveEmergencyContact({}, {name: "María"}), null);
    assert.equal(
        resolveEmergencyContact({}, {name: "María", phoneNumber: ""}), null);
  });

  test("familiar sin nombre: etiqueta genérica, nunca un hueco", () => {
    const contacto = resolveEmergencyContact({}, {phoneNumber: "+34600111222"});
    assert.equal(contacto.name, "Mi familiar");
  });

  test("datos ausentes no revientan", () => {
    assert.equal(resolveEmergencyContact(undefined, undefined), null);
    assert.equal(resolveEmergencyContact(null, {}), null);
  });
});

describe("normalizeLinkCode", () => {
  test("acepta el código tal cual", () => {
    assert.equal(normalizeLinkCode("AB23"), "AB23");
  });

  test("corrige minúsculas y espacios de tecleo", () => {
    assert.equal(normalizeLinkCode(" ab23 "), "AB23");
  });

  test("rechaza longitudes que no son 4", () => {
    assert.equal(normalizeLinkCode("AB2"), "");
    assert.equal(normalizeLinkCode("AB234"), "");
    assert.equal(normalizeLinkCode(""), "");
  });

  test("rechaza lo que no es texto", () => {
    assert.equal(normalizeLinkCode(null), "");
    assert.equal(normalizeLinkCode(1234), "");
    assert.equal(normalizeLinkCode({code: "AB23"}), "");
  });
});
