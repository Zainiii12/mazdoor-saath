// User profiles: builders and mazdoors.
// Collection: users/{uid}
//   { uid, name, phone, role: 'builder'|'mazdoor', trades[], skills[],
//     dailyWage, location: {lat,lng}|null, city, availability,
//     yearsExperience, cnic,
//     ratingAvg, ratingCount, completedJobs, createdAt, updatedAt }

import { Router } from 'express';
import { db, serverTimestamp } from '../config/firebase.js';
import { requireAuth } from '../middleware/auth.js';
import { ok, fail, ah, toNumber } from '../utils/http.js';

const router = Router();

const ROLES = ['builder', 'mazdoor'];

/**
 * Public view of a user document. Sensitive fields (phone, CNIC) are
 * withheld — builders see a worker's contact details only after hiring.
 */
export function toPublicProfile(doc) {
  const u = doc.data() || {};
  return {
    id: doc.id,
    name: u.name || null,
    role: u.role || null,
    trades: u.trades || [],
    skills: u.skills || [],
    dailyWage: u.dailyWage ?? null,
    city: u.city || null,
    location: u.location || null,
    availability: u.availability !== false,
    ratingAvg: u.ratingAvg || 0,
    ratingCount: u.ratingCount || 0,
    completedJobs: u.completedJobs || 0,
    createdAt: u.createdAt || null,
  };
}

function validateProfile(body) {
  const errors = [];
  if (!body || typeof body !== 'object') return ['Request body must be a JSON object.'];

  if (!body.name || typeof body.name !== 'string' || !body.name.trim()) {
    errors.push('name is required.');
  }
  if (!ROLES.includes(body.role)) {
    errors.push('role must be "builder" or "mazdoor".');
  }
  if (body.trades !== undefined && !Array.isArray(body.trades)) {
    errors.push('trades must be an array of trade ids.');
  }
  if (body.skills !== undefined && !Array.isArray(body.skills)) {
    errors.push('skills must be an array of strings.');
  }
  if (body.dailyWage !== undefined && body.dailyWage !== null && toNumber(body.dailyWage) === null) {
    errors.push('dailyWage must be a number.');
  }
  if (
    (body.lat !== undefined && body.lat !== null && toNumber(body.lat) === null) ||
    (body.lng !== undefined && body.lng !== null && toNumber(body.lng) === null)
  ) {
    errors.push('lat and lng must be numbers.');
  }
  if (
    body.yearsExperience !== undefined &&
    body.yearsExperience !== null &&
    (toNumber(body.yearsExperience) === null || toNumber(body.yearsExperience) < 0)
  ) {
    errors.push('yearsExperience must be a non-negative number.');
  }
  return errors;
}

// POST /api/users/profile — create or update the caller's profile.
router.post(
  '/profile',
  requireAuth,
  ah(async (req, res) => {
    const errors = validateProfile(req.body);
    if (errors.length > 0) return fail(res, 400, 'Invalid profile.', errors);

    const uid = req.user.uid;
    const { name, phone, role } = req.body;
    const trades = Array.isArray(req.body.trades) ? req.body.trades : [];
    const skills = Array.isArray(req.body.skills) ? req.body.skills : [];
    const dailyWage =
      req.body.dailyWage === undefined || req.body.dailyWage === null
        ? null
        : toNumber(req.body.dailyWage);
    const lat = toNumber(req.body.lat);
    const lng = toNumber(req.body.lng);
    const yearsExperience =
      req.body.yearsExperience === undefined || req.body.yearsExperience === null
        ? null
        : toNumber(req.body.yearsExperience);

    const ref = db.collection('users').doc(uid);
    const existing = await ref.get();

    const profile = {
      uid,
      name: name.trim(),
      phone: phone || null,
      role,
      trades,
      skills,
      dailyWage,
      location: lat !== null && lng !== null ? { lat, lng } : null,
      city: req.body.city || null,
      availability: req.body.availability !== false,
      yearsExperience,
      cnic: req.body.cnic || null,
      updatedAt: serverTimestamp(),
    };

    if (!existing.exists) {
      // First-time profile: initialise counters.
      profile.createdAt = serverTimestamp();
      profile.ratingAvg = 0;
      profile.ratingCount = 0;
      profile.completedJobs = 0;
    }

    await ref.set(profile, { merge: true });
    const fresh = await ref.get();
    return ok(
      res,
      { id: fresh.id, ...fresh.data() },
      existing.exists ? 200 : 201
    );
  })
);

// GET /api/users/me — the caller's own full profile (includes private fields).
router.get(
  '/me',
  requireAuth,
  ah(async (req, res) => {
    const snap = await db.collection('users').doc(req.user.uid).get();
    if (!snap.exists) return fail(res, 404, 'Profile not found. Create it via POST /api/users/profile.');
    return ok(res, { id: snap.id, ...snap.data() });
  })
);

// POST /api/users/me/device-token — register an FCM token for push notifications.
// Collection: deviceTokens/{tokenId} { userId, token, platform, updatedAt }
router.post(
  '/me/device-token',
  requireAuth,
  ah(async (req, res) => {
    const { token, platform } = req.body || {};
    if (!token || typeof token !== 'string') {
      return fail(res, 400, 'token is required.');
    }
    // FCM tokens can contain characters that are unsafe in doc ids; sanitise.
    const tokenId = token.replace(/[^a-zA-Z0-9\-_:.]/g, '_');
    await db.collection('deviceTokens').doc(tokenId).set(
      {
        userId: req.user.uid,
        token,
        platform: platform || 'unknown',
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    );
    return ok(res, { registered: true });
  })
);

// GET /api/users/:id — public profile + rating summary.
router.get(
  '/:id',
  ah(async (req, res) => {
    const snap = await db.collection('users').doc(req.params.id).get();
    if (!snap.exists) return fail(res, 404, 'User not found.');
    return ok(res, toPublicProfile(snap));
  })
);

export default router;
