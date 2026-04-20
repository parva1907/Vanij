# Vanij — Production Release Checklist

This is the end-to-end walkthrough for a production deploy. Run it top-to-bottom the first time, and use the **Every release** section for subsequent cuts.

---

## One-time setup

### 1. Firebase project

- [ ] Create / confirm Firebase project `vanij-6cc7e` (blaze plan — required for Cloud Functions outbound HTTP).
- [ ] **Authentication → Sign-in method**: enable *Email/Password* and *Google*.
- [ ] **Firestore**: create database in region `asia-south1` (Mumbai).
- [ ] **Storage**: create bucket in `asia-south1`.
- [ ] **Crashlytics**: enable in the project (Release & Monitoring → Crashlytics).
- [ ] **Analytics**: already linked to a Google Analytics property by default.

### 2. Secret Manager (Google Cloud)

Create the following secrets in the project's Secret Manager. Each one must be bound to the FastAPI Cloud Run service account with the `Secret Manager Secret Accessor` role.

| Secret name | Consumer | Purpose |
| --- | --- | --- |
| `ANTHROPIC_API_KEY` | FastAPI (`/v1/agent/draft`) | Claude Sonnet API key. |
| `AGENT_FUNCTION_SA_EMAIL` | FastAPI | Email of the Cloud Function SA allowed to call the agent endpoint. |
| `AGENT_AUDIENCE` | FastAPI | Expected `aud` claim (Cloud Run URL of the FastAPI service). |
| `ALLOWED_ORIGINS` | FastAPI | Comma-separated CORS allow-list. Never `*`. |

**Never commit a secret** to Git. `.gitleaks.toml` guards this in CI, but the operator is the final line of defence.

### 3. IAM — least privilege

Create two service accounts:

- `vanij-ai@vanij-6cc7e.iam.gserviceaccount.com` — FastAPI runtime.
  - `roles/datastore.viewer` (read-only inventory access — the agent has no write code path).
  - `roles/secretmanager.secretAccessor` (for the secrets above).
- `vanij-fn@vanij-6cc7e.iam.gserviceaccount.com` — Cloud Function runtime.
  - `roles/datastore.user` (needs to write agent draft messages).
  - `roles/iam.serviceAccountTokenCreator` (mint ID tokens to call FastAPI).

Bind `AGENT_FUNCTION_SA_EMAIL` to `vanij-fn@...`.

### 4. Android upload keystore

- [ ] Generate once: `keytool -genkey -v -keystore ~/vanij-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias vanij-upload`.
- [ ] Store the `.jks` outside the repo (e.g. in 1Password + a secure backup).
- [ ] Copy `app/android/key.properties.example` → `app/android/key.properties` and fill in the four values. **Never commit `key.properties` or the `.jks`** — both are in `.gitignore`.
- [ ] Upload the **upload-certificate fingerprint** to Firebase console → project settings → your Android app → SHA certificate fingerprints (needed for Google Sign-In to work on release builds).
- [ ] Upload the Play-managed app-signing key to Play Console (one-time).

---

## Every release

### 1. Preflight

- [ ] `main` is green (all 5 CI checks pass on the commit you're about to ship).
- [ ] Bump `app/pubspec.yaml` `version: MAJOR.MINOR.PATCH+BUILD`.
- [ ] Bump `ai/pyproject.toml` `version` if the AI backend changed.
- [ ] Bump `functions/package.json` `version` if the Cloud Functions changed.
- [ ] Tag the commit: `git tag -a vX.Y.Z -m "..."` then `git push origin vX.Y.Z`.

### 2. Deploy Firestore / Storage rules + indexes

```bash
cd firebase
firebase use vanij-6cc7e
firebase deploy --only firestore:rules,firestore:indexes,storage:rules
```

Index creation is asynchronous — check the Firebase console and wait until each new index shows "Enabled" before deploying the backend.

### 3. Deploy the FastAPI backend (Cloud Run)

```bash
cd ai
gcloud run deploy vanij-ai \
  --source . \
  --region asia-south1 \
  --platform managed \
  --service-account vanij-ai@vanij-6cc7e.iam.gserviceaccount.com \
  --set-secrets ANTHROPIC_API_KEY=ANTHROPIC_API_KEY:latest \
  --set-secrets AGENT_FUNCTION_SA_EMAIL=AGENT_FUNCTION_SA_EMAIL:latest \
  --set-secrets AGENT_AUDIENCE=AGENT_AUDIENCE:latest \
  --set-secrets ALLOWED_ORIGINS=ALLOWED_ORIGINS:latest \
  --set-env-vars ENVIRONMENT=prod \
  --no-allow-unauthenticated
```

Smoke-test:

```bash
curl -fsS https://vanij-ai-<hash>-el.a.run.app/health
```

### 4. Deploy the Cloud Functions

```bash
cd functions
npm run build
firebase deploy --only functions:onCustomerMessageCreated
```

Set the runtime env:

```bash
firebase functions:config:set \
  agent.base_url="https://vanij-ai-<hash>-el.a.run.app" \
  agent.audience="https://vanij-ai-<hash>-el.a.run.app"
firebase deploy --only functions:onCustomerMessageCreated
```

### 5. Build & ship the Flutter app

```bash
cd app
flutter clean
flutter pub get
flutter gen-l10n

# Sanity checks (same as CI):
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test

# Release build — signed with the upload keystore via `key.properties`.
flutter build appbundle --release \
  --dart-define=PYTHON_BACKEND_URL=https://vanij-ai-<hash>-el.a.run.app
```

Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console → Production track.

### 6. Post-deploy smoke tests

On a real Android device with a merchant account signed in:

- [ ] Sign in (email + Google).
- [ ] Create an inventory item (camera snap → TagConfirm → save).
- [ ] Create a ledger entry (sale + UPI ref — ensure the UPI ref doesn't appear in Firestore console in plaintext).
- [ ] Open a customer chat and send a message from merchant side.
- [ ] Simulate a customer reply (via admin SDK in a scratch script), confirm the DRAFT bubble appears within ~5 seconds and the draft text mentions only items from the merchant's inventory.
- [ ] Edit the draft and send — verify the DRAFT badge clears.

### 7. Telemetry verification

- [ ] Firebase console → Crashlytics → confirm the new app version shows up (zero crashes expected).
- [ ] Firebase console → Analytics → DebugView → confirm `sign_in_success`, `inventory_item_created`, `ledger_entry_added`, `chat_message_sent`, `agent_draft_reviewed` events arrive with expected parameters.
- [ ] Cloud Logging → filter `severity=ERROR` for the FastAPI service — should be empty.

---

## Rotation / incident response

- **Rotate `ANTHROPIC_API_KEY`**: create a new version in Secret Manager, redeploy Cloud Run (no code change). Old version stays accessible but the service picks up `:latest`.
- **Rotate Android upload key**: Play Console → App integrity → request upload key reset (Google will email a new upload certificate). Do **not** attempt to change the app-signing key — that's managed by Play.
- **Revoke a merchant**: Firebase console → Authentication → disable account. The Auth middleware rejects tokens for disabled accounts with 401 on the next request.
- **Secret leak** (gitleaks, pre- or post-merge): rotate the secret first, then force-push with history rewrite after confirming no downstream consumer.
