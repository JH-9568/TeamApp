from __future__ import annotations

import json
from typing import Any
from uuid import UUID

import redis.asyncio as redis

from .config import REDIS_URL

_redis_client: redis.Redis | None = None


def get_redis() -> redis.Redis:
    """Return a singleton Redis client."""
    global _redis_client
    if _redis_client is None:
        _redis_client = redis.from_url(REDIS_URL, decode_responses=True)
    return _redis_client


def meeting_channel(meeting_id: UUID) -> str:
    return f"meeting:{meeting_id}:events"


def meeting_audio_key(meeting_id: UUID) -> str:
    return f"meeting:{meeting_id}:audio"


def serialize_message(message_type: str, data: dict[str, Any]) -> str:
    """Helper to keep Redis pub/sub payloads consistent."""
    return json.dumps({"type": message_type, "data": data})
