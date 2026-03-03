FROM python:3.11-slim AS base

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml .
RUN pip install --no-cache-dir -e ".[training]"

COPY config/ config/
COPY src/ src/
COPY scripts/ scripts/

# --- Serving image ---
FROM base AS serving

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import httpx; r = httpx.get('http://localhost:8080/health/live'); r.raise_for_status()" || exit 1

ENTRYPOINT ["python", "scripts/serve.py"]
CMD ["--host", "0.0.0.0", "--port", "8080", "--workers", "4"]

# --- Training image ---
FROM base AS training

ENTRYPOINT ["python", "scripts/train.py"]
