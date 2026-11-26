import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {before, after, beforeEach, test} from 'node:test';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {collection, doc, setDoc, getDoc, getDocs, query, where, updateDoc,
  deleteDoc, serverTimestamp, Timestamp, runTransaction, onSnapshot} from 'firebase/firestore';

if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8787') throw Error('Local emulator required.');
let env;
const db = uid => env.authenticatedContext(uid).firestore();
const order = (uid = 'customer') => ({customerId:uid, disp_id:'GF-TEST', table_no:5,
  no_of_guests:2, client_name:null, meals:[{meal_id:'meal', meal_name:'Meal', meal_image:'', quantity:2, unit_price:10}],
  status:'pending', subtotal:20, service_charge:2, total:22, payment_data:null, created_at:serverTimestamp()});
const owned = store => query(collection(store,'orders'),where('customerId','==','customer'));
const incoming = store => query(collection(store,'orders'),where('status','==','pending'));
async function accept(store, uid) {
  return runTransaction(store,async tx => {
    const ref=doc(store,'orders','order'), snap=await tx.get(ref);
    if (snap.data()?.status !== 'pending' || snap.data()?.acceptedByChefId) throw Error('Conflict');
    tx.update(ref,{status:'preparing',acceptedByChefId:uid,acceptedByChefName:uid,acceptedAt:serverTimestamp()});
  });
}
function ready(store) { return updateDoc(doc(store,'orders','order'),{status:'ready',readyAt:serverTimestamp()}); }
function waitFor(ref,predicate) {
  return new Promise((resolve,reject) => {
    let stop;
    const timeout=setTimeout(()=>{stop?.();reject(Error('Listener timeout'));},10000);
    stop=onSnapshot(ref,s=>{if(predicate(s)){clearTimeout(timeout);stop();resolve(s);}},e=>{clearTimeout(timeout);stop?.();reject(e);});
  });
}
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-goodfood-chef',firestore:{host:'127.0.0.1',port:8787,
  rules:readFileSync(new URL('../../firebase/customer_chef.rules.proposed',import.meta.url),'utf8')}});});
after(async()=>env?.cleanup());
beforeEach(async()=>{
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async c=>{
    for(const uid of ['chef-a','chef-b']) await setDoc(doc(c.firestore(),'users',uid),{name:uid,role:'Chef',status:'Active'});
    await setDoc(doc(c.firestore(),'users','inactive'),{name:'inactive',role:'Chef',status:'Inactive'});
    const legacy=order(); delete legacy.customerId;
    await setDoc(doc(c.firestore(),'orders','legacy'),{...legacy,created_at:Timestamp.now()});
  });
});

test('customer creates own order; other customer and unauthenticated cannot get or list it',async()=>{
  const customer=db('customer'), other=db('other');
  await assertSucceeds(setDoc(doc(customer,'orders','order'),order()));
  assert.equal((await getDocs(owned(customer))).size,1);
  await assertFails(getDocs(owned(other)));
  await assertFails(getDocs(collection(customer,'orders')));
  await assertFails(getDoc(doc(other,'orders','order')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'orders','order')));
  await assertFails(getDoc(doc(customer,'orders','legacy')));
});

test('only active non-anonymous claimed admins can monitor all orders and manage chef directory records', async () => {
  await env.withSecurityRulesDisabled(async context => {
    const store = context.firestore();
    for (const [uid, status] of [['admin', 'Active'], ['inactive-admin', 'Inactive']]) {
      await setDoc(doc(store, 'users', uid), {name: uid, role: 'Admin', status});
    }
  });
  const claimed = (uid, provider = 'password') => env.authenticatedContext(uid, {
    admin: true, firebase: {sign_in_provider: provider},
  }).firestore();
  const admin = claimed('admin');
  const orderRef = doc(admin, 'orders', 'legacy');
  const chefs = collection(admin, 'chefs');
  const chefRef = doc(chefs, 'directory-only');
  await assertSucceeds(getDocs(collection(admin, 'orders')));
  await assertSucceeds(getDoc(orderRef));
  await assertFails(updateDoc(orderRef, {status: 'delivered'}));
  await assertFails(updateDoc(orderRef, {status: 'canceled'}));
  await assertFails(deleteDoc(orderRef));
  await assertSucceeds(setDoc(chefRef, {name: 'Chef', role: 'Chef', status: 'Active'}));
  await assertSucceeds(getDocs(chefs));
  await assertSucceeds(updateDoc(chefRef, {status: 'Inactive'}));
  await assertFails(setDoc(doc(admin, 'users', 'directory-only'), {role: 'Admin'}));
  for (const denied of [
    db('admin'), claimed('inactive-admin'), claimed('chef-a'),
    claimed('admin', 'anonymous'), db('guest'), env.unauthenticatedContext().firestore(),
  ]) {
    await assertFails(getDocs(collection(denied, 'orders')));
    await assertFails(getDocs(collection(denied, 'chefs')));
    await assertFails(updateDoc(doc(denied, 'chefs', 'directory-only'), {status: 'Active'}));
  }
  await assertSucceeds(deleteDoc(chefRef));
});

test('forged owner, preassignment, state, payment and untrusted creation time are rejected',async()=>{
  const customer=db('customer');
  for(const change of [{customerId:'other'},{status:'ready'},{acceptedByChefId:'chef-a'},
    {acceptedByChefName:'Chef'},{acceptedAt:Timestamp.now()},{readyAt:Timestamp.now()},
    {created_at:Timestamp.fromMillis(0)},{payment_data:{payment_method:'cash',payment_date:serverTimestamp()}},
    {total:1},{unknown:true},{meals:[]},{meals:[{meal_id:'broken'}]}]) {
    await assertFails(setDoc(doc(customer,'orders','bad'),{...order(),...change}));
  }
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(),'orders','bad'),order()));
});

test('every bounded item is checked; 5 lines accepted and oversized or malformed final line denied',async()=>{
  const store=db('customer'), sample=order();
  const meals=Array.from({length:5},()=>sample.meals[0]);
  await assertSucceeds(setDoc(doc(store,'orders','five'),{...sample,meals}));
  await assertFails(setDoc(doc(store,'orders','large'),{...sample,meals:[...meals,sample.meals[0]]}));
  await assertFails(setDoc(doc(store,'orders','bad'),{...sample,meals:[...meals.slice(0,4),{...sample.meals[0],quantity:0}]}));
});

test('owner cannot change ownership, content, totals, status or assignment after creation',async()=>{
  const store=db('customer'), ref=doc(store,'orders','order');
  await setDoc(ref,order());
  for(const change of [{customerId:'other'},{status:'preparing'},{meals:[]},{subtotal:1},{service_charge:0},
    {total:1},{table_no:3},{acceptedByChefId:'customer'},{acceptedByChefName:'customer'},
    {acceptedAt:serverTimestamp()},{readyAt:serverTimestamp()}]) await assertFails(updateDoc(ref,change));
  await assertFails(deleteDoc(ref));
  await assertFails(setDoc(doc(store,'users','customer'),{name:'Customer',role:'Chef',status:'Active'}));
});

test('payment selection is owner-only, one-time, server-timed and not a paid flag',async()=>{
  const store=db('customer'), ref=doc(store,'orders','order'); await setDoc(ref,order());
  for(const p of [{payment_method:'bitcoin',payment_date:serverTimestamp()},
    {payment_method:'card',payment_date:Timestamp.fromMillis(0)},
    {payment_method:'card',payment_date:serverTimestamp(),paid:true}]) await assertFails(updateDoc(ref,{payment_data:p}));
  const payment={payment_data:{payment_method:'cash',payment_date:serverTimestamp()}};
  await assertFails(updateDoc(doc(db('other'),'orders','order'),payment));
  await assertFails(updateDoc(doc(db('chef-a'),'orders','order'),payment));
  await assertFails(updateDoc(ref,{...payment,total:1}));
  await accept(db('chef-a'),'chef-a');
  await assertSucceeds(updateDoc(ref,payment));
  await assertFails(updateDoc(ref,payment));
});

test('complete customer to two chefs to Ready lifecycle uses live authorized listeners',async()=>{
  const customer=db('customer'), a=db('chef-a'), b=db('chef-b');
  await setDoc(doc(customer,'orders','order'),order());
  assert.ok((await getDocs(incoming(a))).docs.some(s=>s.id==='order'));
  assert.ok((await getDocs(incoming(b))).docs.some(s=>s.id==='order'));
  const removed=waitFor(incoming(b),s=>s.docs.every(d=>d.id!=='order'));
  const preparing=waitFor(owned(customer),s=>s.docs.some(d=>d.data().status==='preparing'));
  await accept(a,'chef-a'); await Promise.all([removed,preparing]);
  await assertFails(accept(b,'chef-b')); await assertFails(ready(b));
  await assertFails(ready(customer));
  const updated=waitFor(owned(customer),s=>s.docs.some(d=>d.data().status==='ready'));
  await assertSucceeds(ready(a)); await updated;
  const saved=(await getDoc(doc(customer,'orders','order'))).data();
  assert.equal(saved.customerId,'customer'); assert.equal(saved.acceptedByChefId,'chef-a');
  assert.equal(saved.acceptedByChefName,'chef-a'); assert.ok(saved.readyAt instanceof Timestamp);
});

test('two concurrent chefs have exactly one winner; inactive and forged roles cannot claim',async()=>{
  await setDoc(doc(db('customer'),'orders','order'),order());
  await assertFails(accept(db('inactive'),'inactive'));
  await assertFails(accept(db('customer'),'customer'));
  const race=await Promise.allSettled([accept(db('chef-a'),'chef-a'),accept(db('chef-b'),'chef-b')]);
  assert.equal(race.filter(r=>r.status==='fulfilled').length,1);
  const saved=(await getDoc(doc(db('customer'),'orders','order'))).data();
  assert.ok(['chef-a','chef-b'].includes(saved.acceptedByChefId));
});

test('legacy unowned order stays chef-readable and cannot acquire customer ownership',async()=>{
  await assertSucceeds(getDoc(doc(db('chef-a'),'orders','legacy')));
  await assertFails(updateDoc(doc(db('customer'),'orders','legacy'),{customerId:'customer'}));
  assert.equal((await getDocs(owned(db('customer')))).size,0);
});

test('documented production boundary: coherent client prices are not authoritative menu pricing',async()=>{
  // This succeeds deliberately: identity rules are NOT a trusted pricing service.
  const data=order();
  data.meals[0].unit_price=0; data.subtotal=0; data.service_charge=0; data.total=0;
  await assertSucceeds(setDoc(doc(db('customer'),'orders','untrusted-price'),data));
});
