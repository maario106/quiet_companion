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
  collection, deleteDoc, doc, getDoc, getDocs, limit,
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

  it('NO puede crear el documento de otro', async () => {
    await assertFails(
      setDoc(userRef(INTRUSO, 'victima'), elder({ id: 'victima' })),
    );
  });
});

describe('el familiar vinculado y su mayor', () => {
  it('lee el documento de su mayor (panel: getUser(elderId))', async () => {
    await assertSucceeds(getDoc(userRef(FAMILIAR, ELDER_VINCULADO)));
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

  it('el familiar NO puede cambiar lo que ve', async () => {
    await assertFails(updateDoc(userRef(FAMILIAR, ELDER_VINCULADO), {
      companionSharing: 'full',
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

  it('el mayor NO puede escribir ni borrar un análisis', async () => {
    await assertFails(setDoc(sub(ELDER_VINCULADO, 'conversations', 'c2'), analizada));
    await assertFails(updateDoc(sub(ELDER_VINCULADO, 'conversations', 'c1'), {
      sentiment: 'positive',
    }));
    await assertFails(deleteDoc(sub(ELDER_VINCULADO, 'conversationContents', 'c1')));
  });
});

// ─── HU-6: qué ve el familiar (ADR-0031) ──────────────────────────────────

describe('el familiar ve lo que el mayor elige, y solo con consentimiento', () => {
  const setElder = (fields) => testEnv.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'users', ELDER_VINCULADO), fields);
  });
  const consent = { granted: true, answeredAt: new Date('2026-09-26'), textVersion: 1 };
  const sub = (name, id) => doc(db(FAMILIAR), 'users', ELDER_VINCULADO, name, id);
  const list = (name) =>
    getDocs(collection(db(FAMILIAR), 'users', ELDER_VINCULADO, name));

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const raw = ctx.firestore();
      await setDoc(doc(raw, 'users', ELDER_VINCULADO, 'conversations', 'c1'), {
        endedAt: new Date('2026-09-26'), sentiment: 'neutral', signals: [],
      });
      await setDoc(doc(raw, 'users', ELDER_VINCULADO, 'conversationContents', 'c1'), {
        endedAt: new Date('2026-09-26'), topics: [], summary: 'Charla breve.',
      });
      await setDoc(doc(raw, 'users', ELDER_VINCULADO, 'memory', 'profile'), { facts: {} });
    });
  });

  it('nivel "wellbeing": el ánimo sí, los resúmenes y la memoria no', async () => {
    await setElder({ conversationConsent: consent, companionSharing: 'wellbeing' });
    await assertSucceeds(list('conversations'));
    await assertFails(getDoc(sub('conversationContents', 'c1')));
    await assertFails(list('conversationContents'));
    await assertFails(getDoc(sub('memory', 'profile')));
  });

  it('consentimiento retirado: nada, aunque el nivel fuera "full"', async () => {
    await setElder({
      conversationConsent: { ...consent, granted: false },
      companionSharing: 'full',
    });
    await assertFails(list('conversations'));
    await assertFails(getDoc(sub('conversationContents', 'c1')));
  });
});
