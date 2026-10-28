/**
 * Tests de las reglas puras de las conversaciones (`conversation.js`).
 *
 *   cd functions && npm test
 */

const {test, describe} = require("node:test");
const assert = require("node:assert/strict");
const {
  DAY_MS,
  effectiveRetentionDays,
  frozenExpireAtMs,
  parseConsentRequest,
  parseCloseRequest,
  normalizeAnalysis,
  applyMemoryChanges,
  MAX_MEMORY_FACTS,
} = require("./conversation");

describe("effectiveRetentionDays — el servidor pone el tope", () => {
  test("por encima del tope: seis meses, nunca más", () => {
    assert.equal(effectiveRetentionDays({retentionDays: 3650}), 180);
  });

  test("valor intermedio: el peldaño más cercano, el bajo en empate", () => {
    assert.equal(effectiveRetentionDays({retentionDays: 70}), 60);
    assert.equal(effectiveRetentionDays({retentionDays: 45}), 30);
  });
});

describe("caducidades", () => {
  const t0 = Date.UTC(2026, 8, 26);

  test("congelar nunca alarga la vida de un dato", () => {
    const deadline = t0 + 45 * DAY_MS;
    assert.equal(frozenExpireAtMs(t0 + 10 * DAY_MS, deadline), t0 + 10 * DAY_MS);
    assert.equal(frozenExpireAtMs(t0 + 80 * DAY_MS, deadline), deadline);
  });
});

describe("parseConsentRequest", () => {
  test("sin decisión explícita no hay consentimiento", () => {
    assert.equal(parseConsentRequest({textVersion: 1}), null);
    assert.equal(parseConsentRequest({granted: "sí", textVersion: 1}), null);
    assert.equal(parseConsentRequest(null), null);
  });
});

describe("parseCloseRequest — lo que llega del teléfono", () => {
  const now = Date.UTC(2026, 8, 26, 12);
  const base = {
    startedAt: now - 20 * 60 * 1000,
    endedAt: now - 60 * 1000,
    endReason: "inactivity",
    elderTurns: 3,
  };
  const turns = (n) => Array.from({length: n}, (_, i) => [
    {role: "elder", text: `frase ${i}`},
    {role: "assistant", text: `respuesta ${i}`},
  ]).flat();

  test("bajo el umbral, el texto se descarta y queda la actividad", () => {
    const parsed = parseCloseRequest({...base, turns: turns(2)}, now);
    assert.equal(parsed.elderTurns, 2);
    assert.equal(parsed.turns, null);
  });

  test("el número de turnos lo cuenta el servidor, no el cliente", () => {
    const parsed =
      parseCloseRequest({...base, elderTurns: 50, turns: turns(3)}, now);
    assert.equal(parsed.elderTurns, 3);
  });
});

describe("normalizeAnalysis — lo que se escribe no depende de 'casi'", () => {
  const good = {
    sentiment: "negative",
    signals: ["loneliness", "loneliness", "inventada"],
    topics: [" Familia ", "familia", "jardín", "", 7, "a", "b", "c", "d"],
    summary: "  Habló de su nieto y se la notó triste.  ",
  };

  test("filtra señales desconocidas y repetidas", () => {
    assert.deepEqual(normalizeAnalysis(good).signals, ["loneliness"]);
  });

  test("sentimiento fuera de la lista: null, no se inventa", () => {
    assert.equal(normalizeAnalysis({...good, sentiment: "eufórico"}).sentiment, null);
  });
});

describe("memoria del mayor (ADR-0032)", () => {
  test("memoria llena: las altas no caben, las correcciones sí", () => {
    const full = {};
    for (let i = 0; i < MAX_MEMORY_FACTS; i++) full[`dato${i}`] = "x";
    const {facts, dropped} = applyMemoryChanges(
        full,
        {upsert: {nuevo: "y", dato0: "corregido"}, remove: []},
    );
    assert.equal(dropped, 1);
    assert.equal(facts.nuevo, undefined);
    assert.equal(facts.dato0, "corregido");
  });
});
