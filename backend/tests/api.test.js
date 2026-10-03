// Mazdoor Sathi — end-to-end API tests (node:test + supertest).
//
// Two ways to run:
//
//   npm test
//     Uses the in-memory Firestore stand-in (FIRESTORE_FAKE=true, see
//     tests/fake-firestore.js). No Java, emulator or credentials needed.
//     This is the default and works everywhere.
//
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-test \
//     ALLOW_TEST_AUTH=true npm run test:emulator
//     Runs against the real Firestore emulator (see backend/TESTING.md).
//     Needs Java 21+ and a network that allows the emulator's gRPC transport.
//
// Auth is faked per-request via `Authorization: Test <uid>` (see
// src/middleware/auth.js — TEST-ONLY, never enable in production).

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';

import app from '../src/index.js';
import { db } from '../src/config/firebase.js';

const api = request(app);
const T = (uid) => ({ Authorization: `Test ${uid}` });

// Distinct UIDs so test data never collides with seed data.
const BUILDER = 't-builder-1';
const MAZ1 = 't-maz-1'; // Mason, near the job site (Gujrat)
const MAZ2 = 't-maz-2'; // Electrician, far (Lahore)
const MAZ3 = 't-maz-3'; // Mason, exactly at the job site (best match)
const OUTSIDER = 't-outsider';

const JOB_SITE = { lat: 32.5, lng: 74.54 }; // Gujrat

function expectOk(res, status = 200) {
  assert.equal(res.status, status, `expected ${status}, got ${res.status}: ${JSON.stringify(res.body)}`);
  assert.equal(res.body.ok, true);
  return res.body.data;
}

function expectErr(res, status) {
  assert.equal(res.status, status, `expected ${status}, got ${res.status}: ${JSON.stringify(res.body)}`);
  assert.equal(res.body.ok, false);
  assert.ok(res.body.error && res.body.error.message);
  return res.body.error;
}

async function wipe() {
  for (const c of [
    'users',
    'jobs',
    'applications',
    'progressLogs',
    'wageLedger',
    'ratings',
    'notifications',
    'deviceTokens',
  ]) {
    const snap = await db.collection(c).get();
    if (snap.empty) continue;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}

before(async () => {
  await wipe();
});

// ---------------------------------------------------------------------------
// 1. Users
// ---------------------------------------------------------------------------
describe('users', () => {
  it('creates a builder profile (201)', async () => {
    const data = expectOk(
      await api.post('/api/users/profile').set(T(BUILDER)).send({
        name: 'Test Builder',
        role: 'builder',
        phone: '03000000001',
        city: 'Gujrat',
      }),
      201
    );
    assert.equal(data.id, BUILDER);
    assert.equal(data.role, 'builder');
    assert.equal(data.ratingAvg, 0);
    assert.equal(data.ratingCount, 0);
  });

  it('rejects invalid profiles (400)', async () => {
    expectErr(await api.post('/api/users/profile').set(T('t-x')).send({ role: 'builder' }), 400); // no name
    expectErr(await api.post('/api/users/profile').set(T('t-x')).send({ name: 'X', role: 'king' }), 400); // bad role
    expectErr(
      await api.post('/api/users/profile').set(T('t-x')).send({ name: 'X', role: 'mazdoor', yearsExperience: -2 }),
      400
    );
  });

  it('creates mazdoor profiles with trades/location', async () => {
    const m1 = expectOk(
      await api.post('/api/users/profile').set(T(MAZ1)).send({
        name: 'Test Mason',
        role: 'mazdoor',
        phone: '03000000002',
        trades: ['Mason'],
        skills: ['brickwork'],
        dailyWage: 1500,
        lat: 32.4917,
        lng: 74.5311,
        city: 'Gujrat',
        availability: true,
        yearsExperience: 6,
      }),
      201
    );
    assert.deepEqual(m1.trades, ['Mason']);
    assert.deepEqual(m1.location, { lat: 32.4917, lng: 74.5311 });
    assert.equal(m1.yearsExperience, 6);

    expectOk(
      await api.post('/api/users/profile').set(T(MAZ2)).send({
        name: 'Test Electrician',
        role: 'mazdoor',
        trades: ['Electrician'],
        dailyWage: 2000,
        lat: 31.5204,
        lng: 74.3587,
        city: 'Lahore',
        availability: true,
      }),
      201
    );
    expectOk(
      await api.post('/api/users/profile').set(T(MAZ3)).send({
        name: 'Best Mason',
        role: 'mazdoor',
        trades: ['Mason'],
        dailyWage: 1400,
        lat: JOB_SITE.lat,
        lng: JOB_SITE.lng,
        city: 'Gujrat',
        availability: true,
      }),
      201
    );
  });

  it('GET /api/users/me returns own full profile; 401 without token', async () => {
    const me = expectOk(await api.get('/api/users/me').set(T(BUILDER)));
    assert.equal(me.phone, '03000000001'); // private field visible to owner
    expectErr(await api.get('/api/users/me'), 401);
  });

  it('GET /api/users/:id hides phone/cnic', async () => {
    const pub = expectOk(await api.get(`/api/users/${MAZ1}`));
    assert.equal(pub.name, 'Test Mason');
    assert.ok(!('phone' in pub), 'phone must be hidden');
    assert.ok(!('cnic' in pub), 'cnic must be hidden');
    expectErr(await api.get('/api/users/does-not-exist'), 404);
  });

  it('registers a device token; 400 without token', async () => {
    const data = expectOk(
      await api.post('/api/users/me/device-token').set(T(BUILDER)).send({ token: 'fake-fcm-token-1', platform: 'android' })
    );
    assert.equal(data.registered, true);
    expectErr(await api.post('/api/users/me/device-token').set(T(BUILDER)).send({}), 400);
  });
});

// ---------------------------------------------------------------------------
// 2. Jobs
// ---------------------------------------------------------------------------
describe('jobs', () => {
  let jobId;
  const jobBody = {
    title: 'House grey structure',
    description: 'Double-storey grey structure',
    tradesRequired: [
      { trade: 'Mason', count: 2, wageOffer: 1500 },
      { trade: 'Electrician', count: 1, wageOffer: 1800 },
    ],
    siteLat: JOB_SITE.lat,
    siteLng: JOB_SITE.lng,
    city: 'Gujrat',
    startDate: '2026-10-10',
    expectedDays: 20,
  };

  it('creates a multi-trade job (201)', async () => {
    const job = expectOk(await api.post('/api/jobs').set(T(BUILDER)).send(jobBody), 201);
    assert.equal(job.status, 'open');
    assert.equal(job.builderId, BUILDER);
    assert.deepEqual(job.tradeList.sort(), ['Electrician', 'Mason']);
    assert.deepEqual(job.siteLocation, JOB_SITE);
    jobId = job.id;
    assert.ok(jobId);
  });

  it('rejects bad job bodies (400)', async () => {
    expectErr(await api.post('/api/jobs').set(T(BUILDER)).send({ ...jobBody, title: '' }), 400);
    expectErr(await api.post('/api/jobs').set(T(BUILDER)).send({ ...jobBody, tradesRequired: [] }), 400);
    expectErr(await api.post('/api/jobs').set(T(BUILDER)).send({ ...jobBody, city: '' }), 400);
    expectErr(await api.post('/api/jobs').set(T(BUILDER)).send({ ...jobBody, siteLat: 'far' }), 400);
    expectErr(await api.post('/api/jobs').set(T(BUILDER)).send({ ...jobBody, startDate: '10-10-2026' }), 400);
  });

  it('lists/filters jobs', async () => {
    const all = expectOk(await api.get('/api/jobs'));
    assert.ok(all.some((j) => j.id === jobId));

    const byStatus = expectOk(await api.get('/api/jobs?status=open'));
    assert.ok(byStatus.some((j) => j.id === jobId));
    const byCity = expectOk(await api.get('/api/jobs?city=Gujrat'));
    assert.ok(byCity.some((j) => j.id === jobId));
    const byTrade = expectOk(await api.get('/api/jobs?trade=Mason'));
    assert.ok(byTrade.some((j) => j.id === jobId));
    const byBuilder = expectOk(await api.get(`/api/jobs?builderId=${BUILDER}`));
    assert.ok(byBuilder.some((j) => j.id === jobId));
    const noMatch = expectOk(await api.get('/api/jobs?city=Karachi'));
    assert.ok(!noMatch.some((j) => j.id === jobId));
    expectErr(await api.get('/api/jobs?status=bogus'), 400);

    const mine = expectOk(await api.get('/api/jobs?mine=true').set(T(BUILDER)));
    assert.ok(mine.some((j) => j.id === jobId));
    const mineMaz = expectOk(await api.get('/api/jobs?mine=true').set(T(MAZ1)));
    assert.ok(!mineMaz.some((j) => j.id === jobId), 'not assigned yet');
    expectErr(await api.get('/api/jobs?mine=true'), 401);
  });

  it('GET /api/jobs/:id; 404 for unknown', async () => {
    const job = expectOk(await api.get(`/api/jobs/${jobId}`));
    assert.equal(job.title, 'House grey structure');
    expectErr(await api.get('/api/jobs/nope'), 404);
  });

  it('owner can edit fields; others cannot', async () => {
    const updated = expectOk(await api.patch(`/api/jobs/${jobId}`).set(T(BUILDER)).send({ title: 'House grey structure v2' }));
    assert.equal(updated.title, 'House grey structure v2');
    expectErr(await api.patch(`/api/jobs/${jobId}`).set(T(OUTSIDER)).send({ title: 'hijack' }), 403);
    expectErr(await api.patch(`/api/jobs/${jobId}`).send({ title: 'x' }), 401);
  });

  it('rejects illegal status transitions (409)', async () => {
    expectErr(await api.patch(`/api/jobs/${jobId}`).set(T(BUILDER)).send({ status: 'completed' }), 409); // open -> completed illegal
    expectErr(await api.patch(`/api/jobs/${jobId}`).set(T(BUILDER)).send({ status: 'bogus' }), 409);
  });

  it('deletes draft jobs only', async () => {
    const draft = expectOk(await api.post('/api/jobs').set(T(BUILDER)).send({ ...jobBody, title: 'Temp draft', status: 'draft' }), 201);
    assert.equal(draft.status, 'draft');
    const del = expectOk(await api.delete(`/api/jobs/${draft.id}`).set(T(BUILDER)));
    assert.equal(del.deleted, true);
    expectErr(await api.get(`/api/jobs/${draft.id}`), 404);
    expectErr(await api.delete(`/api/jobs/${jobId}`).set(T(BUILDER)), 409); // open job
  });

  it('exposes jobId for later suites', async () => {
    globalThis.__JOB_ID = jobId;
  });
});

// ---------------------------------------------------------------------------
// 3. Matching
// ---------------------------------------------------------------------------
describe('matching', () => {
  let jobId;
  before(() => {
    jobId = globalThis.__JOB_ID;
  });

  it('ranks available mazdoors with score + breakdown', async () => {
    const data = expectOk(await api.get(`/api/jobs/${jobId}/matches`).set(T(BUILDER)));
    assert.equal(data.jobId, jobId);
    assert.equal(data.radiusKm, 25);
    assert.ok(data.count >= 2, `expected >=2 matches, got ${data.count}`);

    const [first, second] = data.matches;
    assert.ok(first.score >= second.score, 'must be ranked desc');
    // MAZ3 sits exactly on the site -> should rank first
    assert.equal(first.mazdoor.id, MAZ3);
    assert.equal(second.mazdoor.id, MAZ1);
    // MAZ2 (Lahore electrician, ~110km away) is outside the radius
    assert.ok(!data.matches.some((m) => m.mazdoor.id === MAZ2));

    for (const m of data.matches) {
      assert.ok(m.score >= 0 && m.score <= 100, 'score in 0..100');
      const b = m.breakdown;
      for (const k of ['tradeMatch', 'rating', 'proximity', 'wageFit']) {
        assert.equal(typeof b[k], 'number', `breakdown.${k} is a number`);
      }
      assert.ok(Math.abs(m.score - (b.tradeMatch + b.rating + b.proximity + b.wageFit)) < 0.02, 'score == sum of breakdown');
      assert.ok(m.distanceKm >= 0);
    }

    // MAZ3: Mason overlapping 1/2 trades -> tradeMatch 20; neutral rating 3.0 -> 15;
    // distance 0 -> proximity 25; wage 1400 <= avg offer 1650 -> wageFit 10
    const b3 = first.breakdown;
    assert.equal(b3.tradeMatch, 20);
    assert.equal(b3.rating, 15);
    assert.equal(b3.proximity, 25);
    assert.equal(b3.wageFit, 10);
    assert.equal(first.score, 70);
  });

  it('respects radiusKm', async () => {
    const data = expectOk(await api.get(`/api/jobs/${jobId}/matches?radiusKm=1`).set(T(BUILDER)));
    // MAZ3 sits exactly on the site (0 km) so it is inside the radius;
    // MAZ1 (~1.2 km away) and MAZ2 (~110 km) are outside it.
    assert.equal(data.count, 1, 'only MAZ3 within 1km');
    assert.equal(data.matches[0].mazdoor.id, MAZ3);
    assert.equal(data.matches[0].distanceKm, 0);
  });

  it('401 without token; 404 for unknown job', async () => {
    expectErr(await api.get(`/api/jobs/${jobId}/matches`), 401);
    expectErr(await api.get('/api/jobs/nope/matches').set(T(BUILDER)), 404);
  });
});

// ---------------------------------------------------------------------------
// 4. Applications + full hire lifecycle
// ---------------------------------------------------------------------------
describe('applications and hire lifecycle', () => {
  let jobId;
  let appId1; // MAZ1 invite
  let appId2; // MAZ2 invite (will decline)
  before(() => {
    jobId = globalThis.__JOB_ID;
  });

  it('builder invites a mazdoor (201)', async () => {
    const app = expectOk(
      await api.post(`/api/jobs/${jobId}/invite`).set(T(BUILDER)).send({ mazdoorId: MAZ1, trade: 'Mason', wageOffer: 1500 }),
      201
    );
    assert.equal(app.status, 'invited');
    assert.equal(app.mazdoorId, MAZ1);
    assert.equal(app.jobId, jobId);
    appId1 = app.id;
  });

  it('rejects duplicate invites (409) and bad invites', async () => {
    expectErr(
      await api.post(`/api/jobs/${jobId}/invite`).set(T(BUILDER)).send({ mazdoorId: MAZ1, trade: 'Mason' }),
      409
    );
    expectErr(await api.post(`/api/jobs/${jobId}/invite`).set(T(BUILDER)).send({ mazdoorId: 'ghost', trade: 'Mason' }), 404);
    expectErr(await api.post(`/api/jobs/${jobId}/invite`).set(T(BUILDER)).send({ trade: 'Mason' }), 400);
    expectErr(await api.post(`/api/jobs/${jobId}/invite`).set(T(OUTSIDER)).send({ mazdoorId: MAZ2, trade: 'Mason' }), 403);
  });

  it('builder lists job applications; mazdoor lists own invites', async () => {
    const list = expectOk(await api.get(`/api/jobs/${jobId}/applications`).set(T(BUILDER)));
    assert.ok(list.some((a) => a.id === appId1));
    expectErr(await api.get(`/api/jobs/${jobId}/applications`).set(T(OUTSIDER)), 403);

    const mine = expectOk(await api.get('/api/users/me/applications').set(T(MAZ1)));
    assert.ok(mine.some((a) => a.id === appId1));
    const none = expectOk(await api.get('/api/users/me/applications').set(T(BUILDER)));
    assert.equal(none.length, 0);
  });

  it('GET /api/applications/:id is party-only', async () => {
    const app = expectOk(await api.get(`/api/applications/${appId1}`).set(T(MAZ1)));
    assert.equal(app.id, appId1);
    expectOk(await api.get(`/api/applications/${appId1}`).set(T(BUILDER)));
    expectErr(await api.get(`/api/applications/${appId1}`).set(T(OUTSIDER)), 403);
    expectErr(await api.get('/api/applications/nope').set(T(BUILDER)), 404);
  });

  it('mazdoor accepts; double-respond is 409', async () => {
    const app = expectOk(await api.post(`/api/applications/${appId1}/respond`).set(T(MAZ1)).send({ action: 'accept' }));
    assert.equal(app.status, 'accepted');
    assert.ok(app.respondedAt);
    expectErr(await api.post(`/api/applications/${appId1}/respond`).set(T(MAZ1)).send({ action: 'accept' }), 409);
    expectErr(await api.post(`/api/applications/${appId1}/respond`).set(T(MAZ1)).send({ action: 'maybe' }), 400);
    expectErr(await api.post(`/api/applications/${appId1}/respond`).set(T(OUTSIDER)).send({ action: 'accept' }), 403);
  });

  it('second mazdoor declines', async () => {
    const app = expectOk(
      await api.post(`/api/jobs/${jobId}/invite`).set(T(BUILDER)).send({ mazdoorId: MAZ2, trade: 'Electrician' }),
      201
    );
    appId2 = app.id;
    const declined = expectOk(await api.post(`/api/applications/${appId2}/respond`).set(T(MAZ2)).send({ action: 'decline' }));
    assert.equal(declined.status, 'declined');
  });

  it('assigning needs accepted applications (409 otherwise)', async () => {
    expectErr(
      await api.patch(`/api/jobs/${jobId}`).set(T(BUILDER)).send({
        status: 'assigned',
        assignedTeam: [{ mazdoorId: MAZ2, trade: 'Electrician', dailyWage: 1800 }], // declined!
      }),
      409
    );
    expectErr(await api.patch(`/api/jobs/${jobId}`).set(T(BUILDER)).send({ status: 'assigned' }), 400); // no team
  });

  it('full lifecycle: assigned -> in_progress -> completed -> closed', async () => {
    let job = expectOk(
      await api.patch(`/api/jobs/${jobId}`).set(T(BUILDER)).send({
        status: 'assigned',
        assignedTeam: [{ mazdoorId: MAZ1, trade: 'Mason', dailyWage: 1500 }],
      })
    );
    assert.equal(job.status, 'assigned');
    assert.deepEqual(job.assignedTeamIds, [MAZ1]);

    // invite on non-open job -> 409
    expectErr(await api.post(`/api/jobs/${jobId}/invite`).set(T(BUILDER)).send({ mazdoorId: MAZ3, trade: 'Mason' }), 409);

    // mazdoor sees it via ?mine=true
    const mine = expectOk(await api.get('/api/jobs?mine=true').set(T(MAZ1)));
    assert.ok(mine.some((j) => j.id === jobId));

    job = expectOk(await api.patch(`/api/jobs/${jobId}`).set(T(BUILDER)).send({ status: 'in_progress' }));
    assert.equal(job.status, 'in_progress');
    expectErr(await api.patch(`/api/jobs/${jobId}`).set(T(BUILDER)).send({ status: 'assigned' }), 409); // no going back

    globalThis.__APP1 = appId1;
  });

  it('progress log: post, validate, timeline, approve', async () => {
    const log = expectOk(
      await api.post(`/api/jobs/${jobId}/progress`).set(T(MAZ1)).send({
        date: '2026-10-05',
        note: 'Ground floor walls done',
        photoUrls: ['https://example.com/p1.jpg'],
        percentComplete: 40,
      }),
      201
    );
    assert.equal(log.authorRole, 'mazdoor');
    assert.equal(log.approved, null);

    expectErr(
      await api.post(`/api/jobs/${jobId}/progress`).set(T(MAZ1)).send({ date: '05-10-2026', percentComplete: 10 }),
      400
    );
    expectErr(
      await api.post(`/api/jobs/${jobId}/progress`).set(T(MAZ1)).send({ date: '2026-10-05', percentComplete: 150 }),
      400
    );
    expectErr(
      await api.post(`/api/jobs/${jobId}/progress`).set(T(OUTSIDER)).send({ date: '2026-10-05', percentComplete: 10 }),
      403
    );

    const timeline = expectOk(await api.get(`/api/jobs/${jobId}/progress`).set(T(BUILDER)));
    assert.ok(timeline.some((l) => l.id === log.id));
    expectErr(await api.get(`/api/jobs/${jobId}/progress`).set(T(OUTSIDER)), 403);

    const approved = expectOk(await api.patch(`/api/progress/${log.id}`).set(T(BUILDER)).send({ approved: true }));
    assert.equal(approved.approved, true);
    expectErr(await api.patch(`/api/progress/${log.id}`).set(T(MAZ1)).send({ approved: true }), 403); // not owner
    expectErr(await api.patch(`/api/progress/${log.id}`).set(T(BUILDER)).send({}), 400);
    globalThis.__LOG_ID = log.id;
  });

  it('ratings only after completion; both directions; averages update', async () => {
    // too early -> 409
    expectErr(
      await api.post(`/api/jobs/${jobId}/ratings`).set(T(BUILDER)).send({ rateeId: MAZ1, stars: 5 }),
      409
    );

    const job = expectOk(await api.patch(`/api/jobs/${jobId}`).set(T(BUILDER)).send({ status: 'completed' }));
    assert.equal(job.status, 'completed');

    const r1 = expectOk(
      await api.post(`/api/jobs/${jobId}/ratings`).set(T(BUILDER)).send({ rateeId: MAZ1, stars: 5, comment: 'Great work' }),
      201
    );
    assert.equal(r1.raterRole, 'builder');

    const r2 = expectOk(
      await api.post(`/api/jobs/${jobId}/ratings`).set(T(MAZ1)).send({ rateeId: BUILDER, stars: 4 }),
      201
    );
    assert.equal(r2.raterRole, 'mazdoor');

    const mazPub = expectOk(await api.get(`/api/users/${MAZ1}`));
    assert.equal(mazPub.ratingCount, 1);
    assert.equal(mazPub.ratingAvg, 5);
    const builderPub = expectOk(await api.get(`/api/users/${BUILDER}`));
    assert.equal(builderPub.ratingAvg, 4);

    const received = expectOk(await api.get(`/api/users/${MAZ1}/ratings`));
    assert.ok(received.some((r) => r.id === r1.id));

    // duplicate -> 409; bad stars -> 400; self-rating -> 400
    expectErr(await api.post(`/api/jobs/${jobId}/ratings`).set(T(BUILDER)).send({ rateeId: MAZ1, stars: 5 }), 409);
    expectErr(await api.post(`/api/jobs/${jobId}/ratings`).set(T(BUILDER)).send({ rateeId: MAZ3, stars: 6 }), 400);
    expectErr(await api.post(`/api/jobs/${jobId}/ratings`).set(T(BUILDER)).send({ rateeId: BUILDER, stars: 5 }), 400);

    const closed = expectOk(await api.patch(`/api/jobs/${jobId}`).set(T(BUILDER)).send({ status: 'closed' }));
    assert.equal(closed.status, 'closed');
  });
});

// ---------------------------------------------------------------------------
// 5. Wage ledger (uses the closed job above)
// ---------------------------------------------------------------------------
describe('ledger', () => {
  let jobId;
  let entryId;
  before(() => {
    jobId = globalThis.__JOB_ID;
  });

  it('records entries with gross/net math', async () => {
    const e = expectOk(
      await api.post(`/api/jobs/${jobId}/ledger`).set(T(BUILDER)).send({
        mazdoorId: MAZ1,
        date: '2026-10-06',
        daysWorked: 2,
        dailyWage: 1500,
        advance: 500,
        deduction: 0,
        note: 'Week 1',
      }),
      201
    );
    assert.equal(e.gross, 3000);
    assert.equal(e.net, 2500);
    assert.equal(e.paid, false);
    entryId = e.id;

    expectOk(
      await api.post(`/api/jobs/${jobId}/ledger`).set(T(BUILDER)).send({
        mazdoorId: MAZ1,
        date: '2026-10-07',
        daysWorked: 1,
        dailyWage: 1500,
        paid: true,
      }),
      201
    );

    expectErr(
      await api.post(`/api/jobs/${jobId}/ledger`).set(T(BUILDER)).send({ mazdoorId: MAZ1, date: '2026-10-08', daysWorked: 0, dailyWage: 1500 }),
      400
    );
    expectErr(
      await api.post(`/api/jobs/${jobId}/ledger`).set(T(BUILDER)).send({ date: '2026-10-08', daysWorked: 1, dailyWage: 1500 }),
      400
    );
    expectErr(
      await api.post(`/api/jobs/${jobId}/ledger`).set(T(MAZ1)).send({ mazdoorId: MAZ1, date: '2026-10-08', daysWorked: 1, dailyWage: 1500 }),
      403
    );
  });

  it('GET ledger returns entries + perWorker + totals', async () => {
    const data = expectOk(await api.get(`/api/jobs/${jobId}/ledger`).set(T(BUILDER)));
    assert.equal(data.entries.length, 2);
    assert.equal(data.perWorker.length, 1);
    const w = data.perWorker[0];
    assert.equal(w.mazdoorId, MAZ1);
    assert.equal(w.daysWorked, 3);
    assert.equal(w.gross, 4500);
    assert.equal(w.net, 4000);
    assert.equal(w.paidAmount, 1500);
    assert.equal(w.balance, 2500);
    assert.equal(data.totals.gross, 4500);
    assert.equal(data.totals.net, 4000);
    assert.equal(data.totals.balance, 2500);

    // assigned worker can read; outsider cannot
    expectOk(await api.get(`/api/jobs/${jobId}/ledger`).set(T(MAZ1)));
    expectErr(await api.get(`/api/jobs/${jobId}/ledger`).set(T(OUTSIDER)), 403);
  });

  it('marks entries paid/unpaid', async () => {
    const paid = expectOk(await api.patch(`/api/ledger/${entryId}`).set(T(BUILDER)).send({ paid: true }));
    assert.equal(paid.paid, true);
    assert.ok(paid.paidAt);
    const unpaid = expectOk(await api.patch(`/api/ledger/${entryId}`).set(T(BUILDER)).send({ paid: false }));
    assert.equal(unpaid.paid, false);
    expectErr(await api.patch(`/api/ledger/${entryId}`).set(T(BUILDER)).send({ paid: 'yes' }), 400);
    expectErr(await api.patch(`/api/ledger/${entryId}`).set(T(OUTSIDER)).send({ paid: true }), 403);
    expectErr(await api.patch('/api/ledger/nope').set(T(BUILDER)).send({ paid: true }), 404);
  });

  it('GET /api/ledger/mine returns the mazdoor’s entries', async () => {
    const mine = expectOk(await api.get('/api/ledger/mine').set(T(MAZ1)));
    assert.equal(mine.length, 2);
    assert.ok(mine.every((e) => e.mazdoorId === MAZ1));
    const none = expectOk(await api.get('/api/ledger/mine').set(T(BUILDER)));
    assert.equal(none.length, 0);
    expectErr(await api.get('/api/ledger/mine'), 401);
  });
});

// ---------------------------------------------------------------------------
// 6. Notifications
// ---------------------------------------------------------------------------
describe('notifications', () => {
  let notifId;

  it('sends + stores inbox copies', async () => {
    // MAZ1 has no device token -> FCM send is skipped, inbox copy still stored
    const res = expectOk(
      await api.post('/api/notify').set(T(BUILDER)).send({
        userIds: [MAZ1],
        title: 'New invite',
        body: 'You were invited to House grey structure',
        data: { jobId: globalThis.__JOB_ID },
      })
    );
    assert.equal(res.notificationsStored, 1);
    assert.equal(res.tokensTargeted, 0);
    assert.equal(res.sent, 0);

    expectErr(await api.post('/api/notify').set(T(BUILDER)).send({ userIds: [], title: 't', body: 'b' }), 400);
    expectErr(await api.post('/api/notify').set(T(BUILDER)).send({ userIds: [MAZ1], body: 'b' }), 400);
    expectErr(await api.post('/api/notify').send({ userIds: [MAZ1], title: 't', body: 'b' }), 401);
  });

  it('inbox read + mark-read flow', async () => {
    const inbox = expectOk(await api.get('/api/users/me/notifications').set(T(MAZ1)));
    assert.equal(inbox.length, 1);
    assert.equal(inbox[0].read, false);
    notifId = inbox[0].id;

    const unread = expectOk(await api.get('/api/users/me/notifications?unread=true').set(T(MAZ1)));
    assert.equal(unread.length, 1);

    const marked = expectOk(await api.patch(`/api/notifications/${notifId}/read`).set(T(MAZ1)));
    assert.equal(marked.read, true);

    const unreadAfter = expectOk(await api.get('/api/users/me/notifications?unread=true').set(T(MAZ1)));
    assert.equal(unreadAfter.length, 0);

    // another user's notification -> 403; unknown -> 404
    expectErr(await api.patch(`/api/notifications/${notifId}/read`).set(T(BUILDER)), 403);
    expectErr(await api.patch('/api/notifications/nope/read').set(T(MAZ1)), 404);
  });
});

// ---------------------------------------------------------------------------
// 7. Auth enforcement
// ---------------------------------------------------------------------------
describe('auth', () => {
  it('protected routes reject missing tokens (401)', async () => {
    expectErr(await api.post('/api/jobs').send({}), 401);
    expectErr(await api.get('/api/users/me'), 401);
    expectErr(await api.post('/api/notify').send({}), 401);
    expectErr(await api.get(`/api/jobs/${globalThis.__JOB_ID}/matches`), 401);
    expectErr(await api.post(`/api/jobs/${globalThis.__JOB_ID}/progress`).send({}), 401);
  });

  it('public reads work without a token', async () => {
    expectOk(await api.get('/api/jobs'));
    expectOk(await api.get(`/api/jobs/${globalThis.__JOB_ID}`));
    expectOk(await api.get(`/api/users/${MAZ1}`));
    expectOk(await api.get(`/api/users/${MAZ1}/ratings`));
  });

  it('garbage Bearer token is rejected (401)', async () => {
    expectErr(await api.get('/api/users/me').set({ Authorization: 'Bearer garbage-token' }), 401);
  });

  it('test bypass is off without the env flag', async () => {
    // Sanity: the Test scheme only works when ALLOW_TEST_AUTH=true (it is, here).
    const me = expectOk(await api.get('/api/users/me').set(T(BUILDER)));
    assert.equal(me.id, BUILDER);
  });
});
