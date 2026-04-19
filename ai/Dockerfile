# Vanij AI backend — Cloud Run image.
#
# Multi-stage build so the runtime image doesn't carry pip/build tools.
# Sprint 4 will layer the torch + vision model on top; keep the base
# small so cold start stays < 2s (spec performance rule).

# ---------- builder ----------
FROM python:3.11-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /build

COPY pyproject.toml ./
COPY app ./app

# Install into an isolated prefix so we can copy only runtime artefacts
# into the final image.
RUN pip install --upgrade pip \
 && pip install --prefix=/install .

# ---------- runtime ----------
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

# Non-root user — Cloud Run already enforces this but belt-and-braces.
RUN useradd --system --create-home --uid 1001 vanij
WORKDIR /app

COPY --from=builder /install /usr/local
COPY --from=builder /build/app /app/app

USER vanij
EXPOSE 8080

# Single worker: Cloud Run autoscales horizontally; extra workers just
# inflate cold start and memory. ``--no-access-log`` keeps logs clean;
# structured app logs go through the stdlib logger.
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --no-access-log"]
