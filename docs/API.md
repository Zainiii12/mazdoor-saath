# REST API Reference — Mazdoor Sathi

**Version:** 1.0 — October 2026
Base URL: `http://<host>:5000/api`

## Conventions

- **Auth:** All endpoints except `GET /health` and the public reads
  (`GET /api/users/:id`, `GET /api/users/:id/ratings`,
  `GET /api/jobs` without `mine=true`, `GET /api/jobs/:id`) require
  `Authorization: Bearer <Firebase ID token>`.
- **Content type:** `application/json`.
- **Dates** are `YYYY-MM-DD` strings; money is PKR (number).
- **Response envelope** — every response uses one shape:

  ```json
  { "ok": true,  "data": <payload>, "error": null }
  { "ok": false, "data": null,      "error": { "message": "…", "details": […] } }
  ```

- **Error codes:** `400` validation, `401` missing/invalid token,
  `403` not owner/party, `404` not found, `409` illegal state/transition.

---

## 1. Users

### `POST /api/users/profile` ✅
Create or update the caller's profile (builder or mazdoor).

Request:
```json
{ "name": "Rashid Ali", "role": "mazdoor", "phone": "03001234567",
  "trades": ["Mason"], "skills": ["brickwork"], "dailyWage": 1500,
  "lat": 32.49, "lng": 74.53, "city": "Gujrat",
  "availability": true, "yearsExperience": 8, "cnic": "34101-…" }
```
Rules: `name` required; `role` must be `builder`|`mazdoor`;
`yearsExperience` must be a non-negative number when present.
First save initialises `ratingAvg`, `ratingCount`, `completedJobs` to 0.

Success `201` (new) / `200` (updated):
```json
{ "id": "uid_maz_7", "uid": "uid_maz_7", "name": "Rashid Ali",
  "phone": "03001234567", "role": "mazdoor", "trades": ["Mason"],
  "skills": ["brickwork"], "dailyWage": 1500,
  "location": { "lat": 32.49, "lng": 74.53 }, "city": "Gujrat",
  "availability": true, "yearsExperience": 8,
  "ratingAvg": 0, "ratingCount": 0, "completedJobs": 0,
  "createdAt": "…", "updatedAt": "…" }
```
Errors: `400` (validation), `401`.

### `GET /api/users/me` ✅
Own full profile (includes private fields).

Success `200`: profile object as above.
Errors: `401`, `404` (no profile — create via `POST /api/users/profile`).

### `GET /api/users/:id`
Public profile + rating summary. Hides `phone` and `cnic`.

Success `200`:
```json
{ "id": "uid_maz_7", "name": "Rashid Ali", "role": "mazdoor",
  "trades": ["Mason"], "skills": ["brickwork"], "dailyWage": 1500,
  "city": "Gujrat", "location": { "lat": 32.49, "lng": 74.53 },
  "availability": true, "ratingAvg": 4.3, "ratingCount": 12,
  "completedJobs": 5, "createdAt": "…" }
```
Errors: `404`.

### `POST /api/users/me/device-token` ✅
Register an FCM token for push notifications.

Request: `{ "token": "fcm_token_xyz", "platform": "android" }`
Success `200`: `{ "registered": true }`.
Errors: `400` (token missing), `401`.

---

## 2. Jobs

Job object:
```json
{ "id": "job_abc", "builderId": "uid_b_1", "title": "House grey structure",
  "description": "…",
  "tradesRequired": [{ "trade": "Mason", "count": 2, "wageOffer": 1500 }],
  "tradeList": ["Mason"],
  "siteLocation": { "lat": 32.50, "lng": 74.54 }, "city": "Gujrat",
  "startDate": "2026-10-10", "expectedDays": 20,
  "status": "open",
  "assignedTeam": [{ "mazdoorId": "uid_maz_7", "trade": "Mason", "dailyWage": 1500 }],
  "assignedTeamIds": ["uid_maz_7"],
  "createdAt": "…", "updatedAt": "…" }
```

**Status flow** (enforced on `PATCH`):

```
draft → open | cancelled
open → assigned | cancelled
assigned → in_progress | cancelled
in_progress → completed | cancelled
completed → closed
```

### `POST /api/jobs` ✅
Builder creates a job posting.

Request:
```json
{ "title": "House grey structure", "description": "Double-storey…",
  "tradesRequired": [{ "trade": "Mason", "count": 2, "wageOffer": 1500 }],
  "siteLat": 32.50, "siteLng": 74.54, "city": "Gujrat",
  "startDate": "2026-10-10", "expectedDays": 20, "status": "open" }
```
Rules: `title`, non-empty `tradesRequired` (each with `trade`, positive
`count`, non-negative `wageOffer`), `siteLat`/`siteLng`, and `city` are
required. `startDate` must be `YYYY-MM-DD`; `expectedDays` positive.
New jobs start as `draft` or `open` (default `open`).

Success `201`: job object. Errors: `400`, `401`.

### `GET /api/jobs`
List jobs (newest first, max 50). Optional auth.
Filters: `?city=` `?trade=` (matches `tradeList`) `?status=` `?builderId=`.
`?mine=true` **requires auth** and is role-aware: builders get jobs they
posted (`builderId == uid`); mazdoors get jobs they are assigned to
(`assignedTeamIds` contains uid). Unauthenticated + `mine=true` → `401`.

Success `200`: `[job, …]`. Errors: `400` (bad status), `401`.

### `GET /api/jobs/:id`
Job detail. Success `200`: job object. Errors: `404`.

### `PATCH /api/jobs/:id` ✅ owner
Edit fields and/or move the status forward along the status flow above.
Editable while `draft`/`open` only: `title, description, city, startDate,
expectedDays, tradesRequired, siteLat, siteLng`.
Moving to `assigned` **requires** `assignedTeam: [{mazdoorId, trade,
dailyWage?}]` — each mazdoor must have an **accepted** application for
the job.

Request: `{ "status": "assigned",
  "assignedTeam": [{ "mazdoorId": "uid_maz_7", "trade": "Mason", "dailyWage": 1500 }] }`
Success `200`: updated job.
Errors: `400`/`409` (illegal transition, missing/invalid assignedTeam),
`401`, `403`, `404`.

### `DELETE /api/jobs/:id` ✅ owner
Delete a job — draft jobs only.

Success `200`: `{ "deleted": true, "id": "job_abc" }`.
Errors: `403`, `404`, `409` (not a draft — cancel it instead).

---

## 3. Matching

### `GET /api/jobs/:id/matches` ✅
Rank available mazdoors for a job. Query: `radiusKm` (default 25),
`limit` (default 20, max 100).

Weights: **trade match 40 / rating 25 / proximity 25 / wage fit 10**.

Success `200`:
```json
{ "jobId": "job_abc", "radiusKm": 25, "count": 2,
  "matches": [
    { "mazdoor": { "id": "uid_maz_7", "name": "Rashid Ali", "role": "mazdoor",
                   "trades": ["Mason"], "skills": ["brickwork"], "dailyWage": 1500,
                   "city": "Gujrat", "location": { "lat": 32.49, "lng": 74.53 },
                   "availability": true, "ratingAvg": 4.3, "ratingCount": 12,
                   "completedJobs": 5 },
      "distanceKm": 3.2, "score": 87.5,
      "breakdown": { "tradeMatch": 35.0, "rating": 21.5, "proximity": 20.0, "wageFit": 10.0 } }
  ] }
```
Errors: `401`, `404`, `409` (no required trades / no site location).

---

## 4. Applications & Invites

Application object:
```json
{ "id": "app_1", "jobId": "job_abc", "mazdoorId": "uid_maz_7",
  "builderId": "uid_b_1", "trade": "Mason", "wageOffer": 1500,
  "status": "invited", "createdAt": "…", "updatedAt": "…", "respondedAt": null }
```
Statuses: `invited | accepted | declined | removed`.
Flow: builder invites (`POST …/invite`) → mazdoor accepts/declines
(`POST …/respond`). Accepted applications back the `assignedTeam` when a
job moves to `assigned`.

### `POST /api/jobs/:id/invite` ✅ owner
Invite a mazdoor (job must be `open`; mazdoor must exist with role
`mazdoor`; no duplicate active invite for the pair).

Request: `{ "mazdoorId": "uid_maz_7", "trade": "Mason", "wageOffer": 1500 }`
Success `201`: application object.
Errors: `400`, `401`, `403`, `404`, `409` (job not open / duplicate invite).

### `GET /api/jobs/:id/applications` ✅ owner
All applications for a job. Success `200`: `[application, …]`.
Errors: `401`, `403`, `404`.

### `GET /api/applications/:id` ✅
One application — only the job's `builderId` or the `mazdoorId`.
Success `200`: application object. Errors: `401`, `403`, `404`.

### `POST /api/applications/:id/respond` ✅ mazdoor
Accept or decline an invitation (only the invited mazdoor, only while
`invited`).

Request: `{ "action": "accept" }` or `{ "action": "decline" }`
Success `200`: updated application (`status: accepted|declined`,
`respondedAt` set). Errors: `400`, `401`, `403`, `404`, `409`.

### `GET /api/users/me/applications` ✅
The caller's own invitations. Success `200`: `[application, …]`.
Errors: `401`.

---

## 5. Progress Log

Log object:
```json
{ "id": "log_21", "jobId": "job_abc", "authorId": "uid_maz_7",
  "authorRole": "mazdoor", "date": "2026-10-05", "note": "Ground floor walls done",
  "photoUrls": ["https://…/p1.jpg"], "percentComplete": 40,
  "approved": null, "flagged": false, "createdAt": "…" }
```
`approved: null` = pending builder review.

### `POST /api/jobs/:id/progress` ✅ party
Post a daily log entry (job owner or assigned worker).

Request:
```json
{ "date": "2026-10-05", "note": "Ground floor walls done",
  "photoUrls": ["https://…/p1.jpg"], "percentComplete": 40 }
```
Rules: `date` required as `YYYY-MM-DD`; `percentComplete` required,
0–100; `photoUrls` must be an array when present.
Success `201`: log object. Errors: `400`, `401`, `403`, `404`.

### `GET /api/jobs/:id/progress` ✅ party
Timeline, newest first. Success `200`: `[log, …]`.
Errors: `401`, `403`, `404`.

### `PATCH /api/progress/:logId` ✅ owner
Builder approves or flags an entry.

Request: `{ "approved": true }` / `{ "approved": false }` / `{ "flagged": true }`
(`approved` may be `true|false|null`; `flagged` boolean).
Success `200`: updated log. Errors: `400`, `401`, `403`, `404`.

"party" = job owner or an assigned worker.

---

## 6. Wage Ledger

Entry object:
```json
{ "id": "led_44", "jobId": "job_abc", "mazdoorId": "uid_maz_7",
  "date": "2026-10-06", "daysWorked": 1, "dailyWage": 1500,
  "advance": 0, "deduction": 0, "gross": 1500, "net": 1500,
  "paid": false, "paidAt": null, "note": "Day 3 wage",
  "createdBy": "uid_b_1", "createdAt": "…" }
```
`gross = daysWorked × dailyWage`; `net = gross − advance − deduction`.

### `POST /api/jobs/:id/ledger` ✅ owner
Record a wage entry.

Request:
```json
{ "mazdoorId": "uid_maz_7", "date": "2026-10-06", "daysWorked": 1,
  "dailyWage": 1500, "advance": 0, "deduction": 0, "paid": false,
  "note": "Day 3 wage" }
```
Rules: `mazdoorId` required; `date` required as `YYYY-MM-DD`;
`daysWorked` positive; `dailyWage` non-negative; `advance`/`deduction`
non-negative.
Success `201`: entry object. Errors: `400`, `401`, `403`, `404`.

### `GET /api/jobs/:id/ledger` ✅ party
Entries + per-worker and job totals.

Success `200`:
```json
{ "jobId": "job_abc",
  "entries": [ { …entry… } ],
  "perWorker": [ { "mazdoorId": "uid_maz_7", "daysWorked": 3, "gross": 4500,
                   "advance": 1000, "deduction": 0, "net": 3500,
                   "paidAmount": 1500, "entries": 3, "balance": 2000 } ],
  "totals": { "daysWorked": 3, "gross": 4500, "advance": 1000, "deduction": 0,
              "net": 3500, "paidAmount": 1500, "balance": 2000 } }
```
(`balance` = still owed to the worker.) Errors: `401`, `403`, `404`.

### `GET /api/ledger/mine` ✅
The caller's own ledger entries across all jobs (`mazdoorId == uid`),
newest first, same entry shape as the per-job GET.
Success `200`: `[entry, …]`. Errors: `401`.

### `PATCH /api/ledger/:entryId` ✅ owner
Mark an entry paid/unpaid.

Request: `{ "paid": true }`
Success `200`: updated entry (`paidAt` set/cleared).
Errors: `400` (paid must be boolean), `401`, `403`, `404`.

---

## 7. Ratings

Rating object:
```json
{ "id": "rat_5", "jobId": "job_abc", "raterId": "uid_b_1",
  "rateeId": "uid_maz_7", "raterRole": "builder", "stars": 5,
  "comment": "Excellent brickwork", "createdAt": "…" }
```

### `POST /api/jobs/:id/ratings` ✅ party
Rate the other party — only after the job is `completed`/`closed`, only
builder ↔ assigned worker, one rating per (rater, job, ratee). Updates the
ratee's `ratingAvg`/`ratingCount` transactionally.

Request: `{ "rateeId": "uid_maz_7", "stars": 5, "comment": "Excellent brickwork" }`
Rules: `stars` integer 1–5; no self-rating.
Success `201`: rating object.
Errors: `400`, `401`, `403`, `404`, `409` (job not completed / already rated).

### `GET /api/users/:id/ratings`
Public list of ratings received by a user (newest first, max 50).
Success `200`: `[rating, …]`.

---

## 8. Notifications

### `POST /api/notify` ✅
Send an FCM push to one or more users; an inbox copy is stored per
recipient.

Request:
```json
{ "userIds": ["uid_maz_7"], "title": "New invite",
  "body": "You were invited to House grey structure",
  "data": { "jobId": "job_abc" } }
```
(`data` values are stringified for FCM.)
Success `200`:
```json
{ "notificationsStored": 1, "tokensTargeted": 2, "sent": 2, "failed": 0 }
```
Dead FCM tokens are pruned automatically.
Errors: `400` (userIds/title/body missing), `401`.

### `GET /api/users/me/notifications` ✅
The caller's inbox, newest first (max 50). `?unread=true` filters unread.

Success `200`:
```json
[ { "id": "n_3", "userId": "uid_maz_7", "title": "New invite",
    "body": "…", "data": { "jobId": "job_abc" }, "read": false,
    "createdAt": "…" } ]
```
Errors: `401`.

### `PATCH /api/notifications/:id/read` ✅
Mark one notification as read (own inbox only).
Success `200`: updated notification. Errors: `401`, `403`, `404`.

---

## 9. Endpoint Index (quick reference)

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | /api/users/profile | ✅ | Create/update own profile |
| GET | /api/users/me | ✅ | Own full profile |
| GET | /api/users/:id | – | Public profile |
| POST | /api/users/me/device-token | ✅ | Register FCM token |
| GET | /api/users/me/applications | ✅ | Own invitations |
| GET | /api/users/me/notifications | ✅ | Notification inbox |
| PATCH | /api/notifications/:id/read | ✅ | Mark notification read |
| POST | /api/jobs | ✅ | Post a job |
| GET | /api/jobs | – / ✅ for mine=true | List/filter jobs |
| GET | /api/jobs/:id | – | Job detail |
| PATCH | /api/jobs/:id | ✅ owner | Edit fields / status transitions |
| DELETE | /api/jobs/:id | ✅ owner | Delete draft job |
| GET | /api/jobs/:id/matches | ✅ | Ranked mazdoor matches |
| POST | /api/jobs/:id/invite | ✅ owner | Invite a mazdoor |
| GET | /api/jobs/:id/applications | ✅ owner | Job's applications |
| GET | /api/applications/:id | ✅ party | Single application |
| POST | /api/applications/:id/respond | ✅ mazdoor | Accept / decline invite |
| POST | /api/jobs/:id/progress | ✅ party | Daily progress log |
| GET | /api/jobs/:id/progress | ✅ party | Progress timeline |
| PATCH | /api/progress/:logId | ✅ owner | Approve / flag entry |
| POST | /api/jobs/:id/ledger | ✅ owner | Record wage entry |
| GET | /api/jobs/:id/ledger | ✅ party | Ledger + totals |
| GET | /api/ledger/mine | ✅ | Own ledger entries (all jobs) |
| PATCH | /api/ledger/:entryId | ✅ owner | Mark entry paid/unpaid |
| POST | /api/jobs/:id/ratings | ✅ party | Rate after completion |
| GET | /api/users/:id/ratings | – | Ratings received |
| POST | /api/notify | ✅ | Send FCM + store inbox copies |

"party" = job owner or an assigned worker.
