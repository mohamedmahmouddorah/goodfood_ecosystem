import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {after, before, beforeEach, test} from 'node:test';
import {initializeTestEnvironment, assertFails} from '@firebase/rules-unit-testing';
import {collection, doc, getDoc, onSnapshot, query, runTransaction, serverTimestamp,
  setDoc, updateDoc, where} from 'firebase/firestore';

if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8787') {
  throw Error('Local emulator required.');
}

let env;
const order = {customerId: 'customer', status: 'pending', total: 22};
const refFor = uid => doc(env.authenticatedContext(uid).firestore(), 'orders', 'order');

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-goodfood-chef',
    firestore: {
      host: '127.0.0.1',
      port: 8787,
      rules: readFileSync(new URL('../../firebase/customer_cancellation.rules.proposed', import.meta.url), 'utf8'),
    },
  });
});
after(async () => env?.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'orders', 'order'), order);
    await setDoc(doc(db, 'orders', 'legacy'), {status: 'pending'});
    await setDoc(doc(db, 'users', 'chef'), {name: 'Chef', role: 'Chef', status: 'Active'});
    await setDoc(doc(db, 'users', 'other-chef'), {name: 'Other chef', role: 'Chef', status: 'Active'});
    await setDoc(doc(db, 'users', 'admin'), {name: 'Admin', role: 'Admin', status: 'Active'});
  });
});

function transition(ref, changes) {
  return runTransaction(ref.firestore, async transaction => {
    const snapshot = await transaction.get(ref);
    if (snapshot.data()?.status !== 'pending') throw Error('Order changed');
    transaction.update(ref, changes);
  });
}

const acceptance = () => ({
  status: 'preparing', acceptedByChefId: 'chef', acceptedByChefName: 'Chef',
  acceptedAt: serverTimestamp(),
});

test('owner can cancel pending order and only its status changes', async () => {
  const ref = refFor('customer');
  await assertFails(updateDoc(ref, {status: 'canceled', total: 1}));
  await transition(ref, {status: 'canceled'});
  assert.deepEqual((await getDoc(ref)).data(), {...order, status: 'canceled'});
});

test('optional reason is validated, visible to the admin and immutable after cancellation', async () => {
  const ref = refFor('customer');
  for (const reason of [null, 42, '', 'x'.repeat(201)]) {
    await assertFails(updateDoc(ref, {status: 'canceled', cancellationReason: reason}));
  }
  const reason = '\u0633'.repeat(200);
  await transition(ref, {status: 'canceled', cancellationReason: reason});
  const admin = env.authenticatedContext('admin', {
    admin: true, firebase: {sign_in_provider: 'password'},
  }).firestore();
  assert.deepEqual((await getDoc(doc(admin, 'orders', 'order'))).data(), {
    ...order, status: 'canceled', cancellationReason: reason,
  });
  await assertFails(updateDoc(ref, {cancellationReason: 'Edited'}));
  await assertFails(updateDoc(ref, {
    payment_data: {payment_method: 'cash', payment_date: serverTimestamp()},
  }));
});

test('both chef listeners drop only the canceled order, and neither chef can accept it', async () => {
  const chefs = ['chef', 'other-chef'].map(refFor);
  const unsubscribes = [];
  try {
    const liveQueues = chefs.map(ref => {
      let initialResolve;
      let removedResolve;
      const initial = new Promise(resolve => { initialResolve = resolve; });
      const removed = new Promise(resolve => { removedResolve = resolve; });
      const pending = query(collection(ref.firestore, 'orders'), where('status', '==', 'pending'));
      unsubscribes.push(onSnapshot(pending, snapshot => {
        const ids = snapshot.docs.map(doc => doc.id);
        if (ids.includes('order')) initialResolve(ids);
        else removedResolve(ids);
      }));
      return {initial, removed};
    });
    for (const queue of liveQueues) assert.deepEqual(await queue.initial, ['legacy', 'order']);
    await transition(refFor('customer'), {status: 'canceled'});
    for (const queue of liveQueues) assert.deepEqual(await queue.removed, ['legacy']);
    for (const ref of chefs) {
      const uid = ref === chefs[0] ? 'chef' : 'other-chef';
      const changes = {...acceptance(), acceptedByChefId: uid,
        acceptedByChefName: uid === 'chef' ? 'Chef' : 'Other chef'};
      await assertFails(updateDoc(ref, changes));
    }
  } finally {
    unsubscribes.forEach(unsubscribe => unsubscribe());
  }
});

test('acceptance and pending assignment both prevent cancellation', async () => {
  await transition(refFor('chef'), acceptance());
  await assertFails(updateDoc(refFor('customer'), {status: 'canceled'}));
  await env.withSecurityRulesDisabled(context =>
    updateDoc(doc(context.firestore(), 'orders', 'order'), {status: 'pending'}));
  await assertFails(updateDoc(refFor('customer'), {status: 'canceled'}));
});

test('other customers and ownerless legacy documents cannot be canceled', async () => {
  await assertFails(updateDoc(refFor('other'), {status: 'canceled'}));
  await assertFails(updateDoc(doc(refFor('customer').firestore, 'orders', 'legacy'), {status: 'canceled'}));
});

test('only one of concurrent acceptance and cancellation commits', async () => {
  const customer = refFor('customer');
  const results = await Promise.allSettled([
    transition(customer, {status: 'canceled'}),
    transition(refFor('chef'), acceptance()),
  ]);
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  const data = (await getDoc(customer)).data();
  assert.equal(data.status, results[0].status === 'fulfilled' ? 'canceled' : 'preparing');
  assert.equal(data.acceptedByChefId, data.status === 'preparing' ? 'chef' : undefined);
});
