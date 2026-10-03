# Software Requirements Specification (SRS)
## Mazdoor Sathi: A Skill-Based Team Hiring and Progress-Tracking Platform for Construction Labor

**Version:** 1.0 — October 2026
**Author:** Muhammad Zayan Nadeem (23821519-001), BS Computer Science
**Supervisor:** Ms Ayesha Rashid, Department of Computer Science, Faculty of Computing & IT, University of Gujrat

---

## 1. Introduction

### 1.1 Purpose
This document specifies the software requirements for **Mazdoor Sathi**, a Final Year Project that digitizes informal construction-labor hiring in Pakistan. It is intended for the developer, the project supervisor, and the FYP evaluation committee, and serves as the baseline for design, implementation, and testing.

### 1.2 Scope
Mazdoor Sathi is a mobile application (Flutter) backed by a Node.js/Express API and Firebase Firestore. It covers:

- Builder and mazdoor registration with role-based profiles
- Job posting with **multi-trade team requests** (e.g., 2 masons + 1 electrician in one job)
- Skill / rating / availability / proximity-based worker matching
- Invite → accept / reject flow between builders and mazdoors
- Job status lifecycle tracking
- Worker location tracking on OpenStreetMap
- Daily photo-based progress logs
- Digital wage ledger (agreed wages, advances, payments)
- Two-way rating and reputation system
- Urdu speech-to-text for selected interactions
- Push notifications (FCM) for job events

Out of scope: in-app payments/money transfer, background checks, government labor-law compliance automation, and web admin panel (may be considered as future work).

### 1.3 Definitions
| Term | Meaning |
|---|---|
| Mazdoor | Construction laborer (mason, electrician, plumber, painter, general laborer) |
| Builder | Homeowner, builder, or small contractor posting jobs |
| Team hiring | One job requesting multiple workers, possibly across trades |
| Match score | Weighted score (0–100) ranking a mazdoor's suitability for a job |
| Wage ledger | Digital record of agreed wages, advances, deductions, and payments per job |

### 1.4 References
- Approved FYP proposal, "Mazdoor Sathi", September 23, 2026
- `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `docs/API.md` (this repository)

---

## 2. Stakeholders

| Stakeholder | Interest |
|---|---|
| Builders / Homeowners | Find verified, skilled workers quickly; track progress; keep clean payment records |
| Mazdoors | Receive job opportunities matching their trade; build a portable reputation; avoid wage disputes |
| Small Contractors / Supervisors | Coordinate workers across one or more job sites |
| Developer (Muhammad Zayan Nadeem) | Design, build, test, and document the system |
| Supervisor (Ms Ayesha Rashid) | Academic guidance and evaluation |
| FYP Evaluation Committee | Assess the project against its objectives |

---

## 3. Functional Requirements

### 3.1 User Management
- **FR-1** The system shall allow a user to register with name, phone number, and role (`builder` or `mazdoor`) via Firebase phone authentication.
- **FR-2** The system shall allow a mazdoor to create a profile listing trades, skills, years of experience, daily-wage expectation, home location (city + map pin), and availability status.
- **FR-3** The system shall allow a builder to create a profile with name, phone, and city.
- **FR-4** The system shall allow any user to update their profile and toggle availability (mazdoors).
- **FR-5** The system shall authenticate API requests using Firebase ID tokens.

### 3.2 Job Posting & Team Requests
- **FR-6** The system shall allow a builder to post a job with title, description, site location (map pin + address), start date, and expected duration in days.
- **FR-7** The system shall allow a job to contain **multiple trade requirements**, each specifying trade, number of workers needed, and offered daily wage.
- **FR-8** The system shall allow a builder to edit or cancel a job while its status is `draft` or `open` (draft jobs may also be deleted).
- **FR-9** The system shall move a job through the status lifecycle: `draft` → `open` → `assigned` → `in_progress` → `completed` → `closed`, with `cancelled` reachable from `draft`/`open`/`assigned`/`in_progress`. Moving to `assigned` requires an `assignedTeam` whose members each hold an accepted application.

### 3.3 Matching
- **FR-10** The system shall compute a match score (0–100) for candidate mazdoors per job, based on trade coverage (**40**), average rating (**25**), proximity to the job site (**25**), and wage fit (**10**), returned as `score` with a per-component `breakdown` (`tradeMatch`, `rating`, `proximity`, `wageFit`).
- **FR-11** The system shall return ranked candidate lists for a job, excluding mazdoors with no trade overlap, no location, or outside the search radius.

### 3.4 Invite & Application Flow
- **FR-12** The system shall allow a builder to invite one or more matched mazdoors to a specific trade requirement of a job.
- **FR-13** The system shall allow an invited mazdoor to **accept** or **decline** an invite while it is `invited`.
- **FR-14** The system shall allow a mazdoor to apply directly to an `open` job. *(Not yet implemented in the API — invites are currently builder-initiated only.)*
- **FR-15** The system shall notify (FCM + in-app) the mazdoor on invite and the builder on accept/reject.

### 3.5 Location Tracking
- **FR-16** The system shall allow a mazdoor to share live location during an `in_progress` job. *(Not yet implemented in the API — only profile-level `users.location` exists.)*
- **FR-17** The system shall display hired workers and the job site on an OpenStreetMap view for the builder.

### 3.6 Daily Progress Log
- **FR-18** The system shall allow a mazdoor (or supervisor) to submit a daily progress entry with at least one site photo, a text/voice note, and the date.
- **FR-19** The system shall allow the builder to view the chronological photo progress log of a job.

### 3.7 Wage Ledger
- **FR-20** The system shall record the agreed daily wage per hired mazdoor in the job's `assignedTeam` when the job moves to `assigned`.
- **FR-21** The system shall allow the builder to record wage entries (days worked, daily wage, advances, deductions) against a mazdoor for a job, with server-computed `gross` and `net`.
- **FR-22** The system shall allow the builder to mark a ledger entry as `paid` (with `paidAt`); the mazdoor can view their own entries across all jobs. *(Payment confirmation/dispute by the mazdoor is not yet implemented.)*
- **FR-23** The system shall compute per-mazdoor and per-job totals: `net`, `paidAmount`, and `balance` (outstanding).

### 3.8 Ratings & Reputation
- **FR-24** The system shall allow a builder to rate each hired mazdoor (1–5 stars + comment) after job completion.
- **FR-25** The system shall allow a mazdoor to rate the builder (1–5 stars + comment) after job completion.
- **FR-26** The system shall update each user's average rating and rating count, and use the average rating as an input to matching.

### 3.9 Urdu Voice Input
- **FR-27** The system shall provide Urdu (`ur-PK`) speech-to-text input for the job description field during job posting and for the accept/confirm action on invites.
- **FR-28** The system shall allow the user to review and edit transcribed text before submitting.

### 3.10 Notifications
- **FR-29** The system shall send push notifications (FCM) for: new invite, invite accepted/rejected, job status changes, new progress entry, payment recorded/confirmed, and new rating received.
- **FR-30** The system shall maintain an in-app notification inbox with read/unread state.

---

## 4. Non-Functional Requirements

### 4.1 Performance
- **NFR-1** Match-score computation for a job shall complete within 3 seconds for up to 500 candidate profiles.
- **NFR-2** API read endpoints (p95) shall respond within 800 ms on a 4G connection, excluding photo uploads.
- **NFR-3** Photo uploads shall be compressed client-side (max 1600px, ≤ 500 KB) before upload.

### 4.2 Usability (incl. low-literacy users)
- **NFR-4** Core flows (post job, accept invite, log progress) shall be completable in ≤ 5 taps/screens.
- **NFR-5** The app shall offer Urdu-language labels for primary actions and Urdu voice input (FR-27) for key text fields.
- **NFR-6** Icons and photo-first cards shall supplement text so users with limited reading ability can navigate.

### 4.3 Reliability
- **NFR-7** Firestore's real-time sync shall keep job status and progress logs consistent across builder and mazdoor devices.
- **NFR-8** The app shall cache the user's active jobs for offline viewing; writes shall queue and sync on reconnect.

### 4.4 Security
- **NFR-9** All API access shall require a valid Firebase ID token; users may only read/write their own data per Firestore security rules (see `docs/DATABASE.md`).
- **NFR-10** Phone numbers and CNIC data shall never be exposed to other users beyond what is needed for coordination (masked phone until hire).
- **NFR-11** Location sharing shall be active only during `in_progress` jobs and only visible to the job's builder.

### 4.5 Maintainability & Portability
- **NFR-12** The Flutter app shall build for Android (primary) from a single codebase.
- **NFR-13** Backend business logic (matching, ledger totals) shall reside in the Express service layer, not in clients.

---

## 5. Use-Case Descriptions

### UC-1: Post Job (multi-trade team request)
- **Actor:** Builder
- **Precondition:** Builder is registered and signed in.
- **Main flow:**
  1. Builder opens "Post Job", enters title, description (optionally via Urdu voice), site location on map, start date, expected days.
  2. Builder adds trade requirements, e.g., Mason ×2 @ Rs 1,500/day, Electrician ×1 @ Rs 1,800/day.
  3. Builder submits; system creates a `jobs` document with status `open` and notifies matching candidates' devices (optional digest).
- **Postcondition:** Job is `open` and visible for matching.

### UC-2: Invite & Accept
- **Actors:** Builder, Mazdoor
- **Precondition:** Job is `open`; candidate list computed (FR-10/FR-11).
- **Main flow:**
  1. Builder views ranked candidates per trade requirement and sends invites.
  2. Builder views ranked candidates and sends invites; each invite creates an `applications` record with status `invited` and notifies the mazdoor (FCM + inbox).
  3. Mazdoor opens invite, reviews wage/site, and accepts (optionally confirming via Urdu voice prompt).
  4. System sets the application status to `accepted` (with `respondedAt`) and notifies the builder.
  5. Builder moves the job to `assigned` with an `assignedTeam` (each member verified against an accepted application), then starts the job → status `in_progress`.
- **Alternate flow:** Mazdoor declines → builder is notified and may invite the next-ranked candidate.

### UC-3: Daily Progress Update
- **Actor:** Mazdoor (or supervisor)
- **Precondition:** Job is `in_progress`; actor is hired on the job.
- **Main flow:**
  1. Mazdoor opens the job, taps "Add today's progress", captures site photo(s).
  2. Adds a short note (typed or Urdu voice), submits.
  3. System stores a `progressLogs` entry; builder receives a notification and can view the photo timeline.
- **Postcondition:** Dated photo entry appended to the job's progress log.

### UC-4: Record Wage Payment
- **Actors:** Builder (records), Mazdoor (confirms)
- **Precondition:** Job is `in_progress` or `completed`; mazdoor is hired on the job.
- **Main flow:**
  1. Builder opens the wage ledger for a worker, records an entry (days worked, daily wage, advance, deduction, note).
  2. System appends a `wageLedger` entry with server-computed `gross`/`net` and notifies the mazdoor.
  3. Builder marks the entry `paid` once settled; totals update for both parties.
- **Postcondition:** Wages, advances, and payments are recorded with running totals.

### UC-5: Rate Worker
- **Actors:** Builder (rates mazdoor); symmetric flow for mazdoor rating builder.
- **Precondition:** Job is `completed`; rater participated in the job; no existing rating by this rater for this ratee on this job.
- **Main flow:**
  1. Builder opens completed job, selects a worker, gives 1–5 stars + comment.
  2. System stores a `ratings` document, recalculates the worker's `ratingAvg`/`ratingCount` on their `users` profile, and notifies the worker.
- **Postcondition:** Worker's public reputation reflects the new rating.

### UC-6: Find Nearby Mazdoors
- **Actor:** Builder
- **Precondition:** Builder has a draft or open job with a site location.
- **Main flow:**
  1. Builder opens "Find mazdoors", optionally filters by trade and radius.
  2. System scores available mazdoors — trade match 40%, rating 25%, proximity 25%, wage fit 10% — and shows ranked cards with name, trades, rating, distance, and daily-wage expectation.
  3. Builder taps a card to view the full profile or send an invite (→ UC-2).
- **Postcondition:** Ranked candidate list displayed; builder can proceed to invite.

---

## 6. Requirements Traceability (data model)

How the functional requirements map to Firestore collections/fields (schemas in `docs/DATABASE.md`):

| Requirement(s) | Collections / key fields |
|---|---|
| FR-1 – FR-5 | `users` (`role`, `phone`, `trades`, `skills`, `dailyWage`, `availability`, `city`, `location`, `yearsExperience`), `deviceTokens` |
| FR-6 – FR-9 | `jobs` (`tradesRequired[]`, `siteLocation`, `status`: `draft` → `open` → `assigned` → `in_progress` → `completed` → `closed` / `cancelled`) |
| FR-10 – FR-11 | `users` → computed `score` + `breakdown` (`tradeMatch`, `rating`, `proximity`, `wageFit`) (not stored; see `docs/ARCHITECTURE.md` §3) |
| FR-12 – FR-15 | `applications` (`status`: `invited` → `accepted` / `declined` / `removed`, `respondedAt`), `notifications` |
| FR-16 – FR-17 | `users.location` (profile-level pin; see FR-16 implementation note) |
| FR-18 – FR-19 | `progressLogs` (`date`, `photoUrls[]`, `note`, `percentComplete`, `approved`, `flagged`) |
| FR-20 – FR-23 | `jobs.assignedTeam[]` (agreed wages), `wageLedger` (`daysWorked`, `dailyWage`, `advance`, `deduction`, `gross`, `net`, `paid`), computed totals (`net`, `paidAmount`, `balance`) |
| FR-24 – FR-26 | `ratings` → `users.ratingAvg` / `users.ratingCount` |
| FR-27 – FR-28 | client-side transcription into `jobs.description` / invite confirmation (reviewed before submit) |
| FR-29 – FR-30 | `notifications` (`read`) + FCM via `deviceTokens` |

## 7. Assumptions & Constraints

**Assumptions**
1. Users have Android smartphones with camera, GPS, and intermittent internet access.
2. Firebase free-tier quotas are sufficient for prototype-scale testing.
3. Urdu speech-to-text service supports the `ur-PK` locale with acceptable accuracy for short phrases.
4. Simulated worker/job data is acceptable for prototype testing (per proposal objective 8).

**Constraints**
1. Single developer; 18-week semester timeline (see README milestone map).
2. Zero/low budget: only free-tier and open-source services (total ≈ PKR 5,000–10,000).
3. Firestore free-tier limits on reads/writes; match queries must use indexed, bounded queries.
4. Location tracking requires explicit user consent and runs only during active jobs.
5. The prototype targets Android first; iOS is not a deliverable.
