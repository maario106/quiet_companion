/**
 * Tests de las reglas puras del chat en vivo (`chat.js`).
 *
 *   cd functions && npm test
 */

const {test, describe} = require("node:test");
const assert = require("node:assert/strict");
const {
  MAX_NAME_CHARS,
  parseChatRequest,
  memoryFromDoc,
  relativeSpanish,
  buildChatSystemPrompt,
  chatContents,
  replyTextOf,
  nameCallOf,
} = require("./chat");

describe("parseChatRequest — lo que se acepta del cliente", () => {
  const valid = {
    message: " hola ",
    history: [{role: "elder", text: "buenas"}, {role: "assistant", text: "¡Hola!"}],
    utcOffsetMinutes: 120,
  };

  test("petición válida: mensaje recortado e historial tal cual", () => {
    const input = parseChatRequest(valid);
    assert.equal(input.message, "hola");
    assert.equal(input.history.length, 2);
    assert.equal(input.utcOffsetMinutes, 120);
  });

  test("mensaje vacío, rol desconocido o desfase imposible: se rechaza", () => {
    assert.equal(parseChatRequest({...valid, message: "  "}), null);
    assert.equal(
        parseChatRequest({...valid, history: [{role: "system", text: "x"}]}),
        null);
    assert.equal(parseChatRequest({...valid, utcOffsetMinutes: 24 * 60}), null);
    assert.equal(parseChatRequest({...valid, utcOffsetMinutes: undefined}), null);
  });

  test("historial por encima del tope: se rechaza", () => {
    const history = Array.from({length: 201}, () => ({role: "elder", text: "x"}));
    assert.equal(parseChatRequest({...valid, history}), null);
  });
});

describe("relativeSpanish — en la hora del teléfono, no la del servidor", () => {
  const now = Date.UTC(2026, 9, 30, 9, 0); // viernes 30/10, 10:00 en España

  test("misma hora UTC, otro día según el desfase", () => {
    const lateNight = Date.UTC(2026, 9, 29, 23, 30); // 00:30 del 30 en España
    assert.equal(relativeSpanish(lateNight, now, 60), "hoy a las 00:30");
    assert.equal(relativeSpanish(lateNight, now, 0), "ayer a las 23:30");
  });

  test("dentro de la semana, el día; más atrás, la fecha", () => {
    assert.equal(relativeSpanish(Date.UTC(2026, 9, 26, 10), now, 60), "el lunes");
    assert.equal(
        relativeSpanish(Date.UTC(2026, 8, 26, 10), now, 60),
        "el 26 de septiembre");
  });
});

describe("buildChatSystemPrompt", () => {
  const now = Date.UTC(2026, 9, 30, 9, 0);

  test("con nombre, no lo vuelve a preguntar", () => {
    const prompt = buildChatSystemPrompt("Carmen", null, now, 60);
    assert.match(prompt, /se llama Carmen/);
    assert.doesNotMatch(prompt, /Aún no sabes el nombre/);
  });

  test("sin nombre (o vacío), lo pregunta", () => {
    assert.match(buildChatSystemPrompt("  ", null, now, 60),
        /Aún no sabes el nombre/);
  });

  test("con memoria, la inyecta; sin ella, el bloque no aparece", () => {
    const memory = memoryFromDoc({
      facts: {ciudad: "Sevilla", basura: 3},
      recent: [{
        endedAt: {toMillis: () => Date.UTC(2026, 9, 29, 17, 0)},
        summary: "Habló de su nieto.",
      }],
    });
    const prompt = buildChatSystemPrompt("Carmen", memory, now, 60);
    assert.match(prompt, /Lo que sabes de Carmen:\n- ciudad: Sevilla\n/);
    assert.doesNotMatch(prompt, /basura/);
    assert.match(prompt, /- ayer a las 18:00: Habló de su nieto\./);

    const without = buildChatSystemPrompt("Carmen", null, now, 60);
    assert.doesNotMatch(without, /Lo que sabes de/);
    assert.doesNotMatch(without, /Usa esto con naturalidad/);
  });
});

describe("respuesta del modelo", () => {
  test("el historial alterna usuario y modelo, y acaba en el mensaje", () => {
    const contents = chatContents(
        [{role: "elder", text: "hola"}, {role: "assistant", text: "¡Hola!"}],
        "¿qué tal?");
    assert.deepEqual(contents.map((c) => c.role), ["user", "model", "user"]);
    assert.equal(contents[2].parts[0].text, "¿qué tal?");
  });

  test("el texto no incluye el razonamiento del modelo", () => {
    const content = {parts: [{text: "pienso…", thought: true}, {text: "Hola."}]};
    assert.equal(replyTextOf(content), "Hola.");
    assert.equal(replyTextOf({parts: [{functionCall: {name: "x"}}]}), null);
    assert.equal(replyTextOf(null), null);
  });

  test("guardarNombre: el último nombre utilizable, o ninguno", () => {
    const call = (nombre) => ({functionCall: {name: "guardarNombre", args: {nombre}}});
    assert.deepEqual(nameCallOf({parts: [call(" Lola "), call("")]}), {name: "Lola"});
    assert.deepEqual(
        nameCallOf({parts: [call("x".repeat(MAX_NAME_CHARS + 1))]}),
        {name: null});
    assert.equal(nameCallOf({parts: [{text: "Hola."}]}), null);
  });
});
