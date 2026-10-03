// Firebase Authentication middleware.
// Verifies the ID token sent as `Authorization: Bearer <idToken>`
// (the Flutter app gets this via FirebaseAuth.instance.currentUser.getIdToken())
// and attaches the caller's identity as `req.user = { uid, email, name, picture }`.

import { auth } from '../config/firebase.js';
import { fail } from '../utils/http.js';

function extractBearerToken(req) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme && scheme.toLowerCase() === 'bearer' && token) return token;
  return null;
}

// TEST-ONLY auth bypass for integration tests against the Firestore emulator.
// Enabled ONLY when process.env.ALLOW_TEST_AUTH === 'true'.
// Lets tests authenticate as any uid via `Authorization: Test <uid>`
// without a real Firebase ID token. NEVER enable in production.
function extractTestUser(req) {
  if (process.env.ALLOW_TEST_AUTH !== 'true') return null;
  const header = req.headers.authorization || '';
  const [scheme, uid] = header.split(' ');
  if (scheme && scheme.toLowerCase() === 'test' && uid) {
    return { uid, email: null, name: null, picture: null };
  }
  return null;
}

async function attachUser(req) {
  const token = extractBearerToken(req);
  if (!token) return null;
  const decoded = await auth.verifyIdToken(token);
  return {
    uid: decoded.uid,
    email: decoded.email || null,
    name: decoded.name || null,
    picture: decoded.picture || null,
  };
}

/** Reject the request unless a valid Firebase ID token is present. */
export async function requireAuth(req, res, next) {
  try {
    const testUser = extractTestUser(req);
    if (testUser) {
      req.user = testUser;
      return next();
    }
    const user = await attachUser(req);
    if (!user) {
      return fail(
        res,
        401,
        'Authentication required. Send Authorization: Bearer <Firebase ID token>.'
      );
    }
    req.user = user;
    return next();
  } catch (err) {
    return fail(res, 401, 'Invalid or expired Firebase ID token.', err.message);
  }
}

/** Attach `req.user` when a valid token is present, otherwise continue anonymously. */
export async function optionalAuth(req, res, next) {
  try {
    const testUser = extractTestUser(req);
    if (testUser) {
      req.user = testUser;
      return next();
    }
    const user = await attachUser(req);
    if (user) req.user = user;
  } catch {
    // Bad/expired tokens on public routes are simply ignored.
  }
  return next();
}
