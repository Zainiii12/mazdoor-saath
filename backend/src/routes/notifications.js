// Push notifications via Firebase Cloud Messaging.
// Collections:
//   deviceTokens/{tokenId}  { userId, token, platform, updatedAt }
//   notifications/{notifId} { userId, title, body, data, read, createdAt }
//
// POST /api/notify — send FCM to one or more users (used internally by the
// app/backend, e.g. on invite, accept, progress post, wage entry).
// A copy is also stored in `notifications` so the app has an inbox.

import { Router } from 'express';
import { db, messaging, serverTimestamp } from '../config/firebase.js';
import { requireAuth } from '../middleware/auth.js';
import { ok, fail, ah } from '../utils/http.js';

const router = Router();

const CHUNK_SIZE = 30; // Firestore 'in' query limit

function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

// FCM data payload values must be strings.
function stringifyData(data) {
  const out = {};
  for (const [k, v] of Object.entries(data || {})) {
    out[k] = v === null || v === undefined ? '' : String(v);
  }
  return out;
}

// POST /api/notify — send a push notification to user(s).
router.post(
  '/notify',
  requireAuth,
  ah(async (req, res) => {
    const { userIds, title, body, data } = req.body || {};
    if (!Array.isArray(userIds) || userIds.length === 0) {
      return fail(res, 400, 'userIds must be a non-empty array.');
    }
    if (!title || typeof title !== 'string') {
      return fail(res, 400, 'title is required.');
    }
    if (!body || typeof body !== 'string') {
      return fail(res, 400, 'body is required.');
    }

    const uniqueUserIds = [...new Set(userIds.map(String))];
    const payloadData = stringifyData(data);

    // 1) Store an inbox copy for every recipient.
    const batch = db.batch();
    for (const userId of uniqueUserIds) {
      const ref = db.collection('notifications').doc();
      batch.set(ref, {
        userId,
        title,
        body,
        data: payloadData,
        read: false,
        createdAt: serverTimestamp(),
      });
    }
    await batch.commit();

    // 2) Collect FCM tokens for the recipients.
    const tokens = [];
    const tokenDocs = [];
    for (const ids of chunk(uniqueUserIds, CHUNK_SIZE)) {
      const snap = await db.collection('deviceTokens').where('userId', 'in', ids).get();
      for (const doc of snap.docs) {
        const t = doc.data();
        if (t.token) {
          tokens.push(t.token);
          tokenDocs.push(doc);
        }
      }
    }

    // 3) Send via FCM multicast; prune dead tokens.
    let sent = 0;
    let failed = 0;
    if (tokens.length > 0) {
      const response = await messaging.sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: payloadData,
      });
      sent = response.successCount;
      failed = response.failureCount;

      const deadCodes = new Set([
        'messaging/invalid-registration-token',
        'messaging/registration-token-not-registered',
      ]);
      const prune = db.batch();
      response.responses.forEach((r, i) => {
        if (!r.success && r.error && deadCodes.has(r.error.code)) {
          prune.delete(tokenDocs[i].ref);
        }
      });
      await prune.commit();
    }

    return ok(res, {
      notificationsStored: uniqueUserIds.length,
      tokensTargeted: tokens.length,
      sent,
      failed,
    });
  })
);

// GET /api/users/me/notifications — the caller's notification inbox.
router.get(
  '/users/me/notifications',
  requireAuth,
  ah(async (req, res) => {
    let query = db
      .collection('notifications')
      .where('userId', '==', req.user.uid)
      .orderBy('createdAt', 'desc')
      .limit(50);
    if (req.query.unread === 'true') {
      query = query.where('read', '==', false);
    }
    const snap = await query.get();
    return ok(res, snap.docs.map((d) => ({ id: d.id, ...d.data() })));
  })
);

// PATCH /api/notifications/:id/read — mark one notification as read.
router.patch(
  '/notifications/:id/read',
  requireAuth,
  ah(async (req, res) => {
    const ref = db.collection('notifications').doc(req.params.id);
    const snap = await ref.get();
    if (!snap.exists) return fail(res, 404, 'Notification not found.');
    if (snap.data().userId !== req.user.uid) {
      return fail(res, 403, 'You can only mark your own notifications as read.');
    }
    await ref.update({ read: true });
    const fresh = await ref.get();
    return ok(res, { id: fresh.id, ...fresh.data() });
  })
);

export default router;
