// Job postings created by builders/homeowners.
// Collection: jobs/{jobId}
//   { builderId, title, description, tradesRequired: [{trade, count, wageOffer}],
//     tradeList: [trade ids] (denormalised for filtering),
//     siteLocation: {lat, lng}, city, startDate, expectedDays,
//     status, assignedTeam: [{mazdoorId, trade, dailyWage}], assignedTeamIds: [uid],
//     createdAt, updatedAt }
//
// Status flow:
//   draft -> open | cancelled
//   open -> assigned | cancelled
//   assigned -> in_progress | cancelled
//   in_progress -> completed | cancelled
//   completed -> closed

import { Router } from 'express';
import { db, serverTimestamp } from '../config/firebase.js';
import { requireAuth, optionalAuth } from '../middleware/auth.js';
import { ok, fail, ah, toNumber, isDateString } from '../utils/http.js';

const router = Router();

const STATUSES = ['draft', 'open', 'assigned', 'in_progress', 'completed', 'closed', 'cancelled'];

const STATUS_FLOW = {
  draft: ['open', 'cancelled'],
  open: ['assigned', 'cancelled'],
  assigned: ['in_progress', 'cancelled'],
  in_progress: ['completed', 'cancelled'],
  completed: ['closed'],
  closed: [],
  cancelled: [],
};

function validateJob(body) {
  const errors = [];
  if (!body || typeof body !== 'object') return ['Request body must be a JSON object.'];

  if (!body.title || typeof body.title !== 'string' || !body.title.trim()) {
    errors.push('title is required.');
  }
  if (!Array.isArray(body.tradesRequired) || body.tradesRequired.length === 0) {
    errors.push('tradesRequired must be a non-empty array.');
  } else {
    body.tradesRequired.forEach((t, i) => {
      if (!t || typeof t.trade !== 'string' || !t.trade.trim()) {
        errors.push(`tradesRequired[${i}].trade is required.`);
      }
      if (toNumber(t.count) === null || toNumber(t.count) < 1) {
        errors.push(`tradesRequired[${i}].count must be a positive number.`);
      }
      if (toNumber(t.wageOffer) === null || toNumber(t.wageOffer) < 0) {
        errors.push(`tradesRequired[${i}].wageOffer must be a non-negative number.`);
      }
    });
  }
  if (toNumber(body.siteLat) === null || toNumber(body.siteLng) === null) {
    errors.push('siteLat and siteLng are required numbers.');
  }
  if (!body.city || typeof body.city !== 'string' || !body.city.trim()) {
    errors.push('city is required.');
  }
  if (body.startDate !== undefined && body.startDate !== null && !isDateString(body.startDate)) {
    errors.push('startDate must be YYYY-MM-DD.');
  }
  if (
    body.expectedDays !== undefined &&
    body.expectedDays !== null &&
    (toNumber(body.expectedDays) === null || toNumber(body.expectedDays) < 1)
  ) {
    errors.push('expectedDays must be a positive number.');
  }
  if (body.status !== undefined && !['draft', 'open'].includes(body.status)) {
    errors.push('New jobs can only start as "draft" or "open".');
  }
  return errors;
}

function toJobPayload(doc) {
  return { id: doc.id, ...doc.data() };
}

// POST /api/jobs — builder creates a job posting.
router.post(
  '/',
  requireAuth,
  ah(async (req, res) => {
    const errors = validateJob(req.body);
    if (errors.length > 0) return fail(res, 400, 'Invalid job.', errors);

    const tradesRequired = req.body.tradesRequired.map((t) => ({
      trade: t.trade.trim(),
      count: toNumber(t.count),
      wageOffer: toNumber(t.wageOffer),
    }));

    const doc = {
      builderId: req.user.uid,
      title: req.body.title.trim(),
      description: req.body.description || '',
      tradesRequired,
      tradeList: [...new Set(tradesRequired.map((t) => t.trade))],
      siteLocation: { lat: toNumber(req.body.siteLat), lng: toNumber(req.body.siteLng) },
      city: req.body.city.trim(),
      startDate: req.body.startDate || null,
      expectedDays: req.body.expectedDays ? toNumber(req.body.expectedDays) : null,
      status: req.body.status || 'open',
      assignedTeam: [],
      assignedTeamIds: [],
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };

    const ref = await db.collection('jobs').add(doc);
    const snap = await ref.get();
    return ok(res, toJobPayload(snap), 201);
  })
);

// GET /api/jobs — list jobs.
// Filters: ?city=&trade=&status=&builderId=
// ?mine=true (requires auth) returns the caller's own jobs: builders see the
// jobs they posted; mazdoors see the jobs they are assigned to.
router.get(
  '/',
  optionalAuth,
  ah(async (req, res) => {
    let query = db.collection('jobs').orderBy('createdAt', 'desc').limit(50);

    if (req.query.city) query = query.where('city', '==', String(req.query.city));
    if (req.query.status) {
      if (!STATUSES.includes(String(req.query.status))) {
        return fail(res, 400, `status must be one of: ${STATUSES.join(', ')}`);
      }
      query = query.where('status', '==', String(req.query.status));
    }
    if (req.query.trade) query = query.where('tradeList', 'array-contains', String(req.query.trade));
    if (req.query.builderId) query = query.where('builderId', '==', String(req.query.builderId));

    if (req.query.mine === 'true') {
      if (!req.user) {
        return fail(res, 401, 'Authentication required for ?mine=true.');
      }
      // Role-aware ownership filter — a single where clause, no composite
      // index needed beyond what the equality/array-contains filters use.
      const userSnap = await db.collection('users').doc(req.user.uid).get();
      const role = userSnap.exists ? userSnap.data().role : null;
      if (role === 'mazdoor') {
        query = query.where('assignedTeamIds', 'array-contains', req.user.uid);
      } else {
        query = query.where('builderId', '==', req.user.uid);
      }
    }

    const snap = await query.get();
    return ok(res, snap.docs.map(toJobPayload));
  })
);

// GET /api/jobs/:id — job detail.
router.get(
  '/:id',
  optionalAuth,
  ah(async (req, res) => {
    const snap = await db.collection('jobs').doc(req.params.id).get();
    if (!snap.exists) return fail(res, 404, 'Job not found.');
    return ok(res, toJobPayload(snap));
  })
);

// PATCH /api/jobs/:id — owner updates fields and/or moves the status forward.
router.patch(
  '/:id',
  requireAuth,
  ah(async (req, res) => {
    const ref = db.collection('jobs').doc(req.params.id);
    const snap = await ref.get();
    if (!snap.exists) return fail(res, 404, 'Job not found.');
    const job = snap.data();
    if (job.builderId !== req.user.uid) {
      return fail(res, 403, 'Only the job owner can update this job.');
    }

    const updates = {};
    const body = req.body || {};

    // --- Field edits (only while the job is still draft/open) ---
    const editable = ['title', 'description', 'city', 'startDate', 'expectedDays'];
    const canEditFields = ['draft', 'open'].includes(job.status);
    for (const key of editable) {
      if (body[key] !== undefined) {
        if (!canEditFields) {
          return fail(res, 409, `Job fields can only be edited while status is draft or open (current: ${job.status}).`);
        }
        updates[key] = body[key];
      }
    }
    if (body.tradesRequired !== undefined) {
      if (!canEditFields) {
        return fail(res, 409, `tradesRequired can only be edited while status is draft or open (current: ${job.status}).`);
      }
      const errors = validateJob({ ...job, ...body, siteLat: job.siteLocation.lat, siteLng: job.siteLocation.lng });
      if (errors.length > 0) return fail(res, 400, 'Invalid tradesRequired.', errors);
      const tradesRequired = body.tradesRequired.map((t) => ({
        trade: String(t.trade).trim(),
        count: toNumber(t.count),
        wageOffer: toNumber(t.wageOffer),
      }));
      updates.tradesRequired = tradesRequired;
      updates.tradeList = [...new Set(tradesRequired.map((t) => t.trade))];
    }
    if (body.siteLat !== undefined || body.siteLng !== undefined) {
      if (!canEditFields) {
        return fail(res, 409, `Location can only be edited while status is draft or open (current: ${job.status}).`);
      }
      const lat = body.siteLat !== undefined ? toNumber(body.siteLat) : job.siteLocation.lat;
      const lng = body.siteLng !== undefined ? toNumber(body.siteLng) : job.siteLocation.lng;
      if (lat === null || lng === null) return fail(res, 400, 'siteLat and siteLng must be numbers.');
      updates.siteLocation = { lat, lng };
    }

    // --- Status transition ---
    if (body.status !== undefined && body.status !== job.status) {
      const allowed = STATUS_FLOW[job.status] || [];
      if (!allowed.includes(body.status)) {
        return fail(
          res,
          409,
          `Invalid status transition: ${job.status} -> ${body.status}. Allowed: ${allowed.join(', ') || 'none'}.`
        );
      }
      updates.status = body.status;

      // Moving to "assigned" requires the hired team, each backed by an
      // accepted application (see POST /api/jobs/:id/invite).
      if (body.status === 'assigned') {
        if (!Array.isArray(body.assignedTeam) || body.assignedTeam.length === 0) {
          return fail(res, 400, 'assignedTeam is required when moving a job to "assigned".');
        }
        const team = [];
        for (const member of body.assignedTeam) {
          if (!member.mazdoorId || !member.trade) {
            return fail(res, 400, 'Each assignedTeam member needs mazdoorId and trade.');
          }
          const appSnap = await db
            .collection('applications')
            .where('jobId', '==', ref.id)
            .where('mazdoorId', '==', member.mazdoorId)
            .where('status', '==', 'accepted')
            .limit(1)
            .get();
          if (appSnap.empty) {
            return fail(res, 409, `Mazdoor ${member.mazdoorId} has no accepted application for this job.`);
          }
          team.push({
            mazdoorId: member.mazdoorId,
            trade: member.trade,
            dailyWage: member.dailyWage !== undefined ? toNumber(member.dailyWage) : null,
          });
        }
        updates.assignedTeam = team;
        updates.assignedTeamIds = team.map((m) => m.mazdoorId);
      }
    }

    if (Object.keys(updates).length === 0) {
      return fail(res, 400, 'Nothing to update.');
    }
    updates.updatedAt = serverTimestamp();
    await ref.update(updates);
    const fresh = await ref.get();
    return ok(res, toJobPayload(fresh));
  })
);

// DELETE /api/jobs/:id — owner can delete only draft jobs.
router.delete(
  '/:id',
  requireAuth,
  ah(async (req, res) => {
    const ref = db.collection('jobs').doc(req.params.id);
    const snap = await ref.get();
    if (!snap.exists) return fail(res, 404, 'Job not found.');
    const job = snap.data();
    if (job.builderId !== req.user.uid) {
      return fail(res, 403, 'Only the job owner can delete this job.');
    }
    if (job.status !== 'draft') {
      return fail(res, 409, `Only draft jobs can be deleted (current: ${job.status}). Cancel it instead.`);
    }
    await ref.delete();
    return ok(res, { deleted: true, id: ref.id });
  })
);

export default router;
