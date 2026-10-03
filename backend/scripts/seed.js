// Mazdoor Sathi — Firestore seed script.
//
// Writes demo data: 1 builder, 8 mazdoors, 2 jobs, applications,
// progress logs, wage ledger entries, ratings, notifications.
//
// SAFETY: this writes to whatever Firebase project your service-account
// credentials point at. It refuses to run unless you explicitly confirm:
//   SEED=true npm run seed        # via env var
//   npm run seed -- --confirm      # via CLI flag
//
// Requires a real Firebase service account in .env (see .env.example).

import 'dotenv/config';
import { db, serverTimestamp } from '../src/config/firebase.js';

const confirmed = process.env.SEED === 'true' || process.argv.includes('--confirm');
if (!confirmed) {
  console.error(
    'Refusing to seed: set SEED=true in your environment or run with --confirm.\n' +
      'Example: SEED=true npm run seed'
  );
  process.exit(1);
}

// --- Reference data ----------------------------------------------------------
const GUJRAT = { lat: 32.5736, lng: 74.074 };
const LAHORE = { lat: 32.5204, lng: 74.3587 };
const SIALKOT = { lat: 32.4945, lng: 74.5229 };

const BUILDER_ID = 'seed-builder-ahmed';

const MAZDOORS = [
  { uid: 'seed-mazdoor-aslam', name: 'Muhammad Aslam', trades: ['mason'], skills: ['راج مستری', 'brickwork', 'plaster'], city: 'Gujrat', location: { lat: 32.575, lng: 74.076 }, dailyWage: 1800, ratingAvg: 4.6, ratingCount: 12 },
  { uid: 'seed-mazdoor-imran', name: 'Imran Ali', trades: ['electrician'], skills: ['الیکٹریشن', 'wiring', 'switchboards'], city: 'Lahore', location: { lat: 31.521, lng: 74.36 }, dailyWage: 2000, ratingAvg: 4.8, ratingCount: 20 },
  { uid: 'seed-mazdoor-shahid', name: 'Shahid Mehmood', trades: ['plumber'], skills: ['پلمبر', 'pipe fitting', 'sanitary'], city: 'Lahore', location: { lat: 31.519, lng: 74.355 }, dailyWage: 2000, ratingAvg: 4.2, ratingCount: 8 },
  { uid: 'seed-mazdoor-bilal', name: 'Bilal Hussain', trades: ['painter'], skills: ['پینٹر', 'wall paint', 'putty'], city: 'Gujrat', location: { lat: 32.572, lng: 74.072 }, dailyWage: 1500, ratingAvg: 4.5, ratingCount: 15 },
  { uid: 'seed-mazdoor-tariq', name: 'Tariq Javed', trades: ['carpenter'], skills: ['ترکھان', 'woodwork', 'door frames'], city: 'Sialkot', location: { lat: 32.496, lng: 74.524 }, dailyWage: 1800, ratingAvg: 4.0, ratingCount: 5 },
  { uid: 'seed-mazdoor-nadeem', name: 'Nadeem Akhtar', trades: ['steel_fixer'], skills: ['سٹیل فکسر', 'rebar', 'shuttering'], city: 'Lahore', location: { lat: 31.522, lng: 74.362 }, dailyWage: 1700, ratingAvg: 3.8, ratingCount: 6 },
  { uid: 'seed-mazdoor-rashid', name: 'Rashid Mahmood', trades: ['general_laborer'], skills: ['مزدور', 'loading', 'site cleanup'], city: 'Gujrat', location: { lat: 32.574, lng: 74.073 }, dailyWage: 1200, ratingAvg: 4.1, ratingCount: 9 },
  { uid: 'seed-mazdoor-khalid', name: 'Khalid Pervaiz', trades: ['mason', 'general_laborer'], skills: ['راج مستری', 'concrete mixing'], city: 'Sialkot', location: { lat: 32.493, lng: 74.521 }, dailyWage: 1600, ratingAvg: 4.4, ratingCount: 11 },
];

const JOBS = [
  {
    id: 'seed-job-house-gujrat',
    title: '5 Marla House — Grey Structure',
    description: 'Grey structure for a 5 marla house in Model Town Gujrat. Need experienced masons and helpers.',
    tradesRequired: [
      { trade: 'mason', count: 2, wageOffer: 1800 },
      { trade: 'general_laborer', count: 2, wageOffer: 1200 },
    ],
    siteLocation: { lat: 32.5745, lng: 74.0755 },
    city: 'Gujrat',
    startDate: '2026-09-15',
    expectedDays: 60,
    status: 'in_progress',
    assignedTeam: [
      { mazdoorId: 'seed-mazdoor-aslam', trade: 'mason', dailyWage: 1800 },
      { mazdoorId: 'seed-mazdoor-rashid', trade: 'general_laborer', dailyWage: 1200 },
    ],
  },
  {
    id: 'seed-job-renovation-lahore',
    title: 'Apartment Renovation — DHA Phase 5',
    description: 'Full renovation of a 10 marla apartment: rewiring, plumbing and repaint.',
    tradesRequired: [
      { trade: 'electrician', count: 1, wageOffer: 2000 },
      { trade: 'plumber', count: 1, wageOffer: 2000 },
      { trade: 'painter', count: 1, wageOffer: 1500 },
    ],
    siteLocation: { lat: 31.52, lng: 74.359 },
    city: 'Lahore',
    startDate: '2026-08-01',
    expectedDays: 30,
    status: 'completed',
    assignedTeam: [
      { mazdoorId: 'seed-mazdoor-imran', trade: 'electrician', dailyWage: 2000 },
      { mazdoorId: 'seed-mazdoor-shahid', trade: 'plumber', dailyWage: 2000 },
      { mazdoorId: 'seed-mazdoor-bilal', trade: 'painter', dailyWage: 1500 },
    ],
  },
];

function ledgerEntry(jobId, mazdoorId, date, daysWorked, dailyWage, { advance = 0, deduction = 0, paid = false, note = '' } = {}) {
  const gross = daysWorked * dailyWage;
  return {
    jobId,
    mazdoorId,
    date,
    daysWorked,
    dailyWage,
    advance,
    deduction,
    gross,
    net: gross - advance - deduction,
    paid,
    paidAt: paid ? serverTimestamp() : null,
    note,
    createdBy: BUILDER_ID,
    createdAt: serverTimestamp(),
  };
}

async function main() {
  const batch = db.batch();
  const set = (col, id, data) => batch.set(db.collection(col).doc(id), data);

  // --- Users ----------------------------------------------------------------
  set('users', BUILDER_ID, {
    uid: BUILDER_ID,
    name: 'Ahmed Raza',
    phone: '0300-1234567',
    role: 'builder',
    trades: [],
    skills: ['residential construction'],
    dailyWage: null,
    location: GUJRAT,
    city: 'Gujrat',
    availability: true,
    cnic: '34201-1234567-1',
    ratingAvg: 4.9,
    ratingCount: 7,
    completedJobs: 3,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  for (const m of MAZDOORS) {
    set('users', m.uid, {
      uid: m.uid,
      name: m.name,
      phone: '03' + String(100000000 + Math.floor(Math.random() * 899999999)),
      role: 'mazdoor',
      trades: m.trades,
      skills: m.skills,
      dailyWage: m.dailyWage,
      location: m.location,
      city: m.city,
      availability: true,
      cnic: '34201-7654321-1',
      ratingAvg: m.ratingAvg,
      ratingCount: m.ratingCount,
      completedJobs: m.ratingCount,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  }

  // --- Jobs -----------------------------------------------------------------
  for (const j of JOBS) {
    set('jobs', j.id, {
      builderId: BUILDER_ID,
      title: j.title,
      description: j.description,
      tradesRequired: j.tradesRequired,
      tradeList: [...new Set(j.tradesRequired.map((t) => t.trade))],
      siteLocation: j.siteLocation,
      city: j.city,
      startDate: j.startDate,
      expectedDays: j.expectedDays,
      status: j.status,
      assignedTeam: j.assignedTeam,
      assignedTeamIds: j.assignedTeam.map((m) => m.mazdoorId),
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  }

  // --- Applications ----------------------------------------------------------
  const apps = [
    ['seed-job-house-gujrat', 'seed-mazdoor-aslam', 'mason', 1800, 'accepted'],
    ['seed-job-house-gujrat', 'seed-mazdoor-rashid', 'general_laborer', 1200, 'accepted'],
    ['seed-job-house-gujrat', 'seed-mazdoor-khalid', 'mason', 1600, 'invited'],
    ['seed-job-renovation-lahore', 'seed-mazdoor-imran', 'electrician', 2000, 'accepted'],
    ['seed-job-renovation-lahore', 'seed-mazdoor-shahid', 'plumber', 2000, 'accepted'],
    ['seed-job-renovation-lahore', 'seed-mazdoor-bilal', 'painter', 1500, 'accepted'],
  ];
  apps.forEach(([jobId, mazdoorId, trade, wageOffer, status], i) => {
    set('applications', `seed-app-${i + 1}`, {
      jobId,
      mazdoorId,
      builderId: BUILDER_ID,
      trade,
      wageOffer,
      status,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      respondedAt: status === 'invited' ? null : serverTimestamp(),
    });
  });

  // --- Progress logs ----------------------------------------------------------
  const logs = [
    {
      id: 'seed-log-1', jobId: 'seed-job-house-gujrat', authorId: 'seed-mazdoor-aslam',
      authorRole: 'mazdoor', date: '2026-09-16', note: 'Foundation brickwork started. Material delivered on site.',
      photoUrls: [], percentComplete: 10, approved: true, flagged: false,
    },
    {
      id: 'seed-log-2', jobId: 'seed-job-house-gujrat', authorId: 'seed-mazdoor-aslam',
      authorRole: 'mazdoor', date: '2026-09-20', note: 'Walls raised to lintel level. Photos attached.',
      photoUrls: ['https://example.com/photos/seed-wall-1.jpg'], percentComplete: 40, approved: null, flagged: false,
    },
    {
      id: 'seed-log-3', jobId: 'seed-job-renovation-lahore', authorId: 'seed-mazdoor-imran',
      authorRole: 'mazdoor', date: '2026-08-25', note: 'Electrical rewiring complete, all points tested.',
      photoUrls: [], percentComplete: 100, approved: true, flagged: false,
    },
  ];
  for (const l of logs) {
    const { id, ...rest } = l;
    set('progressLogs', id, { ...rest, createdAt: serverTimestamp() });
  }

  // --- Wage ledger ------------------------------------------------------------
  const entries = [
    ledgerEntry('seed-job-house-gujrat', 'seed-mazdoor-aslam', '2026-09-20', 6, 1800, { advance: 2000, paid: true, note: 'Week 1 wages' }),
    ledgerEntry('seed-job-house-gujrat', 'seed-mazdoor-rashid', '2026-09-20', 6, 1200, { note: 'Week 1 wages' }),
    ledgerEntry('seed-job-renovation-lahore', 'seed-mazdoor-imran', '2026-08-28', 10, 2000, { paid: true, note: 'Full contract' }),
    ledgerEntry('seed-job-renovation-lahore', 'seed-mazdoor-shahid', '2026-08-28', 8, 2000, { advance: 3000, paid: true }),
    ledgerEntry('seed-job-renovation-lahore', 'seed-mazdoor-bilal', '2026-08-28', 7, 1500, { paid: true }),
  ];
  entries.forEach((e, i) => set('wageLedger', `seed-ledger-${i + 1}`, e));

  // --- Ratings ----------------------------------------------------------------
  const ratings = [
    { id: 'seed-rating-1', jobId: 'seed-job-renovation-lahore', raterId: BUILDER_ID, rateeId: 'seed-mazdoor-imran', raterRole: 'builder', stars: 5, comment: 'Excellent wiring work, finished on time.' },
    { id: 'seed-rating-2', jobId: 'seed-job-renovation-lahore', raterId: BUILDER_ID, rateeId: 'seed-mazdoor-shahid', raterRole: 'builder', stars: 4, comment: 'Good work, slight delay on day 3.' },
    { id: 'seed-rating-3', jobId: 'seed-job-renovation-lahore', raterId: 'seed-mazdoor-imran', rateeId: BUILDER_ID, raterRole: 'mazdoor', stars: 5, comment: 'Paid on time, clear instructions.' },
  ];
  for (const r of ratings) {
    const { id, ...rest } = r;
    set('ratings', id, { ...rest, createdAt: serverTimestamp() });
  }

  // --- Notifications + a sample device token -----------------------------------
  set('notifications', 'seed-notif-1', {
    userId: BUILDER_ID, title: 'Application accepted', body: 'Muhammad Aslam accepted your invitation.',
    data: { jobId: 'seed-job-house-gujrat', type: 'application_accepted' }, read: false, createdAt: serverTimestamp(),
  });
  set('notifications', 'seed-notif-2', {
    userId: BUILDER_ID, title: 'Progress update', body: 'Walls raised to lintel level (40%).',
    data: { jobId: 'seed-job-house-gujrat', type: 'progress_posted' }, read: false, createdAt: serverTimestamp(),
  });
  set('deviceTokens', 'seed-token-1', {
    userId: BUILDER_ID, token: 'fcm-test-token-do-not-use', platform: 'android', updatedAt: serverTimestamp(),
  });

  await batch.commit();

  console.log('Seed complete:');
  console.log(`  users:         1 builder + ${MAZDOORS.length} mazdoors`);
  console.log(`  jobs:          ${JOBS.length}`);
  console.log(`  applications:  ${apps.length}`);
  console.log(`  progressLogs:  ${logs.length}`);
  console.log(`  wageLedger:    ${entries.length}`);
  console.log(`  ratings:       ${ratings.length}`);
  console.log('  notifications: 2, deviceTokens: 1');
}

main().catch((err) => {
  console.error('Seed failed:', err.message);
  process.exit(1);
});
