/**
 * Tests de `firestore.rules`.
 *
 * Cada caso reproduce una operación real del cliente (el fichero y la línea
 * están citados) o un abuso concreto que las reglas deben frenar. Corren
 * contra el emulador, sin nube y sin coste:
 *
 *   cd firestore-tests && npm test
 *
 * Los casos marcados HUECO TEMPORAL comprueban que un permiso deliberadamente
 * abierto SIGUE abierto. No son un descuido: son el recordatorio ejecutable de
 * lo que la callable `validateAndLink` tiene que cerrar (RNF-9). Cuando se
 * implemente, estos casos se invierten a `assertFails`.
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

describe('vinculación por código', () => {
  it('reclama a un mayor con código libre poniéndose como familiar', async () => {
    // Mitad de la transacción de linkCompanionToElder que toca al mayor.
    await assertSucceeds(updateDoc(userRef(INTRUSO, ELDER_LIBRE), {
      linkedCompanionId: INTRUSO,
      autonomy: 'dependent',
      linkCode: deleteField(),
    }));
  });

  it('NO puede reclamar a un mayor que ya tiene familiar', async () => {
    await assertFails(updateDoc(userRef(INTRUSO, ELDER_VINCULADO), {
      linkedCompanionId: INTRUSO,
      autonomy: 'dependent',
      linkCode: deleteField(),
    }));
  });

  it('NO puede vincular a un tercero: solo puede reclamarse a sí mismo', async () => {
    await assertFails(updateDoc(userRef(INTRUSO, ELDER_LIBRE), {
      linkedCompanionId: 'otro-familiar',
      autonomy: 'dependent',
      linkCode: deleteField(),
    }));
  });

  it('NO puede aprovechar la vinculación para cambiar otros campos', async () => {
    await assertFails(updateDoc(userRef(INTRUSO, ELDER_LIBRE), {
      linkedCompanionId: INTRUSO,
      autonomy: 'dependent',
      linkCode: deleteField(),
      name: 'Nombre robado',
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

describe('HUECO TEMPORAL — lo que validateAndLink debe cerrar (RNF-9)', () => {
  it('la búsqueda por linkCode con limit(1) está permitida a cualquiera', async () => {
    const q = query(
      collection(db(INTRUSO), 'users'),
      where('linkCode', '==', 'AB23'),
      where('role', '==', 'elder'),
      limit(1),
    );
    await assertSucceeds(getDocs(q));
  });

  it('una consulta limit(1) SIN filtro también pasa: se puede enumerar despacio', async () => {
    await assertSucceeds(
      getDocs(query(collection(db(INTRUSO), 'users'), limit(1))),
    );
  });

  it('el documento de un mayor pendiente de vincular es legible por cualquiera', async () => {
    await assertSucceeds(getDoc(userRef(INTRUSO, ELDER_LIBRE)));
  });
});
