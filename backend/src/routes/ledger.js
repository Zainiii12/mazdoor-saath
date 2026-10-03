// Digital wage ledger per job.
// Collection: wageLedger/{entryId}
//   { jobId, mazdoorId, date (YYYY-MM-DD), daysWorked, dailyWage,
//     advance, deduction, gross (= daysWorked * dailyWage),
//     net (= gross - advance - deduction),
//     paid: bool, paidAt, note, createdBy, createdAt }
//
// GET returns entries plus per-worker totals and job totals.

import { Router } from 'express';
import { db, serverTimestamp } from '../config/firebase.js';
import { requireAuth } from '../middleware/auth.js';
import { ok, fail, ah, toNumber, isDateString } from '../utils/http.js';

const router = Router();

function toEntryPayload(doc) {
  return { id: doc.id, ...doc.data() };
}

// Owner-only for writes; owner or assigned worker for reads.
async function getJobWithAccess(jobId, uid, res, { write = false } = {}) {
  const snap = await db.collection('jobs').doc(jobId).get();
  if (!snap.exists) {
    fail(res, 404, 'Job not found.');
    return null;
  }
  const job = snap.data();
  const isOwner = job.builderId === uid;
  const isWorker = (job.assignedTeamIds || []).includes(uid);
  if (write && !isOwner) {
    fail(res, 403, 'Only the job owner can modify the wage ledger.');
    return null;
  }
  if (!isOwner && !isWorker) {
    fail(res, 403, 'Only the job owner or assigned workers can view the wage ledger.');
    return null;
  }
  return { job };
}

// POST /api/jobs/:id/ledger — record a wage entry (builder only).
router.post(
  '/jobs/:id/ledger',
  requireAuth,
  ah(async (req, res) => {
    const access = await getJobWithAccess(req.params.id, req.user.uid, res, { write: true });
    if (!access) return;

    const { mazdoorId, date, daysWorked, dailyWage, advance, deduction, paid, note } = req.body || {};
    if (!mazdoorId || typeof mazdoorId !== 'string') {
      return fail(res, 400, 'mazdoorId is required.');
    }
    if (!isDateString(date)) {
      return fail(res, 400, 'date is required as YYYY-MM-DD.');
    }
    const days = toNumber(daysWorked);
    const wage = toNumber(dailyWage);
    if (days === null || days <= 0) return fail(res, 400, 'daysWorked must be a positive number.');
    if (wage === null || wage < 0) return fail(res, 400, 'dailyWage must be a non-negative number.');
    const adv = advance === undefined ? 0 : toNumber(advance);
    const ded = deduction === undefined ? 0 : toNumber(deduction);
    if (adv === null || adv < 0) return fail(res, 400, 'advance must be a non-negative number.');
    if (ded === null || ded < 0) return fail(res, 400, 'deduction must be a non-negative number.');

    const gross = days * wage;
    const net = gross - adv - ded;
    const isPaid = paid === true;

    const doc = {
      jobId: req.params.id,
      mazdoorId,
      date,
      daysWorked: days,
      dailyWage: wage,
      advance: adv,
      deduction: ded,
      gross,
      net,
      paid: isPaid,
      paidAt: isPaid ? serverTimestamp() : null,
      note: note || '',
      createdBy: req.user.uid,
      createdAt: serverTimestamp(),
    };
    const ref = await db.collection('wageLedger').add(doc);
    const snap = await ref.get();
    return ok(res, toEntryPayload(snap), 201);
  })
);

// GET /api/jobs/:id/ledger — full ledger with per-worker and job totals.
router.get(
  '/jobs/:id/ledger',
  requireAuth,
  ah(async (req, res) => {
    const access = await getJobWithAccess(req.params.id, req.user.uid, res);
    if (!access) return;

    const snap = await db
      .collection('wageLedger')
      .where('jobId', '==', req.params.id)
      .orderBy('date', 'desc')
      .orderBy('createdAt', 'desc')
      .get();
    const entries = snap.docs.map(toEntryPayload);

    const perWorker = {};
    for (const e of entries) {
      const w = (perWorker[e.mazdoorId] = perWorker[e.mazdoorId] || {
        mazdoorId: e.mazdoorId,
        daysWorked: 0,
        gross: 0,
        advance: 0,
        deduction: 0,
        net: 0,
        paidAmount: 0,
        entries: 0,
      });
      w.daysWorked += e.daysWorked || 0;
      w.gross += e.gross || 0;
      w.advance += e.advance || 0;
      w.deduction += e.deduction || 0;
      w.net += e.net || 0;
      if (e.paid) w.paidAmount += e.net || 0;
      w.entries += 1;
    }
    const workers = Object.values(perWorker).map((w) => ({
      ...w,
      balance: w.net - w.paidAmount, // still owed to the worker
    }));

    const totals = workers.reduce(
      (acc, w) => ({
        daysWorked: acc.daysWorked + w.daysWorked,
        gross: acc.gross + w.gross,
        advance: acc.advance + w.advance,
        deduction: acc.deduction + w.deduction,
        net: acc.net + w.net,
        paidAmount: acc.paidAmount + w.paidAmount,
        balance: acc.balance + w.balance,
      }),
      { daysWorked: 0, gross: 0, advance: 0, deduction: 0, net: 0, paidAmount: 0, balance: 0 }
    );

    return ok(res, { jobId: req.params.id, entries, perWorker: workers, totals });
  })
);

// GET /api/ledger/mine — the caller's own ledger entries across all jobs.
// Same entry shape as the per-job GET, newest first.
// NOTE: registered before /ledger/:entryId so "mine" isn't parsed as an id.
router.get(
  '/ledger/mine',
  requireAuth,
  ah(async (req, res) => {
    const snap = await db
      .collection('wageLedger')
      .where('mazdoorId', '==', req.user.uid)
      .orderBy('date', 'desc')
      .orderBy('createdAt', 'desc')
      .get();
    return ok(res, snap.docs.map(toEntryPayload));
  })
);

// PATCH /api/ledger/:entryId — builder marks an entry paid/unpaid.
router.patch(
  '/ledger/:entryId',
  requireAuth,
  ah(async (req, res) => {
    const ref = db.collection('wageLedger').doc(req.params.entryId);
    const snap = await ref.get();
    if (!snap.exists) return fail(res, 404, 'Ledger entry not found.');
    const entry = snap.data();

    const access = await getJobWithAccess(entry.jobId, req.user.uid, res, { write: true });
    if (!access) return;

    const { paid } = req.body || {};
    if (typeof paid !== 'boolean') {
      return fail(res, 400, 'paid must be a boolean.');
    }

    await ref.update({
      paid,
      paidAt: paid ? serverTimestamp() : null,
    });
    const fresh = await ref.get();
    return ok(res, toEntryPayload(fresh));
  })
);

export default router;
