"""Request/response middleware for the serving API.

Provides request ID tracking, latency monitoring, rate limiting,
and structured logging for production observability.
"""

from __future__ import annotations

import logging
import time
import uuid
from collections import defaultdict
from threading import Lock

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

logger = logging.getLogger(__name__)


class RequestIdMiddleware(BaseHTTPMiddleware):
    """Adds a unique request ID to each request for tracing."""

    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        request.state.request_id = request_id

        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response


class LatencyMiddleware(BaseHTTPMiddleware):
    """Tracks and logs request latency."""

    async def dispatch(self, request: Request, call_next) -> Response:
        start_time = time.perf_counter()

        response = await call_next(request)

        latency_ms = (time.perf_counter() - start_time) * 1000
        response.headers["X-Response-Time-Ms"] = f"{latency_ms:.2f}"

        logger.info(
            "request completed",
            extra={
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "latency_ms": round(latency_ms, 2),
            },
        )

        return response


class RateLimiter:
    """Simple in-memory rate limiter using a sliding window.

    Tracks request counts per client IP with configurable
    requests-per-minute and burst limits.
    """

    def __init__(self, requests_per_minute: int = 60, burst_size: int = 10) -> None:
        self.rpm = requests_per_minute
        self.burst_size = burst_size
        self._windows: dict[str, list[float]] = defaultdict(list)
        self._lock = Lock()

    def is_allowed(self, client_id: str) -> bool:
        """Check if a request from the given client is allowed.

        Args:
            client_id: Client identifier (e.g., IP address).

        Returns:
            True if the request is allowed.
        """
        now = time.time()
        window_start = now - 60.0

        with self._lock:
            # Clean old entries
            self._windows[client_id] = [
                t for t in self._windows[client_id] if t > window_start
            ]

            if len(self._windows[client_id]) >= self.rpm:
                return False

            # Check burst (last 1 second)
            recent = sum(1 for t in self._windows[client_id] if t > now - 1.0)
            if recent >= self.burst_size:
                return False

            self._windows[client_id].append(now)
            return True


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Rate limiting middleware using sliding window."""

    def __init__(self, app, requests_per_minute: int = 60, burst_size: int = 10):
        super().__init__(app)
        self.limiter = RateLimiter(requests_per_minute, burst_size)

    async def dispatch(self, request: Request, call_next) -> Response:
        # Skip rate limiting for health checks
        if request.url.path.startswith("/health"):
            return await call_next(request)

        client_ip = request.client.host if request.client else "unknown"

        if not self.limiter.is_allowed(client_ip):
            return JSONResponse(
                status_code=429,
                content={"detail": "Rate limit exceeded. Please try again later."},
            )

        return await call_next(request)
