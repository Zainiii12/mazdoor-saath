# Mazdoor Sathi

**A Skill-Based Team Hiring and Progress-Tracking Platform for Construction Labor**

Final Year Project — Department of Computer Science, Faculty of Computing & IT, University of Gujrat.

Mazdoor Sathi is a mobile platform that connects **builders/homeowners** with **construction laborers (mazdoors)** such as masons, electricians, plumbers, painters, and general laborers. A builder posts a construction requirement specifying trades, team size, location, and expected duration; the system matches the requirement with suitable nearby mazdoors using trade match (**40**), rating (**25**), proximity (**25**), and wage fit (**10**). A single job can request **multiple workers across multiple trades** (team hiring). Once a team is hired, the platform supports job status updates, daily photo-based progress logs, ratings, and a transparent digital wage ledger. **Urdu speech-to-text** is integrated for selected interactions to support users with limited text literacy.

## Architecture at a Glance

Three-tier client–server architecture:

| Tier | Technology | Responsibility |
|---|---|---|
| Presentation | Flutter (Dart) | Builder & mazdoor mobile UIs, OSM maps, Urdu voice input |
| Business logic | Node.js + Express.js | Auth, job management, matching engine, REST API |
| Data | Firebase Firestore | Real-time storage: profiles, jobs, applications, progress, ledger |
| Maps & location | OpenStreetMap (flutter_map) | Job-site and worker location visualization |
| Voice input | Urdu speech-to-text service | Voice-assisted job posting & acceptance |
| Notifications | Firebase Cloud Messaging (FCM) | Job invites, acceptance, status changes, payments |
| Version control | Git / GitHub | Source control |

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full architecture, request flows, and the matching algorithm.

## Data Model (Firestore)

Collections — full schemas in [docs/DATABASE.md](docs/DATABASE.md): `users`, `jobs`, `applications`, `progressLogs`, `wageLedger`, `ratings`, `notifications`, `deviceTokens`.

## Repository Layout

```
mazdoor-sathi/
├── README.md                 # This file
├── app/                      # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/           # Data models (User, Job, Application, ...)
│   │   ├── screens/
│   │   │   ├── builder/      # Post job, matches, invites, ledger, ratings
│   │   │   └── mazdoor/      # Job invites, my jobs, progress log, earnings
│   │   ├── services/         # ApiService, AuthService, LocationService,
│   │   │                     # SpeechService (Urdu STT), NotificationService
│   │   └── widgets/          # Reusable UI components
│   └── pubspec.yaml
├── backend/                   # Node.js + Express API
│   ├── src/
│   │   ├── index.js          # App entry point
│   │   ├── config/           # Firebase Admin SDK init
│   │   ├── middleware/       # Firebase ID-token auth
│   │   ├── routes/           # users, jobs, applications, progress,
│   │   │                     # ledger, ratings, notifications
│   │   └── utils/            # haversine.js, http.js (envelope/helpers)
│   ├── package.json
│   └── .env.example
└── docs/
    ├── SRS.md                # Software Requirements Specification
    ├── DATABASE.md           # Firestore data model & security rules
    ├── API.md                # REST API reference
    └── ARCHITECTURE.md       # Architecture, flows, matching algorithm, tests
```

## Quick Start

### Backend (Node.js / Express)

Prerequisites: Node.js 18+, a Firebase project with Firestore enabled, a Firebase service-account key.

```bash
cd backend
cp .env.example .env        # fill in FIREBASE_PROJECT_ID, service account path, PORT
npm install
npm run dev                 # starts API on http://localhost:5000
```

The API base URL is `http://localhost:5000/api`. Auth is Firebase phone sign-in in the app; the backend verifies the Firebase ID token — all API endpoints except `GET /health` and a few public reads require it in the `Authorization: Bearer <token>` header. Full endpoint reference: [docs/API.md](docs/API.md).

### Flutter App

Prerequisites: Flutter SDK 3.x, Android Studio / VS Code.

```bash
cd app
flutter pub get
flutter run                 # select an emulator or connected device
```

Point `ApiService.baseUrl` at your backend (use `http://10.0.2.2:5000/api` for the Android emulator). Configure `google-services.json` for FCM and the Urdu speech-to-text API key per `docs/ARCHITECTURE.md`.

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (Dart), flutter_map (OpenStreetMap), speech_to_text (Urdu `ur-PK`) |
| Backend | Node.js, Express.js |
| Database | Firebase Firestore (real-time) |
| Auth | Firebase Authentication (phone), ID-token verification on backend |
| Maps / location | OpenStreetMap + Nominatim geocoding |
| Voice input | Urdu speech-to-text API/service |
| Push notifications | Firebase Cloud Messaging |
| Prototyping | Figma |
| VCS | Git / GitHub |

## Estimated Cost

From the approved FYP proposal — the project uses free-tier and open-source technologies:

| Item | Type | Estimated Cost (PKR) |
|---|---|---|
| Flutter, VS Code, Git/GitHub | Software | 0 |
| Firebase free tier | Cloud service | 0 |
| OpenStreetMap | Mapping | 0 |
| Speech-to-text testing | API | 0 – 2,000 |
| Optional domain/hosting | Hosting | 1,500 – 3,000 |
| Internet, printing, miscellaneous | Miscellaneous | 3,000 – 5,000 |
| **Total** | | **Approx. 5,000 – 10,000** |

## Milestones → Repo Map (18-week timeline)

| Weeks | Milestone (per proposal) | Primary repo area |
|---|---|---|
| 1–3 | Requirements & SRS | `docs/SRS.md` |
| 3–4 | Architecture & database design | `docs/ARCHITECTURE.md`, `docs/DATABASE.md` |
| 5–6 | UI/UX design | `app/lib/screens`, Figma prototypes |
| 7–9 | Builder module | `app/lib/screens/builder`, `backend/src/routes/jobs.js` |
| 10–11 | Mazdoor module | `app/lib/screens/mazdoor`, `backend/src/routes/applications.js` |
| 12 | Location & maps | `app/lib/services/LocationService`, OSM integration |
| 13 | Voice input | `app/lib/services/SpeechService` (Urdu STT) |
| 14–15 | Progress, ratings & wage ledger | `backend/src/routes/progress.js`, `ledger.js`, `ratings.js` |
| 16–18 | Testing & documentation | `docs/`, test scenarios TS-1..TS-6 in `docs/ARCHITECTURE.md` |

## Team & Credits

| Role | Name |
|---|---|
| Developer (sole group member) | **Muhammad Zayan Nadeem** (23821519-001), BS Computer Science |
| Supervisor | **Ms Ayesha Rashid**, Department of Computer Science, Faculty of Computing & IT, University of Gujrat (ayesha.rashid@uog.edu.pk) |

All responsibilities — requirements analysis, system architecture, database design, Flutter development, backend/API development, authentication, job matching, location integration, voice-input integration, progress tracking, testing, documentation, and deployment — are carried out by the single group member, per the approved proposal.

## Documentation Index

- [docs/SRS.md](docs/SRS.md) — Software Requirements Specification
- [docs/DATABASE.md](docs/DATABASE.md) — Firestore data model
- [docs/API.md](docs/API.md) — REST API reference
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Architecture, matching algorithm, test plan
