import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, setDoc, Timestamp} from 'firebase/firestore';

if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8787' ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9099') {
  throw new Error('The dedicated local Auth and Firestore emulators are required.');
}

const projectId = 'demo-goodfood-chef';
const authUrl = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
const email = 'admin@local.test';
const password = 'AdminLocal123!';
const headers = {'Content-Type': 'application/json'};
const credentials = JSON.stringify({email, password, returnSecureToken: true});
let response = await fetch(authUrl + '/accounts:signUp?key=demo-api-key', {
  method: 'POST', headers, body: credentials,
});
if (!response.ok) {
  response = await fetch(authUrl + '/accounts:signInWithPassword?key=demo-api-key', {
    method: 'POST', headers, body: credentials,
  });
}
const account = await response.json();
if (!response.ok || !account.localId) throw new Error('Could not create the local admin account.');

const claim = await fetch(authUrl + '/projects/' + projectId + '/accounts:update', {
  method: 'POST',
  headers: {...headers, Authorization: 'Bearer owner'},
  body: JSON.stringify({localId: account.localId, customAttributes: JSON.stringify({admin: true})}),
});
if (!claim.ok) throw new Error('Could not set the local admin claim.');

const environment = await initializeTestEnvironment({
  projectId,
  firestore: {host: '127.0.0.1', port: 8787},
});
try {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users', account.localId), {
      name: 'Local Admin', email, role: 'Admin', status: 'Active', start_date: Timestamp.now(),
    });
  });
  console.log('Emulator admin credentials:', email, password);
} finally {
  await environment.cleanup();
}

