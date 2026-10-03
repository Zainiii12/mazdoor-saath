// Firebase Admin SDK initialisation.
// Reads the service-account credentials from environment variables
// (see .env.example) and exports Firestore, Auth and Cloud Messaging.
//
// TEST MODES:
// - FIRESTORE_EMULATOR_HOST=... : use the Firestore emulator (needs Java,
//   and the sandbox must allow the emulator's gRPC/HTTP2 transport).
// - FIRESTORE_FAKE=true : skip the Admin SDK entirely and use the in-memory
//   Firestore stand-in in tests/fake-firestore.js. No Java, emulator or
//   credentials needed. TEST-ONLY — never enable in production.

import 'dotenv/config';

let admin = null;
let db;
let auth;
let messaging;
let serverTimestamp;
let Timestamp;

if (process.env.FIRESTORE_FAKE === 'true') {
  // In-memory Firestore for the integration test suite (see
  // tests/fake-firestore.js). Auth tokens can't be verified here, but the
  // suite authenticates via the ALLOW_TEST_AUTH bypass in middleware/auth.js.
  const fake = await import('../../tests/fake-firestore.js');
  db = fake.createFakeFirestore();
  auth = {
    verifyIdToken: async () => {
      throw new Error('verifyIdToken is unavailable in FIRESTORE_FAKE mode.');
    },
  };
  messaging = {
    sendEachForMulticast: async () => ({ successCount: 0, failureCount: 0, responses: [] }),
  };
  serverTimestamp = fake.fakeServerTimestamp;
  Timestamp = fake.FakeTimestamp;
} else {
  const { default: adminSdk } = await import('firebase-admin');
  admin = adminSdk;

  const getServiceAccount = () => {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    // .env files cannot hold literal newlines, so the key is stored with \n
    // escape sequences which we convert back here.
    const privateKey = process.env.FIREBASE_PRIVATE_KEY
      ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
      : undefined;

    const missing = [
      ['FIREBASE_PROJECT_ID', projectId],
      ['FIREBASE_CLIENT_EMAIL', clientEmail],
      ['FIREBASE_PRIVATE_KEY', privateKey],
    ]
      .filter(([, value]) => !value)
      .map(([key]) => key);

    if (missing.length > 0) {
      throw new Error(
        `Missing required Firebase env vars: ${missing.join(', ')}. ` +
          'Copy .env.example to .env and fill in a service account key.'
      );
    }

    return { projectId, clientEmail, privateKey };
  };

  if (!admin.apps.length) {
    if (process.env.FIRESTORE_EMULATOR_HOST) {
      // Local testing against the Firestore emulator: no service-account
      // credentials are needed. Never set FIRESTORE_EMULATOR_HOST in production.
      admin.initializeApp({
        projectId:
          process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || 'demo-test',
      });
    } else {
      admin.initializeApp({
        credential: admin.credential.cert(getServiceAccount()),
      });
    }
  }

  db = admin.firestore();
  auth = admin.auth();
  messaging = admin.messaging();
  serverTimestamp = admin.firestore.FieldValue.serverTimestamp;
  Timestamp = admin.firestore.Timestamp;
}

export { db, auth, messaging, serverTimestamp, Timestamp };
export default admin;
