# Firestore Data Model — Mazdoor Sathi

**Version:** 1.1 — October 2026
Companion to `SRS.md` (requirements), `API.md` (endpoints), `ARCHITECTURE.md` (flows).

Conventions: document IDs are Firestore auto-IDs (`collection.add()`) unless
noted. Timestamps are ISO-8601 strings (`new Date().toISOString()`) produced
by the API. Monetary values are numbers in **PKR**.

---

## 1. Collections Overview

| Collection | Purpose | Key relations |
|---|---|---|
| `users` | Builder & mazdoor profiles (doc ID = Firebase Auth UID) | 1 → N `jobs` (as builder), `applications`, `progressLogs`, `wageLedger`, `ratings`, `notifications`, `deviceTokens` |
| `jobs` | Job postings incl. multi-trade requirements | N → 1 `users` (builder); 1 → N `applications`, `progressLogs`, `wageLedger`, `ratings` |
| `applications` | Invites, accept/decline/remove | N → 1 `jobs`; N → 1 `users` (mazdoor); N → 1 `users` (builder) |
| `progressLogs` | Daily progress entries (photos + % complete) | N → 1 `jobs`; N → 1 `users` (author) |
| `wageLedger` | Wage entries (days × wage, advances, deductions, paid flag) | N → 1 `jobs`; N → 1 `users` (mazdoor) |
| `ratings` | Post-job ratings between builder and mazdoor | N → 1 `jobs`; N → 1 `users` (rater); N → 1 `users` (ratee) |
| `notifications` | In-app notification inbox | N → 1 `users` |
| `deviceTokens` | FCM device tokens (doc ID = sanitised token) | N → 1 `users` |

**ER-style summary:** A `users` document with `role = "builder"` owns many `jobs`. Each `jobs` document embeds a `tradesRequired[]` array (with a denormalised `tradeList[]` for filtering) plus an `assignedTeam[]` array once hired, and links to many `applications` (one per invited mazdoor), many `progressLogs` (one per author per day), many `wageLedger` entries (days worked × daily wage, advances, deductions, paid flag), and ratings. Each `applications` document ties one mazdoor to one job. `notifications` and `deviceTokens` hang off `users` for messaging.

---

## 2. Collection Schemas

### 2.1 `users` (doc ID = Firebase Auth `uid`)

| Field | Type | Description | Example |
|---|---|---|---|
| `uid` | string | Same as doc ID | `"uid_maz_7"` |
| `name` | string | Display name | `"Rashid Ali"` |
| `role` | string | `"builder"` or `"mazdoor"` | `"mazdoor"` |
| `phone` | string \| null | Phone number | `"03001234567"` |
| `trades` | string[] | Mazdoor trades | `["Mason", "Plasterer"]` |
| `skills` | string[] | Free-form skills | `["brickwork", "tiling"]` |
| `dailyWage` | number \| null | Expected PKR/day | `1500` |
| `location` | `{lat, lng}` map \| null | Home/base location pin | `{lat: 32.49, lng: 74.53}` |
| `city` | string \| null | Home city | `"Gujrat"` |
| `availability` | boolean | Open to invites | `true` |
| `yearsExperience` | number \| null | Years of experience (≥ 0) | `8` |
| `cnic` | string \| null | National ID (private — never in public reads) | `"34101-…"` |
| `ratingAvg` | number | Mean rating 0–5 | `4.3` |
| `ratingCount` | number | Number of ratings received | `12` |
| `completedJobs` | number | Completed jobs count | `5` |
| `createdAt` | string | ISO timestamp | — |
| `updatedAt` | string | ISO timestamp | — |

`GET /api/users/:id` hides `phone` and `cnic`.

### 2.2 `jobs`

| Field | Type | Description | Example |
|---|---|---|---|
| `builderId` | string | UID of posting builder | `"uid_builder_1"` |
| `title` | string | Short title | `"House grey structure"` |
| `description` | string | Details (may come from Urdu STT) | `"Double-storey grey structure…"` |
| `tradesRequired` | array of objects | `{ trade: string, count: number, wageOffer: number }` | `[{trade:"Mason",count:2,wageOffer:1500}]` |
| `tradeList` | string[] | Denormalised list of trades (for filtering) | `["Mason"]` |
| `siteLocation` | `{lat, lng}` map | Job-site pin | `{lat: 32.50, lng: 74.54}` |
| `city` | string | Job city | `"Gujrat"` |
| `startDate` | string \| null | `YYYY-MM-DD` | `"2026-10-10"` |
| `expectedDays` | number \| null | Planned duration | `20` |
| `status` | string | `draft` \| `open` \| `assigned` \| `in_progress` \| `completed` \| `closed` \| `cancelled` | `"open"` |
| `assignedTeam` | array of objects | `{ mazdoorId: string, trade: string, dailyWage: number \| null }` | `[{mazdoorId:"uid_maz_7",trade:"Mason",dailyWage:1500}]` |
| `assignedTeamIds` | string[] | Denormalised mazdoor IDs (for `mine=true` queries) | `["uid_maz_7"]` |
| `createdAt` | string | ISO timestamp | — |
| `updatedAt` | string | ISO timestamp | — |

Status transitions follow the `STATUS_FLOW` (see `API.md` §2): only `draft`/`open` jobs are editable; moving to `assigned` requires an `assignedTeam` whose members each hold an **accepted** application for the job.

### 2.3 `applications`

| Field | Type | Description | Example |
|---|---|---|---|
| `jobId` | string | Parent job | `"job_abc"` |
| `mazdoorId` | string | UID of worker | `"uid_maz_7"` |
| `builderId` | string | UID of job owner | `"uid_builder_1"` |
| `trade` | string | Trade invited for | `"Mason"` |
| `wageOffer` | number \| null | Offered PKR/day | `1500` |
| `status` | string | `invited` \| `accepted` \| `declined` \| `removed` | `"accepted"` |
| `createdAt` | string | ISO timestamp | — |
| `updatedAt` | string | ISO timestamp | — |
| `respondedAt` | string \| null | Accept/decline time | — |

Uniqueness: one **active** (`invited`/`accepted`) application per (`jobId`, `mazdoorId`) — enforced in backend logic. Flow: builder invites (`invited`) → mazdoor accepts/declines → builder may `removed`.

### 2.4 `progressLogs`

| Field | Type | Description | Example |
|---|---|---|---|
| `jobId` | string | Parent job | `"job_abc"` |
| `authorId` | string | UID of author | `"uid_maz_7"` |
| `authorRole` | string | `"builder"` or `"mazdoor"` | `"mazdoor"` |
| `date` | string | `YYYY-MM-DD` | `"2026-10-05"` |
| `note` | string \| null | Typed or voice-transcribed note | `"Ground floor walls done"` |
| `photoUrls` | string[] | Site photo URLs | `["https://…/p1.jpg"]` |
| `percentComplete` | number | 0–100 | `40` |
| `approved` | boolean \| null | `null` = pending builder review | `null` |
| `flagged` | boolean | Builder-flagged for attention | `false` |
| `createdAt` | string | ISO timestamp | — |

### 2.5 `wageLedger`

| Field | Type | Description | Example |
|---|---|---|---|
| `jobId` | string | Parent job | `"job_abc"` |
| `mazdoorId` | string | UID of worker | `"uid_maz_7"` |
| `date` | string | `YYYY-MM-DD` | `"2026-10-06"` |
| `daysWorked` | number | Days this entry covers | `1` |
| `dailyWage` | number | PKR/day | `1500` |
| `advance` | number | Advance already given | `0` |
| `deduction` | number | Deduction | `0` |
| `gross` | number | `daysWorked × dailyWage` (server-computed) | `1500` |
| `net` | number | `gross − advance − deduction` (server-computed) | `1500` |
| `paid` | boolean | Whether paid out | `false` |
| `paidAt` | string \| null | ISO timestamp when marked paid | `null` |
| `note` | string \| null | Memo | `"Day 3 wage"` |
| `createdBy` | string | UID of recorder (builder) | `"uid_builder_1"` |
| `createdAt` | string | ISO timestamp | — |

Totals (computed by the backend on read, never stored redundantly) per worker and per job: `daysWorked`, `gross`, `advance`, `deduction`, `net`, `paidAmount` (net of paid entries), `balance` (net − paidAmount, still owed).

### 2.6 `ratings`

| Field | Type | Description | Example |
|---|---|---|---|
| `jobId` | string | Completed/closed job | `"job_abc"` |
| `raterId` | string | UID of rater | `"uid_builder_1"` |
| `rateeId` | string | UID of ratee | `"uid_maz_7"` |
| `raterRole` | string | `"builder"` or `"mazdoor"` | `"builder"` |
| `stars` | number | 1–5 | `5` |
| `comment` | string \| null | Optional comment | `"Excellent brickwork"` |
| `createdAt` | string | ISO timestamp | — |

Uniqueness: one rating per (`jobId`, `raterId`, `rateeId`) — enforced in backend logic. On write, the ratee's `users.ratingAvg` / `users.ratingCount` are recalculated transactionally. Ratings are only allowed when the job is `completed`/`closed`, only between the builder and an assigned worker, and never self-ratings.

### 2.7 `notifications`

| Field | Type | Description | Example |
|---|---|---|---|
| `userId` | string | Recipient UID | `"uid_maz_7"` |
| `title` | string | Short title | `"New job invite"` |
| `body` | string | Details | `"You are invited as Mason…"` |
| `data` | map | Payload (values stringified for FCM), e.g. `{ jobId }` | `{"jobId":"job_abc"}` |
| `read` | boolean | Inbox state | `false` |
| `createdAt` | string | ISO timestamp | — |

### 2.8 `deviceTokens` (doc ID = sanitised FCM token)

| Field | Type | Description | Example |
|---|---|---|---|
| `userId` | string | Owner UID | `"uid_maz_7"` |
| `platform` | string | e.g. `"android"` | `"android"` |
| `createdAt` | string | ISO timestamp | — |
| `updatedAt` | string | ISO timestamp | — |

Dead FCM tokens are pruned by the backend when push delivery fails.

---

## 3. Indexes (composite)

| Collection | Fields | Use |
|---|---|---|
| `jobs` | `status` ASC, `createdAt` DESC | Browse open jobs |
| `jobs` | `builderId` ASC, `createdAt` DESC | Builder's job list |
| `jobs` | `assignedTeamIds` array-contains, `createdAt` DESC | `mine=true` for mazdoors |
| `applications` | `jobId` ASC, `status` ASC | Job's invites/applications |
| `applications` | `jobId` ASC, `mazdoorId` ASC | Duplicate-invite guard |
| `applications` | `mazdoorId` ASC, `createdAt` DESC | Mazdoor's invites |
| `progressLogs` | `jobId` ASC, `createdAt` DESC | Job photo timeline |
| `wageLedger` | `jobId` ASC, `createdAt` DESC | Worker ledger view |
| `wageLedger` | `mazdoorId` ASC, `createdAt` DESC | `GET /api/ledger/mine` |
| `ratings` | `rateeId` ASC, `createdAt` DESC | Public reputation feed |
| `notifications` | `userId` ASC, `createdAt` DESC | Inbox |
| `deviceTokens` | `userId` ASC | Fan-out for FCM |

Proximity ranking is computed in the backend matching engine (Firestore has no native radius query); candidate pre-filtering uses `availability == true` and trade overlap with the job's `tradesRequired`.

---

## 4. Security Rules Summary

- **Auth required:** all reads/writes require a valid Firebase Auth session.
- `users/{uid}`: the owner has full read/write; other authenticated users have **read-only** access to non-sensitive fields (phone and cnic masked — enforced in API responses, not rules).
- `jobs`: anyone authenticated can read `open` jobs; only the owning builder (`builderId == auth.uid`) can create/update/delete; assigned mazdoors can read their jobs.
- `applications`: readable by the job's builder and the mazdoor; builder creates invites (`invited`); the invited mazdoor responds (accept/decline); builder may `removed`.
- `progressLogs`: readable by job participants; writable by the builder or an assigned worker of that job.
- `wageLedger`: readable by job participants (mazdoors additionally read their own entries across jobs via `/api/ledger/mine`); writable by the job's builder only; only the builder may toggle `paid`.
- `ratings`: readable by all; writable once per (job, rater, ratee) by the rater, only when job is `completed`/`closed`, and never self-ratings.
- `notifications`, `deviceTokens`: owner-only read/write.
- All writes validate field types and enum values (`role`, job `status`, application `status`, `stars` range).
