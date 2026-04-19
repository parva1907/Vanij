// ============================================================
// Vanij — Cloud Functions entrypoint (Sprint 1 skeleton).
//
// We keep cold start under 2s by:
//   • lazy-loading heavy modules (e.g. the AI agent) inside handlers only
//   • using top-level imports for `firebase-admin` / `firebase-functions` only
//
// Secrets come from environment variables wired up by Google Cloud
// Secret Manager at deploy time — never from `functions.config()` and never
// hardcoded.
// ============================================================
import {initializeApp} from "firebase-admin/app";
import {onRequest} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";

initializeApp();

/** Lightweight health check used by uptime monitors and CI smoke tests. */
export const health = onRequest(
  {region: "asia-south1", cors: false},
  (_req, res) => {
    logger.info("health ping");
    res.status(200).json({ok: true, service: "vanij-functions"});
  },
);
