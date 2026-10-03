# Mazdoor Sathi — Backend API

Express + Firebase Admin backend for **Mazdoor Sathi**, a platform connecting
builders/homeowners with construction laborers (mazdoors) in Pakistan.
Supports team-based hiring by trade, skill/rating/proximity matching, job
status tracking, daily photo progress logs, a digital wage ledger, ratings,
and FCM push notifications. Pairs with the Flutter mobile app.

## Prerequisites

- Node.js 18+
- A Firebase project with **Firestore** and **Cloud Messaging** enabled

## Setup

1. **Create a Firebase project** at https://console.firebase.google.com
   - Enable Firestore (production or test mode — then deploy `firestore.rules`)
   - Enable Cloud Messaging (for push notifications)

2. **Create a service account key**
   - Firebase Console → Project Settings → Service accounts → *Generate new private key*
   - The downloaded JSON contains `project_id`, `client_email`, `private_key`

3. **Configure environment**

   ```bash
   cp .env.example .env
   # then edit .env and paste the three service-account values
   ```

   The private key must keep its `\n` escape sequences inside the quotes, e.g.
   `FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nABC...\n-----END PRIVATE KEY-----\n"`.

4. **Install and run**

   ```bash
   npm install
   npm run dev     # watch mode, http://localhost:5000
   npm start       # production
   ```

5. **(Optional) Deploy Firestore rules**

   ```bash
   firebase deploy --only firestore:rules   # from the project root, or paste firestore.rules into the console
   ```

## Testing

```bash
npm test   # 37 integration tests, in-memory Firestore — no credentials needed
```

See **[TESTING.md](TESTING.md)** for the full guide (emulator mode, seeding,
test auth bypass, coverage table).

## Seeding demo data

`scripts/seed.js` writes 1 builder, 8 mazdoors (Gujrat / Lahore / Sialkot),
2 jobs, applications, progress logs, ledger entries, ratings and
notifications. **It writes to the project in your `.env`** and refuses to run
without explicit confirmation:

```bash
SEED=true npm run seed
# or
npm run seed -- --confirm
```

Requires the `FIREBASE_*` service-account variables when run normally, and can
also target the Firestore emulator (`FIRESTORE_EMULATOR_HOST=...`) or the
in-memory test Firestore (`FIRESTORE_FAKE=true`) — see TESTING.md.

## Authentication

All write endpoints (and a few sensitive reads) require a Firebase ID token:

```
Authorization: Bearer <Firebase ID token>
```

The Flutter app obtains it via
`FirebaseAuth.instance.currentUser.getIdToken()`. The middleware
(`src/middleware/auth.js`) verifies it and attaches `req.user = { uid, email, name }`.

## Response shape

Every response uses one envelope:

```json
{ "ok": true,  "data": { ... }, "error": null }
{ "ok": false, "data": null,    "error": { "message": "...", "details": [...] } }
```

## API reference

Base URL: `http://localhost:5000`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/health` | – | Health check |
| POST | `/api/users/profile` | ✅ | Create/update own profile (builder or mazdoor) |
| GET | `/api/users/me` | ✅ | Own full profile |
| POST | `/api/users/me/device-token` | ✅ | Register FCM token for push |
| GET | `/api/users/me/applications` | ✅ | Mazdoor's invitations |
| GET | `/api/users/me/notifications` | ✅ | Notification inbox (`?unread=true`) |
| GET | `/api/users/:id` | – | Public profile + rating summary |
| GET | `/api/users/:id/ratings` | – | Ratings received by a user |
| POST | `/api/jobs` | ✅ | Builder creates a job |
| GET | `/api/jobs?city=&trade=&status=&builderId=&mine=true` | – | List/filter jobs (`mine=true` needs auth: builder's posted / mazdoor's assigned jobs) |
| GET | `/api/jobs/:id` | – | Job detail |
| PATCH | `/api/jobs/:id` | ✅ owner | Edit fields; status transitions `draft→open→assigned→in_progress→completed→closed` (plus `cancelled`) |
| DELETE | `/api/jobs/:id` | ✅ owner | Delete draft jobs only |
| GET | `/api/jobs/:id/matches?radiusKm=25&limit=20` | ✅ | Ranked mazdoor matches with score breakdown |
| POST | `/api/jobs/:id/invite` | ✅ owner | Invite a mazdoor (`mazdoorId`, `trade`, `wageOffer`) |
| GET | `/api/applications/:id` | ✅ party | View one application (job owner or invited mazdoor) |
| GET | `/api/jobs/:id/applications` | ✅ owner | All applications for a job |
| POST | `/api/applications/:id/respond` | ✅ mazdoor | Accept / decline invitation |
| POST | `/api/jobs/:id/progress` | ✅ party | Daily log: `date`, `note`, `photoUrls[]`, `percentComplete` |
| GET | `/api/jobs/:id/progress` | ✅ party | Progress timeline |
| PATCH | `/api/progress/:logId` | ✅ owner | Approve / flag an entry |
| POST | `/api/jobs/:id/ledger` | ✅ owner | Wage entry (`mazdoorId`, `date`, `daysWorked`, `dailyWage`, `advance`, `deduction`, `paid`) |
| GET | `/api/jobs/:id/ledger` | ✅ party | Entries + per-worker and job totals |
| PATCH | `/api/ledger/:entryId` | ✅ owner | Mark entry paid/unpaid |
| GET | `/api/ledger/mine` | ✅ | Caller's own ledger entries across all jobs |
| POST | `/api/jobs/:id/ratings` | ✅ party | Rate the other party after completion (1–5) |
| POST | `/api/notify` | ✅ | Send FCM to `userIds[]` (`title`, `body`, `data`); stores inbox copy |
| PATCH | `/api/notifications/:id/read` | ✅ | Mark notification read |

"party" = job owner or an assigned worker.

### Matching score

`GET /api/jobs/:id/matches` scores each available mazdoor within `radiusKm`
whose trades overlap the job's required trades:

- trade match 40% · rating 25% (unrated → neutral 3.0) · proximity 25% · wage fit 10%

## Project layout

```
backend/
├── package.json
├── .env.example
├── firestore.rules
├── README.md
├── scripts/
│   └── seed.js            # demo data (guarded by SEED=true / --confirm)
└── src/
    ├── index.js           # app wiring, health check, error handler
    ├── config/
    │   └── firebase.js    # Admin SDK init; exports db, auth, messaging
    ├── middleware/
    │   └── auth.js        # requireAuth / optionalAuth (Firebase ID tokens)
    ├── utils/
    │   ├── haversine.js   # distance helper for matching
    │   └── http.js        # {ok,data,error} envelope, async wrapper, validators
    └── routes/
        ├── users.js         # profiles, device tokens
        ├── jobs.js          # job CRUD + status flow
        ├── matching.js      # weighted worker ranking
        ├── applications.js  # invites + accept/decline
        ├── progress.js      # daily photo progress logs
        ├── ledger.js        # digital wage ledger + totals
        ├── ratings.js       # post-job ratings, transactional avg update
        └── notifications.js # FCM send + inbox
```

## Firestore data model

| Collection | Key fields |
|---|---|
| `users` | `uid, name, phone, role, trades[], skills[], dailyWage, location{lat,lng}, city, availability, yearsExperience, cnic, ratingAvg, ratingCount, completedJobs` |
| `jobs` | `builderId, title, description, tradesRequired[{trade,count,wageOffer}], tradeList[], siteLocation, city, startDate, expectedDays, status, assignedTeam[], assignedTeamIds[]` |
| `applications` | `jobId, mazdoorId, builderId, trade, wageOffer, status, respondedAt` |
| `progressLogs` | `jobId, authorId, authorRole, date, note, photoUrls[], percentComplete, approved, flagged` |
| `wageLedger` | `jobId, mazdoorId, date, daysWorked, dailyWage, advance, deduction, gross, net, paid, paidAt, note` |
| `ratings` | `jobId, raterId, rateeId, raterRole, stars, comment` |
| `notifications` | `userId, title, body, data, read` |
| `deviceTokens` | `userId, token, platform` |
