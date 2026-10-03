// Worker matching engine.
// GET /api/jobs/:id/matches — ranks available mazdoors for a job.
//
// Score (0-100, weighted):
//   trade match   40% — share of the job's required trades the mazdoor covers
//   rating        25% — ratingAvg / 5 (unrated workers get a neutral 3.0)
//   proximity     25% — closer to the site scores higher (linear falloff to radiusKm)
//   wage fit      10% — dailyWage within the offered wage (full), within 1.5x (half)

import { Router } from 'express';
import { db } from '../config/firebase.js';
import { requireAuth } from '../middleware/auth.js';
import { ok, fail, ah, toNumber } from '../utils/http.js';
import { haversineKm } from '../utils/haversine.js';
import { toPublicProfile } from './users.js';

const router = Router();

const round2 = (n) => Math.round(n * 100) / 100;

router.get(
  '/:id/matches',
  requireAuth,
  ah(async (req, res) => {
    const radiusKm = Math.max(1, toNumber(req.query.radiusKm) ?? 25);
    const limit = Math.min(100, Math.max(1, Math.floor(toNumber(req.query.limit) ?? 20)));

    const jobSnap = await db.collection('jobs').doc(req.params.id).get();
    if (!jobSnap.exists) return fail(res, 404, 'Job not found.');
    const job = jobSnap.data();

    const requiredTrades = (job.tradesRequired || [])
      .map((t) => t.trade)
      .filter(Boolean);
    if (requiredTrades.length === 0) {
      return fail(res, 409, 'Job has no required trades to match against.');
    }
    const site = job.siteLocation || {};
    if (site.lat == null || site.lng == null) {
      return fail(res, 409, 'Job has no site location to match against.');
    }

    const offers = (job.tradesRequired || [])
      .map((t) => toNumber(t.wageOffer))
      .filter((n) => n !== null);
    const avgOffer =
      offers.length > 0 ? offers.reduce((a, b) => a + b, 0) / offers.length : 0;

    // Candidate pool: available mazdoors. (Capped for performance; refine
    // with geo queries if the worker base grows.)
    const pool = await db
      .collection('users')
      .where('role', '==', 'mazdoor')
      .where('availability', '==', true)
      .limit(300)
      .get();

    const matches = [];

    for (const doc of pool.docs) {
      const m = doc.data() || {};
      const loc = m.location;
      if (!loc || loc.lat == null || loc.lng == null) continue;

      const distanceKm = haversineKm(site.lat, site.lng, loc.lat, loc.lng);
      if (distanceKm > radiusKm) continue;

      const workerTrades = m.trades || [];
      const overlap = requiredTrades.filter((t) => workerTrades.includes(t)).length;
      if (overlap === 0) continue; // must cover at least one required trade

      const tradeScore = (overlap / requiredTrades.length) * 40;

      const ratingBase = m.ratingCount > 0 ? m.ratingAvg || 0 : 3.0;
      const ratingScore = (ratingBase / 5) * 25;

      const proximityScore = (1 - distanceKm / radiusKm) * 25;

      let wageFitScore = 0;
      const wage = toNumber(m.dailyWage);
      if (wage === null || wage <= avgOffer) wageFitScore = 10;
      else if (avgOffer > 0 && wage <= avgOffer * 1.5) wageFitScore = 5;

      matches.push({
        mazdoor: toPublicProfile(doc),
        distanceKm: round2(distanceKm),
        score: round2(tradeScore + ratingScore + proximityScore + wageFitScore),
        breakdown: {
          tradeMatch: round2(tradeScore), // /40
          rating: round2(ratingScore), // /25
          proximity: round2(proximityScore), // /25
          wageFit: round2(wageFitScore), // /10
        },
      });
    }

    matches.sort((a, b) => b.score - a.score);

    return ok(res, {
      jobId: req.params.id,
      radiusKm,
      count: matches.length,
      matches: matches.slice(0, limit),
    });
  })
);

export default router;
