# Mazdoor Sathi — Backend Testing Guide

Integration tests for the Express API (`src/`) use **node:test + supertest**
(`tests/api.test.js`, 37 tests across 7 suites).

## Quick start (default — no setup needed)

```bash
cd backend
npm install   # once; includes supertest as a dev dependency
npm test
```

`npm test` runs the suite against an **in-memory Firestore stand-in**
(`tests/fake-firestore.js`, enabled via `FIRESTORE_FAKE=true`). No Java,
emulator, Firebase project or credentials are needed — the whole suite runs
in about a second. It exercises the real Express routes, the real auth
middleware and the real Firestore query patterns the routes use (`==`,
`array-contains`, `in`, `orderBy`, `limit`, batches, transactions,
`serverTimestamp`).

## Alternative: run against the real Firestore emulator

If you want the suite to talk to actual Firestore semantics:

```bash
# 1. Start the emulator (needs Java 21+)
npx -y firebase-tools@latest emulators:start --only firestore --project demo-test

# 2. Run the suite against it
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-test \
ALLOW_TEST_AUTH=true npm run test:emulator
```

> **Sandbox note (Muse VM):** the Admin SDK connects to the emulator over
> **gRPC (HTTP/2)**. This sandbox's network filter blocks non-HTTP(S) TCP by
> default ("Direct network protocols → other_tcp: Deny"), so every Firestore
> call fails with `14 UNAVAILABLE … Protocol error`. Plain HTTP checks like
> `curl http://127.0.0.1:8080/` still return 200, which is misleading — the
> failing symptom is always the gRPC `Protocol error`. Either switch
> **other_tcp** to **Ask** in Muse settings → Permissions → Direct network
> protocols, or just use the default `npm test` (in-memory) path above.
> If your shell exports proxy variables, strip them for the emulator run —
> grpc-js must reach the emulator directly:
>
> ```bash
> env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
>     -u ALL_PROXY -u all_proxy \
>     FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-test \
>     ALLOW_TEST_AUTH=true npm run test:emulator
> ```

## Seed demo data (optional)

```bash
cd backend
SEED=true node scripts/seed.js                        # in-memory (validates seed logic)
# or, with the emulator running:
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-test \
SEED=true node scripts/seed.js
```

Writes 1 builder, 8 mazdoors, 2 jobs, applications, progress logs, ledger
entries, ratings, notifications and a device token. Seed document IDs use the
`seed-*` prefix, so they never collide with the `t-*` IDs used by the test
suite. The script refuses to run without `SEED=true` (or `--confirm`) so it
can never wipe a real project by accident.

## How the tests authenticate

`ALLOW_TEST_AUTH=true` enables a **test-only** bypass in
`src/middleware/auth.js`: requests may carry `Authorization: Test <uid>` and
are treated as that Firebase user. It is inert unless the env flag is set —
production deployments must never set it. The suite also asserts that the
bypass is off without the flag and that garbage `Bearer` tokens are rejected.

## Coverage (`tests/api.test.js`, node:test + supertest)

| Area | What's exercised |
|---|---|
| Users | Profile create/update (`POST /api/users/profile`), validation 400s, public profile hides `phone`/`cnic`, device-token save |
| Jobs | Multi-trade create, list filters (`trade`, `status`, `city`), role-aware `?mine=true`, `PATCH` by owner, status transitions incl. 409 on illegal ones, draft-only `DELETE` |
| Matching | `GET /api/jobs/:id/matches` ranked order, `score` 0–100, breakdown keys `tradeMatch`/`rating`/`proximity`/`wageFit`, `radiusKm` filter |
| Applications & hiring | Invite → 409 duplicate → accept → 409 double-respond → decline → `assigned` → `in_progress` → progress → `completed` → ratings both directions → `closed` |
| Progress | Validation rules, approval flow |
| Ledger | Wage math, totals, mark-paid, `GET /api/ledger/mine` |
| Notifications | `POST /api/notify` → inbox → mark-read (403/404 guards) |
| Auth | 401 on protected routes without token, public reads without token, bypass-off assertion |

Test UIDs (`t-builder-1`, `t-maz-1`, …) are namespaced so reruns and the seed
script can't collide.

## Production notes (not covered by either test path)

- **Composite indexes:** neither the in-memory stand-in nor the emulator
  enforces them. Queries that combine `where` + `orderBy` on different fields
  need composite indexes deployed for production Firestore — watch the server
  logs for index-required errors after deploying.
- **`ALLOW_TEST_AUTH` / `FIRESTORE_FAKE`:** test-only; never set in production.
- **FCM:** `sendEachForMulticast` has no emulator; the suite covers
  notification *persistence/inbox* (the FCM call is stubbed), not delivery.
