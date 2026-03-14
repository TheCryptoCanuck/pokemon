# Multi-stage Python FastAPI deployment image
# Target: Single VPS deployment (Railway, Render, or self-hosted Docker)

# Build stage
FROM python:3.11-slim as builder

WORKDIR /app

# Install system dependencies required for building Python packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies to a virtual environment
COPY requirements.txt .
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt


# Runtime stage — minimal production image
FROM python:3.11-slim

WORKDIR /app

# Create non-root user for improved security
RUN useradd -m -u 1000 appuser

# Install runtime dependencies only (no build tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Copy application code
COPY app/ ./app/
COPY alembic/ ./alembic/
COPY alembic.ini .
COPY scripts/ ./scripts/

# Set environment variables
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Change ownership to non-root user
RUN chown -R appuser:appuser /app
USER appuser

# Health check — verifies FastAPI is responding
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Run uvicorn with graceful shutdown support
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
