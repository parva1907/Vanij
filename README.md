# Vanij (वणिज्)

> **Built for the backbone of India.**
> A lightweight Local Merchant Command Center for Indian clothing/fashion retail shops.

## Monorepo layout

```
vanij/
├── app/          # Flutter 3.x app (Dart, Riverpod, GoRouter)
├── functions/    # Firebase Cloud Functions (Node 20, TypeScript)
├── ai/           # Python 3.11 FastAPI service (Cloud Run) — vision + LLM agent
└── firebase/     # Firebase rules & indexes (deployed via Firebase CLI)
```

## Stack (strict — no substitutions)

| Layer            | Tech                                                   |
|------------------|--------------------------------------------------------|
| Frontend         | Flutter 3.x                                            |
| State            | Riverpod (no `setState` in screens)                    |
| Navigation       | GoRouter                                               |
| Auth             | Firebase Auth (email + Google)                         |
| Database         | Cloud Firestore                                        |
| Storage          | Firebase Cloud Storage                                 |
| Cloud Functions  | Node 20                                                |
| AI backend       | Python 3.11 FastAPI on Cloud Run                       |
| Vision AI        | CNN/ViT (PyTorch)                                      |
| LLM agent        | Claude Sonnet (read-only Firestore access)             |
| Payments         | Razorpay SDK                                           |

## Sprint plan

1. **Sprint 1** ✅ Firebase Auth + Firestore rules + folder structure
2. **Sprint 2** ✅ Inventory CRUD (no AI yet) + image upload
3. **Sprint 3** ✅ Python FastAPI skeleton + auth middleware + health check
4. **Sprint 4** ✅ Vision service + TagConfirmScreen
5. **Sprint 5** ✅ Finance module (ledger + UPI log)
6. **Sprint 6** ✅ CRM chat UI (no agent yet)
7. **Sprint 7** ✅ LLM agent + Cloud Function trigger
8. **Sprint 8** ✅ Telemetry (Crashlytics + Analytics), structured logging, release signing, full-history gitleaks

See [`docs/SPRINTS.md`](docs/SPRINTS.md) for the per-sprint delivery log and [`docs/RELEASE.md`](docs/RELEASE.md) for the production-release checklist.

## Security guarantees

- Firestore/Storage rules default-deny — every collection explicitly allow-listed.
- No hardcoded secrets anywhere. Flutter reads `PYTHON_BACKEND_URL` via `--dart-define`; backend reads secrets from Google Cloud Secret Manager / env.
- Customer phone & UPI reference encrypted AES-256 before write.
- LLM agent: read-only Firestore access, no write tools.
- AI vision tags are drafts — every tag confirmed on `TagConfirmScreen` before Firestore write.

## Getting started

### Prerequisites

- Flutter 3.x + Dart 3.x
- Node 20 + npm
- Python 3.11 + pip
- Firebase CLI (`npm i -g firebase-tools`)

### Flutter app

```bash
cd app
flutter pub get
flutter run --dart-define=PYTHON_BACKEND_URL=http://10.0.2.2:8000
```

The `--dart-define=PYTHON_BACKEND_URL=...` flag is required — the app refuses to start without it.

### Cloud Functions

```bash
cd functions
cp .env.example .env   # fill in locally, never commit
npm install
npm run build
```

### AI backend

```bash
cd ai
cp .env.example .env   # fill in locally, never commit
pip install -e .
uvicorn app.main:app --reload
```

### Firebase

```bash
cd firebase
firebase deploy --only firestore:rules,firestore:indexes,storage:rules
```

## APK size target

Under 25 MB. Always build with `--split-per-abi`:

```bash
cd app
flutter build apk --release --split-per-abi
```
