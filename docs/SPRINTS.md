# Sprint log

## Sprint 1 — Auth + rules + folder structure

**Module:** Foundation.

**Delivered:**

- Monorepo skeleton: `app/` (Flutter), `functions/` (Node 20), `ai/` (Python 3.11 FastAPI), `firebase/` (rules & indexes), `docs/`.
- Flutter app shell with Riverpod, GoRouter, theme (`#1B5E20` / `#F9A825`), `Inter` + `Tiro Devanagari Sanskrit` fonts via `google_fonts`, bilingual `en`/`hi` ARB files, 4-tab bottom nav (Inventory / Customers / Finance / Settings).
- Firebase Auth (email + Google) through `AuthRepository` + `AuthController` (`AsyncNotifier`). No `setState` anywhere — every screen consumes Riverpod providers.
- GoRouter auth gate: unauthenticated users are bounced to `/sign-in`; authenticated users land on `/inventory`.
- `merchants/{uid}` document is created on first sign-up (idempotent).
- Full Firestore rules (default-deny) and Cloud Storage rules under `firebase/`. Every collection/subcollection is owner-scoped.
- `PYTHON_BACKEND_URL` is consumed via `--dart-define` only — never hardcoded.
- Cloud Functions skeleton with a single `/health` `onRequest` function (asia-south1, lazy-loaded heavy deps).
- Python 3.11 FastAPI skeleton with restricted CORS, SlowAPI limiter installed, `/health` endpoint.
- CI workflow for Flutter, Functions, AI, and Gitleaks on every PR.

**Security notes:** default-deny Firestore rules; `customers` refuses plaintext `phone`; `ledger` refuses plaintext `upiRef` and is append-only; CORS allow-list never `*`; Storage is owner-scoped + 5 MB + MIME-gated.

## Sprint 2 — Inventory CRUD + image upload

**Module:** Inventory.

**Delivered:**

- `InventoryItem` model (`name, category, color[], pattern, size[], quantity{}, price, costPrice, imageUrl, lowStock, updatedAt`).
- `InventoryRepository` (paginated list, search-by-name, category + colour filters, low-stock highlight) with `.limit()` on every read.
- `InventoryFormScreen` — camera → `flutter_image_compress` WebP → Firebase Storage upload → URL saved on doc. Temp WebP deleted in `try/finally`.
- Firestore composite indexes: `category + updatedAt DESC`, `lowStock + updatedAt DESC`, `color (array-contains) + updatedAt DESC`, `category + color + updatedAt DESC`.
- `cached_network_image` used throughout for product photos.

**Security notes:** EXIF stripped by WebP compression before upload; Storage rules enforce 5 MB + image/\* MIME type; `price >= 0`, `costPrice >= 0`, `quantity is map`, non-empty `name`, `color is list` enforced by Firestore rules.

## Sprint 3 — FastAPI skeleton + auth middleware + health

**Module:** Backend foundation.

**Delivered:**

- Firebase Auth bearer-token middleware (`HTTPBearer` → `firebase_admin.auth.verify_id_token` → `AuthenticatedUser` on `request.state.uid`; 401 on missing / invalid / expired / revoked tokens).
- `/health` (liveness) + `/ready` (readiness — checks firebase-admin init + env config). Both unauthenticated.
- `/v1` router gated by `require_auth`; every subroute inherits `@limiter.limit` so future AI routes can't forget.
- Production guard on the `AUTH_DISABLED` local-dev escape hatch (refuses to boot with `AUTH_DISABLED=true` + `ENVIRONMENT=prod`).
- Multi-stage Dockerfile (non-root runtime user, no build tools in the final layer).
- CI now runs `ruff check` + `ruff format --check` + `pytest` for the AI backend.

## Sprint 4 — Vision tagger + TagConfirmScreen

**Module:** Vision (AI-assisted inventory tagging).

**Delivered:**

- `POST /v1/vision/tag` — accepts WebP/JPEG, returns `TagCandidate[]` (category / colours / pattern) with confidence scores. Auth-gated + rate-limited; 413 on oversized bodies (aligns with the 5 MB Storage rule).
- Pluggable `VisionTagger` protocol. Default `HeuristicVisionTagger` is deterministic (hash-based stub so CI + dev work without torch). Production flips `VISION_BACKEND=torch` to load a PyTorch CNN at startup in the lifespan.
- Flutter `VisionApiService` (multipart POST with Firebase ID token) + `TagConfirmScreen` (preview + editable dropdowns + "Looks good" / "Reject" CTAs).
- New-item flow rewired to: camera snap → WebP compress → `/v1/vision/tag` → TagConfirmScreen → pre-fill InventoryFormScreen → existing save path.
- Drift guard: a pytest fixture parses the Flutter source and asserts the Python tagger's category list matches `kInventoryCategories`.

**Security notes:** AI tags are **never** auto-committed — TagConfirmScreen always runs first; no raw image bytes logged; backend refuses bodies > `MAX_IMAGE_BYTES`.

## Sprint 5 — Finance (ledger + AES-256 UPI + CSV export)

**Module:** Finance.

**Delivered:**

- `LedgerEntry { id, type: sale|expense|refund, amount, note, itemRef?, upiRefEncrypted?, createdAt, createdBy }`.
- `LedgerCipher` (AES-256-GCM, 12-byte nonce, 16-byte tag) with the key stored in Android Keystore via `flutter_secure_storage`. Memoised `Future<SecretKey>` fixes a real concurrency bug where two first-use calls could each generate and overwrite the key (silent UPI data loss). 16-way concurrent-first-use regression test.
- `LedgerRepository` with paginated list + date-range queries (`.limit()` on every read).
- `FinanceScreen` dashboard (today's revenue, weekly P&L, top-selling items joining by `itemRef`).
- `AddLedgerEntryScreen`, `LedgerListScreen` (filter by type + date range).
- `CsvExportService` — CSV writes to app sandbox first, then shared via `share_plus`. UPI decrypted locally at export time, never sent over network.
- Firestore indexes: `type + date DESC`, `type + date ASC`, `date DESC`.

**Security notes:** `upiRef` never written plaintext — AES-256-GCM encrypted + base64; modal barrier cleanup in `try/finally` prevents permanent UI block after export; ledger remains append-only (no edit/delete UI; corrections are new entries).

## Sprint 6 — CRM chat UI (no agent)

**Module:** CRM.

**Delivered:**

- `AesGcmCipher` base class; `LedgerCipher` refactored to a thin subclass; new `PhoneCipher` with a separate keystore namespace (`vanij.phone.aes256.v1`) — ledger/phone keys can't cross-decrypt.
- `Customer { id, name, phoneEncrypted, tags?, notes?, lastMessageAt?, createdAt, createdBy }` and `ChatMessage { id, sender ∈ {merchant, customer, agent}, body, createdAt, edited?, isDraft?, agentDraftFromMessageId? }`.
- `CustomerRepository` (paginated, `updatedAt DESC`, 30/page) + `ChatRepository` (batch send atomically bumps parent `lastMessageAt` / `updatedAt` so the list re-sorts live).
- Riverpod providers (AsyncNotifier pagination, filtered-list notifier, family streams for customer detail + chat history).
- Screens — `CustomersScreen` (search + pagination), `AddCustomerScreen` (encrypts phone before write), `ChatScreen` (WhatsApp-style bubbles with long-press edit/delete).
- `customers: updatedAt DESC` index; gitleaks allowlist for the new keystore namespace.

**Security notes:** `plaintext phone` can never be emitted from `toCreatePayload` / `toUpdatePayload`; Sprint-1 Firestore rules reject plaintext-phone writes; all 16-way concurrent cipher first-use tests pass; namespace isolation tested.

## Sprint 7 — LLM agent /v1/agent/draft + Firestore trigger + DRAFT badge

**Module:** Agent + Functions trigger + UI.

**Delivered:**

- FastAPI `/v1/agent/draft`: dual-path auth (Firebase ID token **or** Google-signed SA token from the Cloud Function), SlowAPI `@limiter.limit("20/minute;200/hour")` keyed by `merchant:<uid>` with IP fallback (critical bug — the first cut keyed on SA email which shared one quota across all merchants).
- Read-only inventory fetcher (top 20 items, `lowStock DESC + updatedAt DESC`). Agent has no write code path.
- Anthropic Sonnet wrapper with a concise English + Hindi code-mix prompt (max 3 sentences, inventory-only references, ends with "— reviewed by merchant before sending."). Reply clipped to `AGENT_MAX_REPLY_CHARS` (default 600).
- Cloud Function `onCustomerMessageCreated`: fires on `messages/{id}` where `sender == customer`, mints a Google ID token, POSTs to `/v1/agent/draft`, writes the reply as `{sender: agent, isDraft: true, agentDraftFromMessageId}` and bumps parent `lastMessageAt`. Idempotency guard prevents duplicate drafts on retries.
- `ChatScreen` now shows a gold "DRAFT" pill + italic "review before sending" hint on agent bubbles while `isDraft == true`. Merchant edit clears the flag (editing implies approval).
- Firestore composite index for the agent query: `lowStock DESC + updatedAt DESC` (critical fix — the initial cut declared `(ASC, DESC)` which Firestore won't serve for a `DESC, DESC` query).
- `_verify_google_id_token` catches all exceptions and falls through to Firebase verification (critical fix — initial cut caught only `ValueError`, so a Google JWKS transport failure would 500 every Firebase-authed merchant sharing the endpoint).
- `InventoryFormScreen` colour chips union the palette with any AI-suggested colours so a suggested "Mustard" isn't silently dropped.

**Security notes:** `ANTHROPIC_API_KEY` loaded from Secret Manager at startup, never logged, never sent to the client; LLM has no write tools; Cloud Function → FastAPI uses Google ID-token auth with `aud = AGENT_AUDIENCE`; only the configured SA email is honoured for SA-path requests.

## Sprint 8 — Telemetry + release polish

**Module:** Polish, telemetry, release-readiness.

**Delivered:**

- **ai/** structured JSON logging (`app/logging_setup.py`) — PII-scrubbing formatter (redacts `phone`, `upi_ref`, `message`, `authorization`, etc. at emit time, walks nested dicts); `X-Request-ID` correlation middleware (`app/middleware.py`) that honours inbound headers or mints UUIDv4, echoes back on the response, emits one structured `http_request` line per request with `{method, path, status, latency_ms}`.
- **app/** Firebase Crashlytics (`core/telemetry/crashlytics_bootstrap.dart`) — `FlutterError.onError` + `PlatformDispatcher.instance.onError` + `runZonedGuarded`; disabled in debug so local stack-traces don't pollute the Firebase console.
- **app/** Firebase Analytics (`core/analytics/`) — bounded event catalogue (`sign_in_success`, `inventory_item_created`, `ledger_entry_added`, `chat_message_sent`, `agent_draft_reviewed`) with PII-free parameters only; `setUserId` hook bound to the Riverpod auth state listener.
- **app/android** release signing config — `key.properties` (never committed) drives `signingConfigs.release`; falls back to the debug keystore so `flutter run --release` still works on dev machines. Crashlytics Gradle plugin added to upload release-build mappings.
- **CI** Gitleaks upgraded from `--no-git` (Sprint-1 placeholder) to a full-history scan — every commit on the branch is covered, not just the working tree.
- **docs** `SPRINTS.md` backfilled (Sprints 2 → 7); new `RELEASE.md` production checklist; `README.md` refreshed with local-dev setup steps.

**Security notes:** analytics payloads carry no customer content by construction (catalogue-driven); logging formatter redacts PII-labelled keys at emit time regardless of caller; `key.properties` and `*.jks` in `.gitignore`; no new Firestore rules.
