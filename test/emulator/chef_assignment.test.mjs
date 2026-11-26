import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {before, after, beforeEach, test} from 'node:test';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {collection, doc, getDoc, getDocs, onSnapshot, query, runTransaction,
  serverTimestamp, setDoc, Timestamp, updateDoc, where} from 'firebase/firestore';

// Deliberately refuse to run against a production project or endpoint.
const projectId = 'demo-goodfood-chef';
if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8787') {
  throw Error('Start the dedicated local Firestore emulator on 127.0.0.1:8787.');
}
let environment;
const chefA = {uid:'chef-a', name:'Chef A'};
const chefB = {uid:'chef-b', name:'Chef B'};
const database = uid => environment.authenticatedContext(uid).firestore();
const pending = db => query(collection(db, 'orders'), where('status', '==', 'pending'));
const owned = (db, uid) => query(collection(db, 'orders'), where('acceptedByChefId', '==', uid));

async function accept(db, chef, id = 'order') {
  return runTransaction(db, async transaction => {
    const ref = doc(db, 'orders', id);
    const profile = await transaction.get(doc(db, 'users', chef.uid));
    const snapshot = await transaction.get(ref);
    const data = snapshot.data();
    if (!data || data.status !== 'pending' || data.acceptedByChefId != null) {
      throw Error('Order conflict');
    }
    transaction.update(ref, {status:'preparing', acceptedByChefId:chef.uid,
      acceptedByChefName:profile.data().name, acceptedAt:serverTimestamp()});
  });
}
async function markReady(db, chef, id = 'order') {
  return runTransaction(db, async transaction => {
    const ref = doc(db, 'orders', id);
    const snapshot = await transaction.get(ref);
    if (snapshot.data()?.status !== 'preparing' || snapshot.data()?.acceptedByChefId !== chef.uid) {
      throw Error('Not assigned to this chef');
    }
    transaction.update(ref, {status:'ready', readyAt:serverTimestamp()});
  });
}
function waitFor(reference, predicate) {
  let unsubscribe;
  const promise = new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {unsubscribe?.(); reject(Error('Listener timeout'));}, 8000);
    unsubscribe = onSnapshot(reference, snapshot => {
      if (predicate(snapshot)) {clearTimeout(timeout); unsubscribe(); resolve(snapshot);}
    }, error => {clearTimeout(timeout); reject(error);});
  });
  return promise;
}

before(async () => {
  environment = await initializeTestEnvironment({projectId,
    firestore:{host:'127.0.0.1', port:8787,
      rules:readFileSync(new URL('../../firebase/chef_assignment.rules.proposed', import.meta.url), 'utf8')}});
});
after(async () => {await environment?.cleanup();});
beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const chef of [chefA, chefB]) {
      await setDoc(doc(db, 'users', chef.uid), {name:chef.name, role:'Chef', status:'Active'});
    }
    await setDoc(doc(db, 'users', 'inactive'), {name:'Inactive', role:'Chef', status:'Inactive'});
    await setDoc(doc(db, 'orders', 'order'), {disp_id:'TEST-1', status:'pending', table_no:5,
      no_of_guests:2, meals:[], subtotal:20, service_charge:2, total:22,
      created_at:Timestamp.now()});
  });
});

test('both chefs share pending orders; acceptance transfers queues in real time', async () => {
  const a = database(chefA.uid), b = database(chefB.uid);
  assert.equal((await getDocs(pending(a))).size, 1);
  assert.equal((await getDocs(pending(b))).size, 1);
  const removedFromB = waitFor(pending(b), snapshot => snapshot.empty);
  const assignedToA = waitFor(owned(a, chefA.uid), snapshot => snapshot.size === 1);
  await assertSucceeds(accept(a, chefA));
  await Promise.all([removedFromB, assignedToA]);
  const data = (await getDoc(doc(a, 'orders', 'order'))).data();
  assert.equal(data.status, 'preparing');
  assert.equal(data.acceptedByChefId, chefA.uid);
  assert.equal(data.acceptedByChefName, chefA.name);
  assert(data.acceptedAt instanceof Timestamp);
  await assertFails(accept(b, chefB));
  await assertFails(getDocs(owned(b, chefA.uid)));
});

test('concurrent transactions have exactly one winner', async () => {
  const results = await Promise.allSettled([accept(database(chefA.uid), chefA), accept(database(chefB.uid), chefB)]);
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  await environment.withSecurityRulesDisabled(async context => {
    const data = (await getDoc(doc(context.firestore(), 'orders', 'order'))).data();
    assert([chefA.uid, chefB.uid].includes(data.acceptedByChefId));
    assert.equal(data.status, 'preparing');
    assert.equal(data.acceptedByChefName, data.acceptedByChefId === chefA.uid ? chefA.name : chefB.name);
  });
});

test('only the assigned active chef can mark Ready; assignment survives new clients', async () => {
  const a = database(chefA.uid), b = database(chefB.uid);
  await accept(a, chefA);
  // This malicious direct write deliberately bypasses the application checks.
  await assertFails(updateDoc(doc(b, 'orders', 'order'), {status:'ready', readyAt:serverTimestamp()}));
  await assertSucceeds(markReady(database(chefA.uid), chefA));
  const restored = (await getDoc(doc(database(chefA.uid), 'orders', 'order'))).data();
  assert.equal(restored.status, 'ready');
  assert.equal(restored.acceptedByChefId, chefA.uid);
  assert.equal(restored.acceptedByChefName, chefA.name);
  assert(restored.readyAt instanceof Timestamp);
});

test('trusted observer receives Ready on the same order document (not customer authorization)', async () => {
  const a = database(chefA.uid);
  await accept(a, chefA);
  await environment.withSecurityRulesDisabled(async context => {
    const received = waitFor(doc(context.firestore(), 'orders', 'order'), snapshot => snapshot.data()?.status === 'ready');
    await markReady(a, chefA);
    await received;
  });
});

test('customers, inactive chefs, unauthenticated users and forged roles cannot claim', async () => {
  for (const db of [database('customer'), database('inactive'),
    environment.unauthenticatedContext().firestore(),
    environment.authenticatedContext('pretender', {role:'Chef', name:'Chef A'}).firestore()]) {
    await assertFails(updateDoc(doc(db, 'orders', 'order'), {status:'preparing',
      acceptedByChefId:chefA.uid, acceptedByChefName:chefA.name, acceptedAt:serverTimestamp()}));
    await assertFails(getDocs(pending(db)));
  }
  await assertFails(updateDoc(doc(database('customer'), 'users', 'customer'), {role:'Chef', status:'Active'}));
});

test('claim rejects forged identity, display name, timestamps, price changes and skipped workflow', async () => {
  const db = database(chefA.uid);
  const valid = {status:'preparing', acceptedByChefId:chefA.uid,
    acceptedByChefName:chefA.name, acceptedAt:serverTimestamp()};
  for (const change of [
    {...valid, acceptedByChefId:chefB.uid},
    {...valid, acceptedByChefName:'Forged name'},
    {...valid, acceptedAt:Timestamp.fromMillis(1)},
    {...valid, total:0},
    {...valid, status:'ready', readyAt:serverTimestamp()},
    {...valid, status:'pending'},
  ]) await assertFails(updateDoc(doc(db, 'orders', 'order'), change));
});

test('ready transition cannot replace the chef or alter order content', async () => {
  const db = database(chefA.uid);
  await accept(db, chefA);
  for (const change of [
    {status:'ready', readyAt:serverTimestamp(), acceptedByChefId:chefB.uid},
    {status:'ready', readyAt:serverTimestamp(), acceptedByChefName:'Changed'},
    {status:'ready', readyAt:Timestamp.fromMillis(1)},
    {status:'ready', readyAt:serverTimestamp(), meals:[] , total:0},
    {status:'delivered'},
  ]) await assertFails(updateDoc(doc(db, 'orders', 'order'), change));
});

test('revoked chef cannot finish an accepted order', async () => {
  const db = database(chefA.uid);
  await accept(db, chefA);
  await environment.withSecurityRulesDisabled(context =>
    updateDoc(doc(context.firestore(), 'users', chefA.uid), {status:'Inactive'}));
  await assertFails(updateDoc(doc(db, 'orders', 'order'), {status:'ready', readyAt:serverTimestamp()}));
});
