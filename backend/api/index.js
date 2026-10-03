// Vercel serverless entry point.
//
// Vercel maps this file to the `/api` serverless function, and vercel.json
// rewrites every request to it. The Express app itself lives in
// `../src/index.js`, which does NOT bind a port when imported (it only
// listens when run directly via `node src/index.js` / `npm start`), so it
// is safe to re-export here for the serverless runtime.
//
// Required Vercel env vars (production):
//   FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY
// Optional: CORS_ORIGIN
// Never set FIRESTORE_FAKE or ALLOW_TEST_AUTH in production.

import app from '../src/index.js';

export default app;
