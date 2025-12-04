from __future__ import annotations

import asyncio
import base64
import json
import logging
import uuid
from datetime import datetime
from typing import Any, Optional
from uuid import UUID

from contextlib import suppress
from google.api_core.exceptions import GoogleAPIError
from google.cloud import speech

from ..config import STT_LANGUAGE, STT_POLL_INTERVAL
from ..db import AsyncSessionLocal
from ..models import Meeting, Transcript, User
from ..redis import get_redis, meeting_channel, serialize_message

logger = logging.getLogger("stt_worker")
logging.basicConfig(level=logging.INFO)


class StreamingSession:
    """Manage a streaming STT session per meeting."""

    def __init__(self, meeting_id: UUID, language_code: str = "ko-KR") -> None:
        self.meeting_id = meeting_id
        self.language_code = language_code
        self._audio_queue: asyncio.Queue[Optional[dict[str, Any]]] = asyncio.Queue()
        self._responses_task: Optional[asyncio.Task] = None
        self._client = speech.SpeechAsyncClient()
        self._config = speech.RecognitionConfig(
            encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
            sample_rate_hertz=16000,
            language_code=self.language_code,
            enable_automatic_punctuation=True,
            model="default",
        )
        self._streaming_config = speech.StreamingRecognitionConfig(
            config=self._config,
            interim_results=False,
            single_utterance=False,
        )
        self._last_meta: dict[str, Any] = {}

    async def start(self) -> None:
        if self._responses_task:
            return
        self._responses_task = asyncio.create_task(self._run())

    async def stop(self) -> None:
        await self._audio_queue.put(None)
        if self._responses_task:
            self._responses_task.cancel()
            with suppress(asyncio.CancelledError):
                await self._responses_task
            self._responses_task = None

    async def enqueue(self, audio_bytes: bytes, meta: dict[str, Any]) -> None:
        if not audio_bytes:
            return
        self._last_meta = meta
        await self._audio_queue.put({"audio": audio_bytes, "meta": meta})

    async def _request_stream(self):
        # First yield config, then audio chunks.
        yield speech.StreamingRecognizeRequest(streaming_config=self._streaming_config)
        while True:
            item = await self._audio_queue.get()
            if item is None:
                break
            audio_bytes = item.get("audio") or b""
            if not audio_bytes:
                continue
            yield speech.StreamingRecognizeRequest(audio_content=audio_bytes)

    async def _run(self) -> None:
        try:
            responses = await self._client.streaming_recognize(
                requests=self._request_stream()
            )
            async for response in responses:
                await self._handle_response(response)
        except GoogleAPIError as exc:
            logger.error("Streaming STT failed for meeting %s: %s", self.meeting_id, exc)
        except Exception as exc:
            logger.exception("Unexpected error in streaming session %s: %s", self.meeting_id, exc)

    async def _handle_response(self, response: speech.StreamingRecognizeResponse) -> None:
        if not response.results:
            return
        for result in response.results:
            if not result.alternatives:
                continue
            text = (result.alternatives[0].transcript or "").strip()
            if not text:
                continue
            if not result.is_final:
                # Skip interim results to avoid duplicates.
                continue
            await self._persist_transcript(text)

    async def _persist_transcript(self, text: str) -> None:
        meta = self._last_meta
        speaker = meta.get("speaker") or meta.get("userName") or meta.get("userId") or "참여자"
        timestamp = (
            meta.get("timestamp")
            or meta.get("receivedAt")
            or datetime.utcnow().isoformat()
        )

        async with AsyncSessionLocal() as session:
            # Resolve speaker from userId if provided
            user_id_val = meta.get("userId")
            if user_id_val:
                try:
                    user_uuid = UUID(str(user_id_val))
                    user = await session.get(User, user_uuid)
                    if user and user.name:
                        speaker = user.name
                    elif user and user.email:
                        speaker = user.email
                except Exception:
                    pass

            transcript = Transcript(
                id=uuid.uuid4(),
                meeting_id=self.meeting_id,
                speaker=speaker,
                text=text,
                timestamp=timestamp,
            )
            session.add(transcript)
            await session.commit()
            await session.refresh(transcript)

        redis = get_redis()
        await redis.publish(
            meeting_channel(self.meeting_id),
            serialize_message(
                "transcript_segment",
                {
                    "id": str(transcript.id),
                    "speaker": transcript.speaker,
                    "text": transcript.text,
                    "timestamp": transcript.timestamp,
                },
            ),
        )


sessions: dict[UUID, StreamingSession] = {}


def _get_session(meeting_id: UUID) -> StreamingSession:
    session = sessions.get(meeting_id)
    if session is None:
        session = StreamingSession(meeting_id, language_code=STT_LANGUAGE)
        sessions[meeting_id] = session
        asyncio.create_task(session.start())
    return session


async def _handle_payload(meeting_id: UUID, payload: dict[str, Any]) -> None:
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

    try:
        audio_bytes = base64.b64decode(chunk_base64, validate=False)
    except (ValueError, TypeError):
        return
    if not audio_bytes:
        return

    meta = {
        "speaker": chunk_speaker or payload.get("speaker"),
        "timestamp": chunk_timestamp or payload.get("timestamp"),
        "receivedAt": payload.get("receivedAt"),
        "userId": payload.get("userId"),
    }
    session = _get_session(meeting_id)
    await session.enqueue(audio_bytes, meta)


async def _drain_queue(redis, key: str, meeting_id: UUID) -> bool:
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
            await _handle_payload(meeting_id, payload)
        except Exception as exc:
            logger.exception("Failed to process audio chunk: %s", exc)
    return consumed


async def _is_meeting_active(meeting_id: UUID) -> bool:
    async with AsyncSessionLocal() as session:
        meeting = await session.get(Meeting, meeting_id)
        return bool(meeting and meeting.status == "in-progress")


async def _stop_session(meeting_id: UUID) -> None:
    session = sessions.pop(meeting_id, None)
    if session:
        await session.stop()


async def run_worker() -> None:
    logger.info("STT streaming worker started. Poll interval %ss", STT_POLL_INTERVAL)

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
                await redis.delete(key)
                await _stop_session(meeting_id)
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
