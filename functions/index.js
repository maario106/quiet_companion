/**
 * Cloud Functions de Quiet Companion.
 *
 * Codebase creado para ADR-0018: hasta ahora el proxy de Cloud Functions
 * estaba solo diseñado (ADR-0014, "Propuesta"). Contiene únicamente la
 * síntesis de voz; la clave de Gemini sigue viviendo en el cliente y su
 * migración es trabajo aparte.
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const textToSpeech = require("@google-cloud/text-to-speech");

/**
 * Voz de síntesis. Constante de servidor: el cliente NUNCA envía parámetros
 * de voz (menor superficie de abuso y una sola fuente de verdad del timbre).
 *
 * Chirp 3: HD sigue el patrón `<locale>-Chirp3-HD-<Nombre>`. Elegida
 * `Sulafat` porque es la única del catálogo que Google describe literalmente
 * como *Warm* — el registro que pide un acompañante para personas mayores.
 * Alternativas femeninas del mismo catálogo, por si en la escucha real suena
 * mal para la persona: Vindemiatrix (*Gentle*), Achernar (*Soft*),
 * Despina (*Smooth*), Gacrux (*Mature*), Leda (*Youthful*), Kore (*Firm*).
 *
 * Cambiar de voz = cambiar esta constante y redesplegar. Nada más.
 *
 * Verificación: `npm run list-voices` enumera las voces realmente disponibles
 * en el proyecto (requiere la API de Cloud Text-to-Speech habilitada y ADC).
 */
const VOICE_NAME = "es-ES-Chirp3-HD-Sulafat";
const LANGUAGE_CODE = "es-ES";

/**
 * Ritmo neutro. La preferencia de velocidad del mayor NO se aplica aquí sino
 * en el reproductor del cliente (ADR-0019): así el audio sintetizado es
 * independiente de la preferencia y el cliente sigue sin enviar parámetros de
 * voz. Rango admitido por Chirp 3: HD si algún día se moviera: 0.25 – 2.0.
 */
const SPEAKING_RATE = 1.0;

/**
 * Tope de seguridad por llamada. El troceado por frases lo hace el cliente;
 * esto solo evita que una petición anómala sintetice un texto enorme.
 */
const MAX_TEXT_LENGTH = 900;

// Cliente perezoso a nivel de módulo: se reutiliza entre invocaciones de una
// misma instancia caliente y evita pagar el arranque en cada llamada.
let client;

/** @return {textToSpeech.TextToSpeechClient} cliente ADC reutilizable. */
function ttsClient() {
  if (!client) client = new textToSpeech.TextToSpeechClient();
  return client;
}

/**
 * Sintetiza una frase en español con la voz Chirp 3: HD del proyecto.
 *
 * Entrada: `{ text: string }`. Salida: `{ audioContent: string }` (MP3 en
 * base64). Autenticación obligatoria; la anónima es válida (los mayores usan
 * Firebase Auth anónimo).
 */
exports.synthesizeSpeech = onCall(
    {
      region: "europe-west1",
      memory: "256MiB",
      timeoutSeconds: 30,
      // Guardarraíl de coste para un proyecto sin financiación: una fuga o un
      // bucle en el cliente no puede escalar a cientos de instancias.
      maxInstances: 10,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Se requiere sesión iniciada.",
        );
      }

      const text = typeof request.data?.text === "string" ?
        request.data.text.trim() :
        "";

      if (text.length === 0) {
        throw new HttpsError("invalid-argument", "Texto vacío.");
      }
      if (text.length > MAX_TEXT_LENGTH) {
        throw new HttpsError(
            "invalid-argument",
            `Texto demasiado largo (máximo ${MAX_TEXT_LENGTH} caracteres).`,
        );
      }

      try {
        const [response] = await ttsClient().synthesizeSpeech({
          // Texto plano siempre: nunca se envuelve en SSML. La respuesta del
          // LLM es texto libre y un `<` suelto rompería el marcado.
          input: {text},
          voice: {languageCode: LANGUAGE_CODE, name: VOICE_NAME},
          audioConfig: {audioEncoding: "MP3", speakingRate: SPEAKING_RATE},
        });

        return {
          audioContent: Buffer.from(response.audioContent).toString("base64"),
        };
      } catch (error) {
        // El detalle se queda en el log; al cliente solo le llega un error
        // genérico y nunca el texto de entrada (es contenido conversacional).
        logger.error("Fallo de síntesis", {
          voice: VOICE_NAME,
          textLength: text.length,
          error: error.message,
        });
        throw new HttpsError("internal", "No se ha podido sintetizar la voz.");
      }
    },
);
