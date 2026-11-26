import {readFileSync} from 'node:fs';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, setDoc, Timestamp} from 'firebase/firestore';

if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8787' ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9099') {
  throw Error('This fixture command requires the dedicated local Auth and Firestore emulators.');
}
const projectId = 'demo-goodfood-chef';
const password = 'ChefLocal123!'; // Local demo accounts only, never production.
const fixtures = [
  {email:'chef-a@local.test', name:'Chef A'},
  {email:'chef-b@local.test', name:'Chef B'},
];
const environment = await initializeTestEnvironment({projectId,
  firestore:{host:'127.0.0.1',port:8787,
    rules:readFileSync(new URL('../../firebase/customer_chef.rules.proposed',import.meta.url),'utf8')}});
try {
  const accounts = [];
  for (const fixture of fixtures) {
    let response = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-api-key',
      {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:fixture.email,password,returnSecureToken:true})});
    if (!response.ok) response = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-api-key',
      {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:fixture.email,password,returnSecureToken:true})});
    const account = await response.json();
    if (!response.ok || !account.localId) throw Error('Could not prepare local chef account.');
    accounts.push({...fixture, uid:account.localId});
  }
  await environment.withSecurityRulesDisabled(async context => {
    const store = context.firestore();
    for (const account of accounts) {
      await setDoc(doc(store,'users',account.uid), {name:account.name,email:account.email,
        role:'Chef',status:'Active',start_date:Timestamp.now()});
    }
    await setDoc(doc(store,'meals','chef-emulator-meal'), {name:'Emulator Test Meal',description:'Local test fixture',
      category:'main_course',price:10,imageUrl:'',isAvailable:true,nameLower:'emulator test meal'});
    for (const id of process.argv.includes('--profiles-only') ? [] : ['workflow','concurrency']) {
      await setDoc(doc(store,'orders',id), {disp_id:`EMU-${id.toUpperCase()}`,table_no:5,no_of_guests:2,
        meals:[{meal_id:'chef-emulator-meal',meal_name:'Emulator Test Meal',meal_image:'',quantity:2,unit_price:10}],
        status:'pending',subtotal:20,service_charge:0,total:20,created_at:Timestamp.now()});
    }
  });
  console.log(process.argv.includes('--profiles-only')
    ? 'Local demo only: seeded two Auth chefs, their users profiles and a meal. No orders created.'
    : 'Local demo only: seeded two Auth chefs, their users profiles, a meal and two pending orders.');
  console.log('Accounts: chef-a@local.test and chef-b@local.test; password: ChefLocal123!');
  if (!process.argv.includes('--profiles-only')) {
    console.log('Orders were created by a test administrator, not by an authorized guest customer.');
  }
} finally {
  await environment.cleanup();
}
