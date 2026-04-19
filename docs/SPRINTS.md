# Sprint log

## Sprint 1 — Auth + rules + folder structure (this PR)

**Module:** Foundation.

**Delivered:**

- Monorepo skeleton: `app/` (Flutter), `functions/` (Node 20), `ai/` (Python
  3.11 FastAPI), `firebase/` (rules & indexes), `docs/`.
- Flutter app shell with Riverpod, GoRouter, theme (`#1B5E20` / `#F9A825`),
  `Inter` + `Tiro Devanagari Sanskrit` fonts via `google_fonts`, bilingual
  `en`/`hi` ARB files, 4-tab bottom nav (Inventory / Customers / Finance /
  Settings).
- Firebase Auth (email + Google) through `AuthRepository` +
  `AuthController` (`AsyncNotifier`). No `setState` anywhere — every screen
  consumes Riverpod providers.
- GoRouter auth gate: unauthenticated users are bounced to `/sign-in`;
  authenticated users land on `/inventory`.
- `merchants/{uid}` document is created on first sign-up (idempotent).
- Full Firestore rules (default-deny) and Cloud Storage rules under
  `firebase/`. Every collection/subcollection is owner-scoped.
- `PYTHON_BACKEND_URL` is consumed via `--dart-define` only — never
  hardcoded.
- Cloud Functions skeleton with a single `/health` `onRequest` function
  (asia-south1, lazy-loaded heavy deps).
- Python 3.11 FastAPI skeleton with restricted CORS, SlowAPI limiter
  installed, `/health` endpoint.
- CI workflow for Flutter (analyze/format/test), Functions (lint/build),
  AI (ruff) and Gitleaks secret-scanning on every PR.

**Riverpod providers introduced:**

| Provider                    | Purpose                                       |
|-----------------------------|-----------------------------------------------|
| `firebaseAuthProvider`      | `FirebaseAuth` singleton                      |
| `firestoreProvider`         | `FirebaseFirestore` singleton                 |
| `firebaseStorageProvider`   | `FirebaseStorage` singleton                   |
| `authRepositoryProvider`    | `AuthRepository` wrapper                      |
| `authStateProvider`         | Streams the current `User?`                   |
| `isSignedInProvider`        | Boolean convenience derived from auth state   |
| `authControllerProvider`    | `AsyncNotifier<void>` — sign-in/up/out/Google |
| `appRouterProvider`         | `GoRouter` that reacts to auth state          |

**Security notes flagged for this sprint:**

- No `allow read, write: if true` anywhere in `firebase/firestore.rules`
  or `firebase/storage.rules`.
- `customers` collection refuses writes that contain a plaintext `phone`
  field; only `phoneEncrypted` is accepted (AES-256 encryption arrives in
  Sprint 6).
- `ledger` collection refuses writes that contain a plaintext `upiRef`
  field; only `upiRefEncrypted` is accepted (AES-256 encryption arrives
  in Sprint 5).
- `ledger` is append-only: `allow update, delete: if false`.
- Python backend: `allow_origins=["*"]` is explicitly forbidden in code
  comments; allow-list is env-driven.
- Cloud Storage images: owner-scoped + MIME-type + size-capped at 5 MB.
