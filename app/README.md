# Mazdoor Sathi — Flutter App

Skill-based team hiring and progress-tracking platform connecting
builders/homeowners with construction laborers (mazdoors) in Pakistan.
Final Year Project — Department of Computer Science, University of Gujrat.

## Prerequisites

- Flutter SDK 3.22+ (`flutter doctor` should be green)
- A Firebase project (for Auth, Messaging, Storage)
- The Mazdoor Sathi backend API running and reachable

## 1. Firebase setup

1. Create a Firebase project at https://console.firebase.google.com
2. Enable **Authentication → Phone** sign-in method.
3. Enable **Cloud Messaging** and **Storage**.
4. Install the FlutterFire CLI and generate options:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This creates `lib/firebase_options.dart` (git-ignored template-wise; keep
   your own copy) and updates the Android/iOS config.
   - Manual alternative: drop `google-services.json` into
     `android/app/` and `GoogleService-Info.plist` into `ios/Runner/`,
     then pass the options to `Firebase.initializeApp()` in `lib/main.dart`.
5. For Android, add your SHA-1/SHA-256 fingerprints in the Firebase console
   so Phone Auth works on real devices.

## 2. Install dependencies

```bash
cd app
flutter pub get
```

## 3. Run

The app talks to the backend through `API_BASE_URL` (see
`lib/services/api_client.dart`). Pass it with `--dart-define`:

```bash
# Android emulator talking to a backend on your dev machine:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000

# Physical device / staging server:
flutter run --dart-define=API_BASE_URL=https://api.mazdoorsathi.example.com
```

Default (no define): `http://10.0.2.2:5000`.

## Backend API contract (expected by the app)

All responses use the envelope `{ "ok": true, "data": ... }` or
`{ "ok": false, "error": "..." }`. Every request sends
`Authorization: Bearer <Firebase ID token>`.

| Method | Endpoint | Used for |
|---|---|---|
| POST | `/api/users/profile` | Create/update my profile `{name, role, phone?, trades?, skills?, dailyWage?, lat?, lng?, city?, availability?, cnic?, yearsExperience?}` |
| GET | `/api/users/me` | Load my profile (404 → run setup) |
| GET | `/api/users/:id` | Public profile (hides phone/cnic) |
| POST | `/api/users/me/device-token` | Register FCM token `{token, platform?}` |
| GET | `/api/users/me/applications` | My invitations (mazdoor) |
| GET | `/api/users/me/notifications` | Notification inbox (`?unread=true`) |
| PATCH | `/api/notifications/:id/read` | Mark notification read |
| GET | `/api/jobs?city=&trade=&status=&builderId=&mine=true` | List/filter jobs; `mine=true` (auth) = my posted/assigned jobs |
| POST | `/api/jobs` | Post a job `{title, description?, tradesRequired:[{trade,count,wageOffer}], siteLat, siteLng, city, startDate?, expectedDays?, status?: draft\|open}` |
| GET | `/api/jobs/:id` | Job detail |
| PATCH | `/api/jobs/:id` | Edit fields / status transitions `draft→open→assigned→in_progress→completed→closed` (plus `cancelled`); open→assigned needs `assignedTeam:[{mazdoorId,trade,dailyWage?}]` |
| DELETE | `/api/jobs/:id` | Delete draft jobs only |
| GET | `/api/jobs/:id/matches?radiusKm=25&limit=20` | Ranked mazdoor matches `{jobId, radiusKm, count, matches:[{mazdoor, distanceKm, score, breakdown:{tradeMatch/40, rating/25, proximity/25, wageFit/10}}]}` |
| POST | `/api/jobs/:id/invite` | Invite a mazdoor `{mazdoorId, trade, wageOffer?}` |
| GET | `/api/jobs/:id/applications` | Job's applications (builder only) |
| GET | `/api/applications/:id` | Single application (job owner or invited mazdoor) |
| POST | `/api/applications/:id/respond` | `{action: accept\|decline}` |
| GET | `/api/jobs/:id/progress` | Progress timeline, newest first |
| POST | `/api/jobs/:id/progress` | `{date (YYYY-MM-DD), note?, photoUrls?[], percentComplete}` |
| PATCH | `/api/progress/:logId` | Builder approve/flag `{approved?, flagged?}` |
| GET | `/api/jobs/:id/ledger` | `{entries, perWorker, totals}` |
| POST | `/api/jobs/:id/ledger` | `{mazdoorId, date, daysWorked, dailyWage, advance?, deduction?, paid?, note?}` |
| PATCH | `/api/ledger/:entryId` | `{paid: bool}` |
| GET | `/api/ledger/mine` | Mazdoor's own ledger entries across all jobs |
| POST | `/api/jobs/:id/ratings` | `{rateeId, stars (1-5), comment?}` — only when job completed/closed, parties only |
| GET | `/api/users/:id/ratings` | Ratings received by a user |
| POST | `/api/notify` | Send FCM to `userIds[]` `{title, body, data?}`; stores inbox copy |

## Project layout

```
lib/
  main.dart            # Firebase init, providers, routes, locale (en/ur, RTL)
  models/              # JSON models matching the API envelope
  services/            # api_client, auth, speech (ur-PK), location,
                       # notifications (FCM), storage
  providers/app_state.dart  # current profile, role, locale, selected job
  l10n/strings.dart    # English + Urdu strings, trade names
  screens/common/      # splash, role select, phone auth, setup, profile
  screens/builder/     # home, post job, detail, matches, timeline, ledger, rate
  screens/mazdoor/     # home, invite, active job, earnings, rate builder
  widgets/             # job/worker cards, stars, Urdu mic button, …
```

## Notes

- Maps use OpenStreetMap tiles via `flutter_map` — no API key needed.
- Urdu speech-to-text uses device locale `ur-PK` via `speech_to_text`.
- The app was scaffolded without a local Flutter SDK; run
  `flutter analyze` after `flutter pub get` to verify.
