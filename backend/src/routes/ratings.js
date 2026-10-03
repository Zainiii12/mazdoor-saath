// Ratings & reviews between builders and mazdoors.
// Collection: ratings/{ratingId}
//   { jobId, raterId, rateeId, raterRole: 'builder'|'mazdoor',
//     stars (1-5), comment, createdAt }
//
// Rules: only after the job is completed/closed, only between the two
// parties of the job, one rating per (rater, job, ratee). The ratee's
// users/{uid}.ratingAvg / ratingCount are updated transactionally.

import { Router } from 'express';
import { db, serverTimestamp } from '../config/firebase.js';
import { requireAuth } from '../middleware/auth.js';
import { ok, fail, ah, toNumber } from '../utils/http.js';

const router = Router();

function toRatingPayload(doc) {
  return { id: doc.id, ...doc.data() };
}

// POST /api/jobs/:id/ratings — rate the other party after completion.
router.post(
  '/jobs/:id/ratings',
  requireAuth,
  ah(async (req, res) => {
    const jobSnap = await db.collection('jobs').doc(req.params.id).get();
    if (!jobSnap.exists) return fail(res, 404, 'Job not found.');
    const job = jobSnap.data();

    if (!['completed', 'closed'].includes(job.status)) {
      return fail(res, 409, 'Ratings are only allowed after the job is completed.');
    }

    const raterId = req.user.uid;
    const isOwner = job.builderId === raterId;
    const isWorker = (job.assignedTeamIds || []).includes(raterId);
    if (!isOwner && !isWorker) {
      return fail(res, 403, 'Only the job owner or assigned workers can rate.');
    }

    const { rateeId, stars, comment } = req.body || {};
    if (!rateeId || typeof rateeId !== 'string') {
      return fail(res, 400, 'rateeId is required.');
    }
    if (rateeId === raterId) {
      return fail(res, 400, 'You cannot rate yourself.');
    }
    const starCount = toNumber(stars);
    if (starCount === null || !Number.isInteger(starCount) || starCount < 1 || starCount > 5) {
      return fail(res, 400, 'stars must be an integer from 1 to 5.');
    }

    // The two parties may only rate each other: builder <-> assigned worker.
    if (isOwner && !(job.assignedTeamIds || []).includes(rateeId)) {
      return fail(res, 400, 'Builders can only rate workers assigned to this job.');
    }
    if (isWorker && rateeId !== job.builderId) {
      return fail(res, 400, 'Workers can only rate the job owner.');
    }

    // One rating per (rater, job, ratee).
    const dup = await db
      .collection('ratings')
      .where('jobId', '==', req.params.id)
      .where('raterId', '==', raterId)
      .where('rateeId', '==', rateeId)
      .limit(1)
      .get();
    if (!dup.empty) {
      return fail(res, 409, 'You have already rated this person for this job.');
    }

    const ratingRef = db.collection('ratings').doc();
    const userRef = db.collection('users').doc(rateeId);

    await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      const u = userSnap.exists ? userSnap.data() : {};
      const count = u.ratingCount || 0;
      const avg = u.ratingAvg || 0;
      const newCount = count + 1;
      const newAvg = (avg * count + starCount) / newCount;

      tx.set(
        userRef,
        {
          ratingAvg: newAvg,
          ratingCount: newCount,
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      );
      tx.set(ratingRef, {
        jobId: req.params.id,
        raterId,
        rateeId,
        raterRole: isOwner ? 'builder' : 'mazdoor',
        stars: starCount,
        comment: comment || '',
        createdAt: serverTimestamp(),
      });
    });

    const snap = await ratingRef.get();
    return ok(res, toRatingPayload(snap), 201);
  })
);

// GET /api/users/:id/ratings — public list of ratings received by a user.
router.get(
  '/users/:id/ratings',
  ah(async (req, res) => {
    const snap = await db
      .collection('ratings')
      .where('rateeId', '==', req.params.id)
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();
    return ok(res, snap.docs.map(toRatingPayload));
  })
);

export default router;
