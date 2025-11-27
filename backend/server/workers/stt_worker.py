from __future__ import annotations

import asyncio
import base64
import json
import logging
import math
import uuid
from datetime import datetime
from typing import Any

from ..config import STT_POLL_INTERVAL
from ..db import AsyncSessionLocal
from ..models import Meeting, Transcript
from ..redis import get_redis, meeting_channel, serialize_message
from ..services.stt import STTNotAvailableError, get_stt_service

logger = logging.getLogger("stt_worker")
logging.basicConfig(level=logging.INFO)


def _is_silence_base64(chunk_base64: str, threshold: float = 200.0) -> bool:
    """Lightweight RMS check to avoid sending obvious silence to STT providers."""
    try:
        audio_bytes = base64.b64decode(chunk_base64, validate=False)
    except (ValueError, TypeError):
        return True
    if len(audio_bytes) < 320:  # ~10ms at 16kHz mono
        return True
    if len(audio_bytes) % 2:
        audio_bytes = audio_bytes[:-1]
    sample_count = len(audio_bytes) // 2
    if sample_count == 0:
        return True
    accum = 0.0
    for i in range(0, len(audio_bytes), 2):
        sample = int.from_bytes(audio_bytes[i : i + 2], "little", signed=True)
        accum += sample * sample
    rms = math.sqrt(accum / sample_count)
    return rms < threshold


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

    if _is_silence_base64(chunk_base64):
        logger.debug("Skipping silent audio chunk for meeting %s", meeting_id)
        return

    stt_service = get_stt_service()
    text = await stt_service.transcribe_base64(meeting_id, chunk_base64)
    if not text:
        logger.debug("No transcription produced for meeting %s", meeting_id)
        return

    async with AsyncSessionLocal() as session:
        # Prefer client-provided speaker label; avoid falling back to raw userId UUID
        speaker = chunk_speaker or payload.get("speaker") or "참여자"
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
        except STTNotAvailableError as exc:
            logger.error("STT dependency missing/unavailable: %s", exc)
            raise
        except Exception as exc:
            logger.exception("Failed to process audio chunk: %s", exc)
    return consumed


async def _is_meeting_active(meeting_id: uuid.UUID) -> bool:
    """Return True only when the meeting exists and is in-progress."""
    async with AsyncSessionLocal() as session:
        meeting = await session.get(Meeting, meeting_id)
        return bool(meeting and meeting.status == "in-progress")


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

            is_active = await _is_meeting_active(meeting_id)
            if not is_active:
                # Drop queued audio for non-active meetings to avoid stray inserts.
                await redis.delete(key)
                logger.info("Dropped audio queue for inactive meeting %s", meeting_id)
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
