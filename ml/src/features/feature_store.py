"""Feature store for caching preprocessed data and serving features.

Provides a lightweight feature store for bird image embeddings and
metadata, supporting both batch and real-time feature serving.
"""

from __future__ import annotations

import hashlib
import json
import logging
import time
from collections import OrderedDict
from dataclasses import asdict, dataclass, field
from pathlib import Path
from threading import Lock

import numpy as np

logger = logging.getLogger(__name__)


@dataclass
class FeatureRecord:
    """A single feature record in the store."""

    feature_id: str
    features: dict[str, float]
    embedding: list[float] | None = None
    metadata: dict[str, str] = field(default_factory=dict)
    created_at: float = field(default_factory=time.time)
    ttl_seconds: float = 3600.0


class InMemoryFeatureStore:
    """Thread-safe in-memory feature store with LRU eviction.

    Caches image features and embeddings for fast retrieval during
    inference. Supports TTL-based expiration and LRU eviction.
    """

    def __init__(self, max_size: int = 10000, default_ttl: float = 3600.0) -> None:
        self._store: OrderedDict[str, FeatureRecord] = OrderedDict()
        self._max_size = max_size
        self._default_ttl = default_ttl
        self._lock = Lock()
        self._hits = 0
        self._misses = 0

    def put(
        self,
        feature_id: str,
        features: dict[str, float],
        embedding: list[float] | None = None,
        metadata: dict[str, str] | None = None,
        ttl: float | None = None,
    ) -> None:
        """Store a feature record.

        Args:
            feature_id: Unique identifier for the feature set.
            features: Dictionary of feature name to value.
            embedding: Optional model embedding vector.
            metadata: Optional metadata tags.
            ttl: Time-to-live in seconds. Uses default if not specified.
        """
        record = FeatureRecord(
            feature_id=feature_id,
            features=features,
            embedding=embedding,
            metadata=metadata or {},
            ttl_seconds=ttl or self._default_ttl,
        )

        with self._lock:
            if feature_id in self._store:
                self._store.move_to_end(feature_id)
            self._store[feature_id] = record

            # Evict oldest entries if over capacity
            while len(self._store) > self._max_size:
                self._store.popitem(last=False)

    def get(self, feature_id: str) -> FeatureRecord | None:
        """Retrieve a feature record.

        Args:
            feature_id: The feature set identifier.

        Returns:
            FeatureRecord if found and not expired, None otherwise.
        """
        with self._lock:
            record = self._store.get(feature_id)
            if record is None:
                self._misses += 1
                return None

            # Check TTL
            if time.time() - record.created_at > record.ttl_seconds:
                del self._store[feature_id]
                self._misses += 1
                return None

            self._store.move_to_end(feature_id)
            self._hits += 1
            return record

    def get_stats(self) -> dict[str, int | float]:
        """Get cache statistics."""
        total = self._hits + self._misses
        return {
            "size": len(self._store),
            "max_size": self._max_size,
            "hits": self._hits,
            "misses": self._misses,
            "hit_rate": self._hits / total if total > 0 else 0.0,
        }

    def clear(self) -> None:
        """Clear all entries from the store."""
        with self._lock:
            self._store.clear()
            self._hits = 0
            self._misses = 0

    @staticmethod
    def compute_feature_id(image_bytes: bytes) -> str:
        """Compute a deterministic feature ID from image content.

        Args:
            image_bytes: Raw image bytes.

        Returns:
            SHA-256 hash string.
        """
        return hashlib.sha256(image_bytes).hexdigest()


class DiskFeatureStore:
    """Persistent feature store backed by disk storage.

    Stores features as JSON files for batch processing workflows
    and offline analysis.
    """

    def __init__(self, store_dir: str | Path) -> None:
        self.store_dir = Path(store_dir)
        self.store_dir.mkdir(parents=True, exist_ok=True)

    def put(self, feature_id: str, record: FeatureRecord) -> None:
        """Write a feature record to disk."""
        path = self.store_dir / f"{feature_id}.json"
        data = asdict(record)
        with open(path, "w") as f:
            json.dump(data, f)

    def get(self, feature_id: str) -> FeatureRecord | None:
        """Read a feature record from disk."""
        path = self.store_dir / f"{feature_id}.json"
        if not path.exists():
            return None
        with open(path) as f:
            data = json.load(f)
        return FeatureRecord(**data)

    def list_ids(self) -> list[str]:
        """List all stored feature IDs."""
        return [p.stem for p in self.store_dir.glob("*.json")]

    def delete(self, feature_id: str) -> bool:
        """Delete a feature record."""
        path = self.store_dir / f"{feature_id}.json"
        if path.exists():
            path.unlink()
            return True
        return False

    def export_embeddings(self) -> tuple[list[str], np.ndarray] | None:
        """Export all stored embeddings as a numpy array.

        Returns:
            Tuple of (feature_ids, embeddings_array) or None if no embeddings exist.
        """
        ids = []
        embeddings = []

        for fid in self.list_ids():
            record = self.get(fid)
            if record and record.embedding:
                ids.append(fid)
                embeddings.append(record.embedding)

        if not embeddings:
            return None

        return ids, np.array(embeddings, dtype=np.float32)
