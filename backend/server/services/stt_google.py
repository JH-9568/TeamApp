from __future__ import annotations

import asyncio
import base64
import math
import uuid
from typing import Optional

from .stt import STTNotAvailableError

try:
    from google.api_core.exceptions import GoogleAPIError
    from google.cloud import speech
except ImportError:  # pragma: no cover - optional dependency
    GoogleAPIError = Exception  # type: ignore
    speech = None


class GoogleSpeechService:
    def __init__(
        self,
        language_code: str = "ko-KR",
        sample_rate: int = 16000,
        enable_punctuation: bool = True,
        min_chunk_seconds: float = 1.0,
        max_buffer_seconds: float = 4.0,
        silence_rms_threshold: float = 400.0,
    ) -> None:
        if speech is None:
            raise STTNotAvailableError(
                "google-cloud-speech is not installed. Run `pip install google-cloud-speech`."
            )
        self.language_code = language_code
        self.sample_rate = sample_rate
        self.enable_punctuation = enable_punctuation
        # Lower the chunk size for faster, more responsive transcripts.
        # (Previously 3.5s/8s; now 1.0s min, 4.0s max)
        self.min_chunk_seconds = min_chunk_seconds
        self.max_buffer_seconds = max_buffer_seconds
        self.silence_rms_threshold = silence_rms_threshold
        self._client = speech.SpeechClient()
        self._buffers: dict[str, bytearray] = {}

    async def transcribe_base64(
        self, meeting_id: uuid.UUID | str, chunk_base64: str
    ) -> Optional[str]:
        if not chunk_base64:
            return None

        try:
            audio_bytes = base64.b64decode(chunk_base64, validate=False)
        except (ValueError, TypeError):
            return None

        if len(audio_bytes) < 320:  # ~10ms at 16kHz
            return None

        if len(audio_bytes) % 2:
            audio_bytes = audio_bytes[:-1]

        if self._is_silence(audio_bytes):
            return None

        # Accumulate per meeting to give Google STT a meaningful chunk.
        meeting_key = str(meeting_id)
        buffer = self._buffers.get(meeting_key)
        if buffer is None:
            buffer = bytearray()
            self._buffers[meeting_key] = buffer
        buffer.extend(audio_bytes)

        max_bytes = int(self.sample_rate * 2 * self.max_buffer_seconds)
        if len(buffer) > max_bytes:
            buffer[:] = buffer[-max_bytes:]

        min_bytes = int(self.sample_rate * 2 * self.min_chunk_seconds)
        if len(buffer) < min_bytes:
            return None

        config = speech.RecognitionConfig(
            encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
            sample_rate_hertz=self.sample_rate,
            language_code=self.language_code,
            enable_automatic_punctuation=self.enable_punctuation,
            model="default",
        )
        audio = speech.RecognitionAudio(content=bytes(buffer))

        loop = asyncio.get_running_loop()
        try:
            response = await loop.run_in_executor(
                None, lambda: self._client.recognize(config=config, audio=audio)
            )
        except GoogleAPIError as exc:
            raise STTNotAvailableError(f"Google STT request failed: {exc}") from exc

        # Reset buffer after an attempt to avoid repeated calls on the same audio
        buffer.clear()

        if not response or not response.results:
            return None
        for result in response.results:
            if not result.alternatives:
                continue
            text = (result.alternatives[0].transcript or "").strip()
            if text:
                return text
        return None

    def _is_silence(self, audio_bytes: bytes) -> bool:
        sample_count = len(audio_bytes) // 2
        if sample_count == 0:
            return True
        accum = 0.0
        for i in range(0, len(audio_bytes), 2):
            sample = int.from_bytes(audio_bytes[i : i + 2], "little", signed=True)
            accum += sample * sample
        rms = math.sqrt(accum / sample_count)
        return rms < self.silence_rms_threshold
