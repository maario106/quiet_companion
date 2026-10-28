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
const {resolveEmergencyContact} = require("./pairing");

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
});
