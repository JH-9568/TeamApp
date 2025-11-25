from __future__ import annotations

import asyncio
import json
import logging
import uuid
from datetime import datetime
from typing import Any

from ..config import STT_POLL_INTERVAL
from ..db import AsyncSessionLocal
from ..models import Transcript, User
from ..redis import get_redis, meeting_channel, serialize_message
from ..services.stt import WhisperNotAvailableError, get_whisper_service

logger = logging.getLogger("stt_worker")
logging.basicConfig(level=logging.INFO)


async def _fetch_user_name(session, user_id: str | None) -> str:
    if not user_id:
        return "Guest"
    try:
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        return "Guest"

    user = await session.get(User, user_uuid)
    if user:
        return user.name
    return "Guest"


async def _handle_chunk(meeting_id: uuid.UUID, payload: dict[str, Any]) -> None:
    chunk_payload = payload.get("chunk")
    if not chunk_payload:
        return

    chunk_speaker = None
    chunk_timestamp = None
    if isinstance(chunk_payload, dict):
        chunk_speaker = chunk_payload.get("speaker")
        chunk_timestamp = chunk_payload.get("timestamp")
        chunk_base64 = chunk_payload.get("data")
    else:
        chunk_base64 = chunk_payload

    if not isinstance(chunk_base64, str) or not chunk_base64.strip():
        logger.debug("Skipping empty audio chunk for meeting %s", meeting_id)
        return

    stt_service = get_whisper_service()
    text = await stt_service.transcribe_base64(meeting_id, chunk_base64)
    if not text:
        logger.info("No transcription produced for meeting %s", meeting_id)
        return

    async with AsyncSessionLocal() as session:
        speaker = await _fetch_user_name(session, payload.get("userId"))
        if chunk_speaker:
            speaker = chunk_speaker
        transcript = Transcript(
            id=uuid.uuid4(),
            meeting_id=meeting_id,
            speaker=speaker,
            text=text,
            timestamp=chunk_timestamp
            or payload.get("timestamp")
            or payload.get("receivedAt")
            or datetime.utcnow().isoformat(),
        )
        session.add(transcript)
        await session.commit()
        await session.refresh(transcript)

        event_payload = {
            "id": str(transcript.id),
            "speaker": transcript.speaker,
            "text": transcript.text,
            "timestamp": transcript.timestamp,
        }

    redis = get_redis()
    await redis.publish(
        meeting_channel(meeting_id),
        serialize_message("transcript_segment", event_payload),
    )


async def _drain_queue(redis, key: str, meeting_id: uuid.UUID) -> bool:
    consumed = False
    while True:
        raw = await redis.lpop(key)
        if raw is None:
            break
        consumed = True
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            logger.warning("Invalid audio payload for meeting %s: %s", meeting_id, raw[:50])
            continue
        try:
            await _handle_chunk(meeting_id, payload)
        except WhisperNotAvailableError as exc:
            logger.error("Whisper dependency missing: %s", exc)
            raise
        except Exception as exc:
            logger.exception("Failed to process audio chunk: %s", exc)
    return consumed


async def run_worker() -> None:
    logger.info("STT worker started. Poll interval %ss", STT_POLL_INTERVAL)

    while True:
        redis = get_redis()
        processed = False
        async for key in redis.scan_iter(match="meeting:*:audio"):
            parts = key.split(":")
            if len(parts) < 3:
                continue
            meeting_part = parts[1]
            try:
                meeting_id = uuid.UUID(meeting_part)
            except ValueError:
                continue
            consumed = await _drain_queue(redis, key, meeting_id)
            processed = processed or consumed

        if not processed:
            await asyncio.sleep(STT_POLL_INTERVAL)


if __name__ == "__main__":
    try:
        asyncio.run(run_worker())
    except KeyboardInterrupt:
        logger.info("STT worker stopped.")
