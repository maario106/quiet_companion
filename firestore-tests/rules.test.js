/**
 * Tests de `firestore.rules`.
 *
 * Cada caso reproduce una operación real del cliente (el fichero y la línea
 * están citados) o un abuso concreto que las reglas deben frenar. Corren
 * contra el emulador, sin nube y sin coste:
 *
 *   cd firestore-tests && npm test
 *
 * El último grupo era, hasta que existió `validateAndLink`, un recordatorio
 * ejecutable de lo que faltaba por cerrar. Ahora comprueba lo contrario: que
 * `/users` no se puede enumerar ni leer a ciegas desde un cliente (RNF-9).
 */

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, deleteField, doc, getDoc, getDocs, limit,
  query, setDoc, updateDoc, where,
} from 'firebase/firestore';

const ELDER_LIBRE = 'elder-libre';       // tiene linkCode, aún sin familiar
const ELDER_VINCULADO = 'elder-vinculado';
const FAMILIAR = 'familiar-1';
const INTRUSO = 'intruso-1';

let testEnv;

/** Documento de mayor con la forma exacta de `UserModel.toMap()`. */
const elder = (over = {}) => ({
  id: ELDER_LIBRE,
  name: 'Carmen',
  role: 'elder',
  autonomy: 'dependent',
  linkCode: 'AB23',
  linkedCompanionId: null,
  linkedElderId: null,
  preferences: { volume: 1.0, speechRate: 0.4, textSizeMultiplier: 1.2 },
  phoneNumber: null,
  ...over,
});

const companion = (over = {}) => ({
  id: FAMILIAR,
  name: 'María',
  role: 'companion',
  autonomy: 'linked',
  linkCode: null,
  linkedCompanionId: null,
  linkedElderId: ELDER_VINCULADO,
  preferences: { volume: 1.0, speechRate: 0.4, textSizeMultiplier: 1.2 },
  phoneNumber: '+34600111222',
  ...over,
});

const db = (uid) =>
  uid === null
    ? testEnv.unauthenticatedContext().firestore()
    : testEnv.authenticatedContext(uid).firestore();

const userRef = (uid, id) => doc(db(uid), 'users', id);

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'quiet-companion-df0af',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => { await testEnv.cleanup(); });

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const raw = ctx.firestore();
    await setDoc(doc(raw, 'users', ELDER_LIBRE), elder());
    await setDoc(doc(raw, 'users', ELDER_VINCULADO), elder({
      id: ELDER_VINCULADO,
      linkCode: null,
      linkedCompanionId: FAMILIAR,
      emergencyContact: {
        name: 'María', phone: '+34600111222', source: 'companion',
      },
    }));
    await setDoc(doc(raw, 'users', FAMILIAR), companion());
  });
});

// ─────────────────────────────────────────────────────────────────────────

describe('el dueño gobierna su documento', () => {
  it('lee su propio documento (getUser / watchUser)', async () => {
    await assertSucceeds(getDoc(userRef(ELDER_LIBRE, ELDER_LIBRE)));
  });

  it('escribe sus preferencias (updatePreferences, ajustes del mayor)', async () => {
    await assertSucceeds(updateDoc(userRef(ELDER_LIBRE, ELDER_LIBRE), {
      preferences: { volume: 0.6, speechRate: 0.4, textSizeMultiplier: 1.6 },
    }));
  });

  it('escribe su contacto de emergencia (updateEmergencyContact)', async () => {
    await assertSucceeds(updateDoc(userRef(ELDER_LIBRE, ELDER_LIBRE), {
      emergencyContact: { name: 'Ana', phone: '+34600999888', source: 'manual' },
    }));
  });

  it('da de alta su documento (saveUser en el onboarding)', async () => {
    await assertSucceeds(
      setDoc(userRef('nuevo-mayor', 'nuevo-mayor'), elder({ id: 'nuevo-mayor' })),
    );
  });

  it('NO puede crear el documento de otro', async () => {
    await assertFails(
      setDoc(userRef(INTRUSO, 'victima'), elder({ id: 'victima' })),
    );
  });

  it('NO puede borrarse: el borrado no es un efecto de la app', async () => {
    await assertFails(deleteDoc(userRef(ELDER_LIBRE, ELDER_LIBRE)));
  });
});

describe('el familiar vinculado y su mayor', () => {
  it('lee el documento de su mayor (panel: getUser(elderId))', async () => {
    await assertSucceeds(getDoc(userRef(FAMILIAR, ELDER_VINCULADO)));
  });

  it('escribe preferencias con un set() del documento entero (saveUser)', async () => {
    // `saveUser` reescribe todo el mapa; solo `preferences` cambia de valor,
    // así que affectedKeys() devuelve una sola clave.
    const completo = elder({
      id: ELDER_VINCULADO,
      linkCode: null,
      linkedCompanionId: FAMILIAR,
      emergencyContact: {
        name: 'María', phone: '+34600111222', source: 'companion',
      },
      preferences: { volume: 0.2, speechRate: 1.0, textSizeMultiplier: 2.0 },
    });
    await assertSucceeds(setDoc(userRef(FAMILIAR, ELDER_VINCULADO), completo));
  });

  it('escribe el nombre del mayor (updateName desde el panel)', async () => {
    await assertSucceeds(
      updateDoc(userRef(FAMILIAR, ELDER_VINCULADO), { name: 'Carmen Rosas' }),
    );
  });

  it('NO puede reescribir el contacto de emergencia de su mayor', async () => {
    await assertFails(updateDoc(userRef(FAMILIAR, ELDER_VINCULADO), {
      emergencyContact: { name: 'X', phone: '+34600000000', source: 'manual' },
    }));
  });

  it('NO puede cambiarle el rol ni la autonomía', async () => {
    await assertFails(
      updateDoc(userRef(FAMILIAR, ELDER_VINCULADO), { role: 'companion' }),
    );
    await assertFails(
      updateDoc(userRef(FAMILIAR, ELDER_VINCULADO), { autonomy: 'independent' }),
    );
  });

  it('NO puede colar un campo extra junto a uno permitido', async () => {
    await assertFails(updateDoc(userRef(FAMILIAR, ELDER_VINCULADO), {
      name: 'Carmen', role: 'companion',
    }));
  });
});

describe('la vinculación ya no se hace desde el cliente', () => {
  // `validateAndLink` escribe con el Admin SDK, que se salta estas reglas.
  // Lo que se comprueba aquí es que NADIE puede replicar esa escritura desde
  // la app, ni siquiera sobre un mayor que todavía tiene código libre.
  it('no se puede reclamar a un mayor con código libre', async () => {
    await assertFails(updateDoc(userRef(INTRUSO, ELDER_LIBRE), {
      linkedCompanionId: INTRUSO,
      autonomy: 'dependent',
      linkCode: deleteField(),
    }));
  });

  it('no se puede reclamar a un mayor ya vinculado', async () => {
    await assertFails(updateDoc(userRef(INTRUSO, ELDER_VINCULADO), {
      linkedCompanionId: INTRUSO,
      autonomy: 'dependent',
      linkCode: deleteField(),
    }));
  });

  it('un familiar no puede robarle el vínculo a otro', async () => {
    await assertFails(updateDoc(userRef(INTRUSO, ELDER_VINCULADO), {
      linkedCompanionId: INTRUSO,
    }));
  });
});

describe('un autenticado cualquiera frente a datos ajenos', () => {
  it('NO lee el documento de un mayor ya vinculado', async () => {
    await assertFails(getDoc(userRef(INTRUSO, ELDER_VINCULADO)));
  });

  it('NO lee el documento de un familiar', async () => {
    await assertFails(getDoc(userRef(INTRUSO, FAMILIAR)));
  });

  it('NO escribe en documentos ajenos', async () => {
    await assertFails(
      updateDoc(userRef(INTRUSO, ELDER_VINCULADO), { name: 'pwned' }),
    );
  });

  it('NO puede volcar la colección entera', async () => {
    await assertFails(getDocs(collection(db(INTRUSO), 'users')));
  });

  it('NO puede paginar con un limit grande', async () => {
    await assertFails(
      getDocs(query(collection(db(INTRUSO), 'users'), limit(50))),
    );
  });
});

describe('sin autenticar no se toca nada', () => {
  it('no lee', async () => {
    await assertFails(getDoc(userRef(null, ELDER_LIBRE)));
  });

  it('no escribe', async () => {
    await assertFails(updateDoc(userRef(null, ELDER_LIBRE), { name: 'x' }));
  });

  it('no consulta', async () => {
    await assertFails(
      getDocs(query(collection(db(null), 'users'), limit(1))),
    );
  });
});

describe('colecciones que no existen: denegadas por defecto', () => {
  it('/pairings', async () => {
    await assertFails(getDoc(doc(db(FAMILIAR), 'pairings', 'AB23')));
  });

  it('/alerts', async () => {
    await assertFails(getDoc(doc(db(FAMILIAR), 'alerts', 'a1')));
  });
});

describe('`/users` no es enumerable desde un cliente (RNF-9)', () => {
  it('la búsqueda por linkCode está denegada, incluso con limit(1)', async () => {
    const q = query(
      collection(db(INTRUSO), 'users'),
      where('linkCode', '==', 'AB23'),
      where('role', '==', 'elder'),
      limit(1),
    );
    await assertFails(getDocs(q));
  });

  it('una consulta limit(1) sin filtro tampoco pasa', async () => {
    await assertFails(
      getDocs(query(collection(db(INTRUSO), 'users'), limit(1))),
    );
  });

  it('el documento de un mayor pendiente de vincular ya no es legible', async () => {
    await assertFails(getDoc(userRef(INTRUSO, ELDER_LIBRE)));
  });

  it('ni siquiera un familiar registrado puede buscar por código', async () => {
    await assertFails(getDocs(query(
      collection(db(FAMILIAR), 'users'),
      where('linkCode', '==', 'AB23'),
      limit(1),
    )));
  });
});

// ─── HU-5/HU-6: consentimiento (ADR-0030) ─────────────────────────────────

describe('el consentimiento solo lo escribe el servidor', () => {
  const consentido = {
    granted: true, answeredAt: new Date('2026-09-26'), textVersion: 1,
  };

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'users', ELDER_VINCULADO), {
        conversationConsent: consentido,
      });
    });
  });

  it('el mayor NO puede escribirse el consentimiento desde el cliente', async () => {
    await assertFails(updateDoc(userRef(ELDER_LIBRE, ELDER_LIBRE), {
      conversationConsent: { ...consentido },
    }));
  });

  it('el mayor NO puede retirárselo ni borrarlo desde el cliente', async () => {
    await assertFails(updateDoc(userRef(ELDER_VINCULADO, ELDER_VINCULADO), {
      'conversationConsent.granted': false,
    }));
    await assertFails(updateDoc(userRef(ELDER_VINCULADO, ELDER_VINCULADO), {
      conversationConsent: deleteField(),
    }));
  });

  it('nadie da de alta un documento con consentimiento de serie', async () => {
    await assertFails(setDoc(
      userRef('nuevo-mayor', 'nuevo-mayor'),
      elder({ id: 'nuevo-mayor', conversationConsent: consentido }),
    ));
  });

  it('el familiar NO puede consentir por su mayor', async () => {
    await assertFails(updateDoc(userRef(FAMILIAR, ELDER_VINCULADO), {
      'conversationConsent.granted': false,
    }));
  });

  it('con el consentimiento puesto, el mayor sigue escribiendo sus ajustes', async () => {
    await assertSucceeds(updateDoc(userRef(ELDER_VINCULADO, ELDER_VINCULADO), {
      preferences: { volume: 0.6, speechRate: 0.4, textSizeMultiplier: 1.6 },
    }));
  });

  it('el mayor elige qué ve su familiar (companionSharing)', async () => {
    await assertSucceeds(updateDoc(userRef(ELDER_VINCULADO, ELDER_VINCULADO), {
      companionSharing: 'wellbeing',
    }));
  });

  it('el familiar NO puede cambiar lo que ve', async () => {
    await assertFails(updateDoc(userRef(FAMILIAR, ELDER_VINCULADO), {
      companionSharing: 'full',
    }));
  });

  it('el panel escribe una sola magnitud (updatePreferenceField, ADR-0027)', async () => {
    await assertSucceeds(updateDoc(userRef(FAMILIAR, ELDER_VINCULADO), {
      'preferences.volume': 0.5,
    }));
  });
});

// ─── HU-5/HU-6: conversaciones analizadas (ADR-0029) ──────────────────────

describe('las conversaciones analizadas las escribe solo el servidor', () => {
  const analizada = {
    endedAt: new Date('2026-09-26'), status: 'analyzed', sentiment: 'neutral',
    signals: [],
  };

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const raw = ctx.firestore();
      await setDoc(doc(raw, 'users', ELDER_VINCULADO, 'conversations', 'c1'), analizada);
      await setDoc(doc(raw, 'users', ELDER_VINCULADO, 'conversationContents', 'c1'), {
        endedAt: new Date('2026-09-26'), topics: ['familia'], summary: 'Habló de su nieto.',
      });
      await setDoc(doc(raw, 'users', ELDER_VINCULADO, 'memory', 'profile'), {
        facts: { ciudad: 'Sevilla' },
      });
    });
  });

  const sub = (uid, name, id) => doc(db(uid), 'users', ELDER_VINCULADO, name, id);

  it('el mayor lee sus conversaciones, contenidos y memoria', async () => {
    await assertSucceeds(getDoc(sub(ELDER_VINCULADO, 'conversations', 'c1')));
    await assertSucceeds(getDoc(sub(ELDER_VINCULADO, 'conversationContents', 'c1')));
    await assertSucceeds(getDoc(sub(ELDER_VINCULADO, 'memory', 'profile')));
    await assertSucceeds(getDocs(
      collection(db(ELDER_VINCULADO), 'users', ELDER_VINCULADO, 'conversations'),
    ));
  });

  it('el mayor NO puede escribir ni borrar un análisis', async () => {
    await assertFails(setDoc(sub(ELDER_VINCULADO, 'conversations', 'c2'), analizada));
    await assertFails(updateDoc(sub(ELDER_VINCULADO, 'conversations', 'c1'), {
      sentiment: 'positive',
    }));
    await assertFails(deleteDoc(sub(ELDER_VINCULADO, 'conversationContents', 'c1')));
  });

  it('un autenticado cualquiera no lee nada', async () => {
    await assertFails(getDoc(sub(INTRUSO, 'conversations', 'c1')));
    await assertFails(getDoc(sub(INTRUSO, 'conversationContents', 'c1')));
    await assertFails(getDoc(sub(INTRUSO, 'memory', 'profile')));
  });
});
