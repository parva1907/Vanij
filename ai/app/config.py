"""Runtime configuration for the Vanij AI backend.

Security rules:
  * No secrets may ever be hardcoded in source. All secrets are loaded from
    environment variables populated by Google Cloud Secret Manager at
    deploy time.
  * CORS ``allow_origins`` is restricted — never ``['*']``.
"""

from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # ------------------------------------------------------------------
    # Identity / environment
    # ------------------------------------------------------------------
    firebase_project_id: str = "vanij-6cc7e"
    environment: str = "dev"  # "dev" | "staging" | "prod"
    app_version: str = "0.1.0"

    # ------------------------------------------------------------------
    # HTTP / CORS
    # ------------------------------------------------------------------
    # Comma-separated list of fully-qualified origins allowed to call this
    # backend. Flutter on Android doesn't send a browser Origin header, so
    # this matters only for future web clients — but we still refuse ``*``.
    allowed_origins: str = "https://vanij.app"

    # ------------------------------------------------------------------
    # Auth
    # ------------------------------------------------------------------
    # When true, the auth middleware is disabled and ``request.state.uid``
    # is set to ``auth_test_uid``. ONLY for local development and tests —
    # must never be enabled in production.
    auth_disabled: bool = False
    auth_test_uid: str = "test-merchant-uid"

    # ------------------------------------------------------------------
    # Rate limits — SlowAPI strings (see spec rule #6).
    # ------------------------------------------------------------------
    # Applied to every AI route. Kept conservative for Sprint 3; per-route
    # overrides arrive with the vision tagger (Sprint 4) and LLM agent
    # (Sprint 7).
    default_rate_limit: str = "60/minute"

    # ------------------------------------------------------------------
    # Vision tagger (Sprint 4)
    # ------------------------------------------------------------------
    # Which backend the vision tagger factory loads at startup.
    #   "heuristic" (default) — deterministic stub used in CI, tests,
    #     and local dev. No torch dependency, cold-start-safe.
    #   "torch" — real PyTorch model. Requires the optional
    #     ``vision`` extras and a loadable checkpoint; refuses to boot
    #     until Sprint 4+ ships the training pipeline.
    vision_backend: str = "heuristic"
    # Hard cap on uploaded image size. Must stay aligned with the 5 MB
    # Cloud Storage rule so a client can't stuff something through the
    # backend that Storage would reject anyway.
    max_image_bytes: int = 5 * 1024 * 1024

    # ------------------------------------------------------------------
    # External API keys (kept empty in Sprint 3).
    # ------------------------------------------------------------------
    claude_api_key: str = ""

    @property
    def allowed_origins_list(self) -> list[str]:
        return [o.strip() for o in self.allowed_origins.split(",") if o.strip()]

    @property
    def is_production(self) -> bool:
        return self.environment.lower() == "prod"


settings = Settings()
