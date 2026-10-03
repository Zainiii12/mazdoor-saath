// Job applications / invitations.
// Collection: applications/{appId}
//   { jobId, mazdoorId, builderId, trade, wageOffer,
//     status: 'invited'|'accepted'|'declined'|'removed',
//     createdAt, updatedAt, respondedAt }
//
// Flow: builder invites a mazdoor (POST /api/jobs/:id/invite) ->
//       mazdoor accepts/declines (POST /api/applications/:id/respond).
// Accepted applications back the team when a job moves to "assigned".

import { Router } from 'express';
import { db, serverTimestamp } from '../config/firebase.js';
import { requireAuth } from '../middleware/auth.js';
import { ok, fail, ah, toNumber } from '../utils/http.js';

const router = Router();

const ACTIVE_STATUSES = ['invited', 'accepted'];

function toAppPayload(doc) {
  return { id: doc.id, ...doc.data() };
}

async function getJobOr404(jobId, res) {
  const snap = await db.collection('jobs').doc(jobId).get();
  if (!snap.exists) {
    fail(res, 404, 'Job not found.');
    return null;
  }
  return { ref: snap.ref, job: snap.data() };
}

// GET /api/applications/:id — a single application/invitation.
// Only the job's builder or the invited mazdoor can view it.
router.get(
  '/applications/:id',
  requireAuth,
  ah(async (req, res) => {
    const ref = db.collection('applications').doc(req.params.id);
    const snap = await ref.get();
    if (!snap.exists) return fail(res, 404, 'Application not found.');
    const app = snap.data();
    if (app.builderId !== req.user.uid && app.mazdoorId !== req.user.uid) {
      return fail(res, 403, 'Only the job owner or the invited mazdoor can view this application.');
    }
    return ok(res, toAppPayload(snap));
  })
);

// POST /api/jobs/:id/invite — builder invites a mazdoor to the job.
router.post(
  '/jobs/:id/invite',
  requireAuth,
  ah(async (req, res) => {
    const found = await getJobOr404(req.params.id, res);
    if (!found) return;
    const { job } = found;
    if (job.builderId !== req.user.uid) {
      return fail(res, 403, 'Only the job owner can invite workers.');
    }
    if (job.status !== 'open') {
      return fail(res, 409, `Invitations are only allowed while the job is open (current: ${job.status}).`);
    }

    const { mazdoorId, trade, wageOffer } = req.body || {};
    if (!mazdoorId || typeof mazdoorId !== 'string') {
      return fail(res, 400, 'mazdoorId is required.');
    }
    if (!trade || typeof trade !== 'string') {
      return fail(res, 400, 'trade is required.');
    }

    const mazdoorSnap = await db.collection('users').doc(mazdoorId).get();
    if (!mazdoorSnap.exists || mazdoorSnap.data().role !== 'mazdoor') {
      return fail(res, 404, 'Mazdoor not found.');
    }

    // No duplicate active invitation/application for the same pair.
    const dup = await db
      .collection('applications')
      .where('jobId', '==', req.params.id)
      .where('mazdoorId', '==', mazdoorId)
      .where('status', 'in', ACTIVE_STATUSES)
      .limit(1)
      .get();
    if (!dup.empty) {
      return fail(res, 409, 'This mazdoor already has an active invitation/application for the job.');
    }

    const doc = {
      jobId: req.params.id,
      mazdoorId,
      builderId: req.user.uid,
      trade,
      wageOffer: wageOffer !== undefined ? toNumber(wageOffer) : null,
      status: 'invited',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      respondedAt: null,
    };
    const ref = await db.collection('applications').add(doc);
    const snap = await ref.get();
    return ok(res, toAppPayload(snap), 201);
  })
);

// POST /api/applications/:id/respond — mazdoor accepts or declines an invitation.
router.post(
  '/applications/:id/respond',
  requireAuth,
  ah(async (req, res) => {
    const { action } = req.body || {};
    if (!['accept', 'decline'].includes(action)) {
      return fail(res, 400, 'action must be "accept" or "decline".');
    }

    const ref = db.collection('applications').doc(req.params.id);
    const snap = await ref.get();
    if (!snap.exists) return fail(res, 404, 'Application not found.');
    const app = snap.data();

    if (app.mazdoorId !== req.user.uid) {
      return fail(res, 403, 'Only the invited mazdoor can respond to this invitation.');
    }
    if (app.status !== 'invited') {
      return fail(res, 409, `Invitation is already ${app.status}.`);
    }

    await ref.update({
      status: action === 'accept' ? 'accepted' : 'declined',
      respondedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    const fresh = await ref.get();
    return ok(res, toAppPayload(fresh));
  })
);

// GET /api/jobs/:id/applications — builder views all applications for a job.
router.get(
  '/jobs/:id/applications',
  requireAuth,
  ah(async (req, res) => {
    const found = await getJobOr404(req.params.id, res);
    if (!found) return;
    if (found.job.builderId !== req.user.uid) {
      return fail(res, 403, 'Only the job owner can view applications.');
    }
    const snap = await db
      .collection('applications')
      .where('jobId', '==', req.params.id)
      .orderBy('createdAt', 'desc')
      .get();
    return ok(res, snap.docs.map(toAppPayload));
  })
);

// GET /api/users/me/applications — mazdoor views their own invitations.
router.get(
  '/users/me/applications',
  requireAuth,
  ah(async (req, res) => {
    const snap = await db
      .collection('applications')
      .where('mazdoorId', '==', req.user.uid)
      .orderBy('createdAt', 'desc')
      .get();
    return ok(res, snap.docs.map(toAppPayload));
  })
);

export default router;
