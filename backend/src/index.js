// Mazdoor Sathi API — Express application entry point.
// Mounts all route modules, a health check, a 404 handler and a central
// error handler. Run with `npm run dev` (watch) or `npm start`.

import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import morgan from 'morgan';

import { ok, fail } from './utils/http.js';

import usersRouter from './routes/users.js';
import jobsRouter from './routes/jobs.js';
import matchingRouter from './routes/matching.js';
import applicationsRouter from './routes/applications.js';
import progressRouter from './routes/progress.js';
import ledgerRouter from './routes/ledger.js';
import ratingsRouter from './routes/ratings.js';
import notificationsRouter from './routes/notifications.js';

const app = express();
const PORT = process.env.PORT || 5000;

// --- Middleware -------------------------------------------------------------
const corsOrigins = process.env.CORS_ORIGIN
  ? process.env.CORS_ORIGIN.split(',').map((s) => s.trim())
  : '*';
app.use(cors({ origin: corsOrigins }));
app.use(express.json({ limit: '2mb' }));
app.use(morgan('dev'));

// --- Meta routes ------------------------------------------------------------
app.get('/', (req, res) =>
  ok(res, {
    name: 'Mazdoor Sathi API',
    version: '1.0.0',
    health: '/health',
    docs: 'See README.md for the full endpoint list.',
  })
);

app.get('/health', (req, res) =>
  ok(res, { status: 'up', time: new Date().toISOString() })
);

// --- API routes -------------------------------------------------------------
// Note: applications/progress/ledger/ratings/notifications routers are
// mounted at /api because they serve nested paths (e.g. /api/jobs/:id/invite).
app.use('/api/users', usersRouter);
app.use('/api/jobs', jobsRouter);
app.use('/api/jobs', matchingRouter); // GET /api/jobs/:id/matches
app.use('/api', applicationsRouter);
app.use('/api', progressRouter);
app.use('/api', ledgerRouter);
app.use('/api', ratingsRouter);
app.use('/api', notificationsRouter);

// --- 404 + error handling ---------------------------------------------------
app.use((req, res) => fail(res, 404, `Not found: ${req.method} ${req.path}`));

// Central error handler (must be last; 4 args so Express treats it as one).
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('[api:error]', err);
  const status = err.status || 500;
  fail(res, status, err.message || 'Internal server error');
});

import { pathToFileURL } from 'url';

// Only bind a port when run directly (`node src/index.js` / `npm start`).
// Importing the app (e.g. from the test suite) must NOT start a listener.
const isMainEntry =
  import.meta.url === pathToFileURL(process.argv[1] ?? '').href;
if (isMainEntry) {
  app.listen(PORT, () => {
    console.log(`Mazdoor Sathi API listening on http://localhost:${PORT}`);
  });
}

export default app;
