// Daily progress logs: photo + note timeline per job.
// Collection: progressLogs/{logId}
//   { jobId, authorId, authorRole: 'builder'|'mazdoor', date (YYYY-MM-DD),
//     note, photoUrls[], percentComplete (0-100),
//     approved: bool|null, flagged: bool, createdAt }
//
// The builder can approve or flag entries (moderation of the photo log).

import { Router } from 'express';
import { db, serverTimestamp } from '../config/firebase.js';
import { requireAuth } from '../middleware/auth.js';
import { ok, fail, ah, toNumber, isDateString } from '../utils/http.js';

const router = Router();

function toLogPayload(doc) {
  return { id: doc.id, ...doc.data() };
}

// The caller must be the job owner or an assigned worker.
async function getJobForParty(jobId, uid, res) {
  const snap = await db.collection('jobs').doc(jobId).get();
  if (!snap.exists) {
    fail(res, 404, 'Job not found.');
    return null;
  }
  const job = snap.data();
  const isOwner = job.builderId === uid;
  const isWorker = (job.assignedTeamIds || []).includes(uid);
  if (!isOwner && !isWorker) {
    fail(res, 403, 'Only the job owner or assigned workers can access progress logs.');
    return null;
  }
  return { job, isOwner };
}

// POST /api/jobs/:id/progress — post a daily log entry.
router.post(
  '/jobs/:id/progress',
  requireAuth,
  ah(async (req, res) => {
    const party = await getJobForParty(req.params.id, req.user.uid, res);
    if (!party) return;

    const { date, note, photoUrls, percentComplete } = req.body || {};
    if (!isDateString(date)) {
      return fail(res, 400, 'date is required as YYYY-MM-DD.');
    }
    const pct = toNumber(percentComplete);
    if (pct === null || pct < 0 || pct > 100) {
      return fail(res, 400, 'percentComplete must be a number between 0 and 100.');
    }
    if (photoUrls !== undefined && !Array.isArray(photoUrls)) {
      return fail(res, 400, 'photoUrls must be an array of URLs.');
    }

    const doc = {
      jobId: req.params.id,
      authorId: req.user.uid,
      authorRole: party.isOwner ? 'builder' : 'mazdoor',
      date,
      note: note || '',
      photoUrls: photoUrls || [],
      percentComplete: pct,
      approved: null, // pending builder review
      flagged: false,
      createdAt: serverTimestamp(),
    };
    const ref = await db.collection('progressLogs').add(doc);
    const snap = await ref.get();
    return ok(res, toLogPayload(snap), 201);
  })
);

// GET /api/jobs/:id/progress — timeline, newest first.
router.get(
  '/jobs/:id/progress',
  requireAuth,
  ah(async (req, res) => {
    const party = await getJobForParty(req.params.id, req.user.uid, res);
    if (!party) return;

    const snap = await db
      .collection('progressLogs')
      .where('jobId', '==', req.params.id)
      .orderBy('date', 'desc')
      .orderBy('createdAt', 'desc')
      .get();
    return ok(res, snap.docs.map(toLogPayload));
  })
);

// PATCH /api/progress/:logId — builder approves or flags an entry.
router.patch(
  '/progress/:logId',
  requireAuth,
  ah(async (req, res) => {
    const ref = db.collection('progressLogs').doc(req.params.logId);
    const snap = await ref.get();
    if (!snap.exists) return fail(res, 404, 'Progress entry not found.');
    const log = snap.data();

    const jobSnap = await db.collection('jobs').doc(log.jobId).get();
    if (!jobSnap.exists || jobSnap.data().builderId !== req.user.uid) {
      return fail(res, 403, 'Only the job owner can review progress entries.');
    }

    const { approved, flagged } = req.body || {};
    const updates = {};
    if (approved !== undefined) {
      if (typeof approved !== 'boolean' && approved !== null) {
        return fail(res, 400, 'approved must be true, false or null.');
      }
      updates.approved = approved;
    }
    if (flagged !== undefined) {
      if (typeof flagged !== 'boolean') return fail(res, 400, 'flagged must be a boolean.');
      updates.flagged = flagged;
    }
    if (Object.keys(updates).length === 0) {
      return fail(res, 400, 'Nothing to update. Send approved and/or flagged.');
    }

    await ref.update(updates);
    const fresh = await ref.get();
    return ok(res, toLogPayload(fresh));
  })
);

export default router;
