"""Runtime configuration for the Vanij AI backend.

Security rules:
  * No secrets may ever be hardcoded in source. All secrets are loaded from
    environment variables populated by Google Cloud Secret Manager at
    deploy time.
  * CORS `allow_origins` is restricted — never `['*']`.
"""

from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Sprint 1 fields — vision/LLM keys arrive in later sprints.
    firebase_project_id: str = "vanij-6cc7e"

    # Comma-separated list of fully-qualified origins allowed to call this
    # backend. Flutter on Android doesn't send a browser Origin header, so
    # this matters only for future web clients — but we still refuse `*`.
    allowed_origins: str = "https://vanij.app"

    # Claude Sonnet API key — used only from Sprint 7 onwards. Left empty
    # for Sprint 1 so the service can boot without it.
    claude_api_key: str = ""

    @property
    def allowed_origins_list(self) -> list[str]:
        return [o.strip() for o in self.allowed_origins.split(",") if o.strip()]


settings = Settings()
