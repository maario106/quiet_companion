/**
 * Tests de las reglas puras de las conversaciones (`conversation.js`).
 *
 *   cd functions && npm test
 */

const {test, describe} = require("node:test");
const assert = require("node:assert/strict");
const {
  DAY_MS,
  DEFAULT_RETENTION_DAYS,
  effectiveRetentionDays,
  expireAtMs,
  graceDeadlineMs,
  frozenExpireAtMs,
  parseConsentRequest,
} = require("./conversation");

describe("effectiveRetentionDays — el servidor pone el tope", () => {
  test("sin ajustes: el plazo por defecto", () => {
    assert.equal(effectiveRetentionDays(undefined), DEFAULT_RETENTION_DAYS);
    assert.equal(effectiveRetentionDays({}), DEFAULT_RETENTION_DAYS);
  });

  test("un peldaño válido se respeta", () => {
    assert.equal(effectiveRetentionDays({retentionDays: 30}), 30);
    assert.equal(effectiveRetentionDays({retentionDays: 180}), 180);
  });

  test("por encima del tope: seis meses, nunca más", () => {
    assert.equal(effectiveRetentionDays({retentionDays: 3650}), 180);
  });

  test("por debajo del mínimo o negativo: un mes", () => {
    assert.equal(effectiveRetentionDays({retentionDays: 1}), 30);
    assert.equal(effectiveRetentionDays({retentionDays: -5}), 30);
  });

  test("valor intermedio: el peldaño más cercano, el bajo en empate", () => {
    assert.equal(effectiveRetentionDays({retentionDays: 70}), 60);
    assert.equal(effectiveRetentionDays({retentionDays: 45}), 30);
  });

  test("basura: el plazo por defecto", () => {
    assert.equal(
        effectiveRetentionDays({retentionDays: "mucho"}),
        DEFAULT_RETENTION_DAYS,
    );
    assert.equal(
        effectiveRetentionDays({retentionDays: NaN}),
        DEFAULT_RETENTION_DAYS,
    );
  });
});

describe("caducidades", () => {
  const t0 = Date.UTC(2026, 8, 26);

  test("expireAt = fin de la conversación + plazo", () => {
    assert.equal(expireAtMs(t0, 90), t0 + 90 * DAY_MS);
  });

  test("periodo de gracia = mitad del plazo (45 días con 90)", () => {
    assert.equal(graceDeadlineMs(t0, 90), t0 + 45 * DAY_MS);
    assert.equal(graceDeadlineMs(t0, 30), t0 + 15 * DAY_MS);
  });

  test("congelar nunca alarga la vida de un dato", () => {
    const deadline = t0 + 45 * DAY_MS;
    assert.equal(frozenExpireAtMs(t0 + 10 * DAY_MS, deadline), t0 + 10 * DAY_MS);
    assert.equal(frozenExpireAtMs(t0 + 80 * DAY_MS, deadline), deadline);
  });

  test("documento sin caducidad (memoria): el fin del periodo de gracia", () => {
    assert.equal(frozenExpireAtMs(null, t0), t0);
  });
});

describe("parseConsentRequest", () => {
  test("respuesta válida", () => {
    assert.deepEqual(
        parseConsentRequest({granted: true, textVersion: 1}),
        {granted: true, textVersion: 1},
    );
    assert.deepEqual(
        parseConsentRequest({granted: false, textVersion: 2}),
        {granted: false, textVersion: 2},
    );
  });

  test("sin decisión explícita no hay consentimiento", () => {
    assert.equal(parseConsentRequest({textVersion: 1}), null);
    assert.equal(parseConsentRequest({granted: "sí", textVersion: 1}), null);
    assert.equal(parseConsentRequest(null), null);
  });

  test("sin versión del texto leído tampoco", () => {
    assert.equal(parseConsentRequest({granted: true}), null);
    assert.equal(parseConsentRequest({granted: true, textVersion: 0}), null);
    assert.equal(parseConsentRequest({granted: true, textVersion: 1.5}), null);
  });
});
