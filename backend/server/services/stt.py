from __future__ import annotations

import asyncio
import base64
import re
import time
import uuid
from dataclasses import dataclass, field
from typing import Any, Optional, cast

from ..config import STT_LANGUAGE, STT_PROVIDER, WHISPER_DEVICE, WHISPER_MODEL

try:
    import whisper
    import numpy as np
except ImportError:
    whisper = cast(Any, None)
    np = cast(Any, None)


class STTNotAvailableError(RuntimeError):
    ...


# Backwards-compat alias for existing imports
WhisperNotAvailableError = STTNotAvailableError


@dataclass
class _SessionState:
    sample_rate: int
    max_buffer_samples: int
    overlap_samples: int
    buffer: Optional["np.ndarray"] = None
    last_text: str = ""
    last_activity: float = field(default_factory=time.monotonic)

    def append(self, audio: "np.ndarray") -> None:
        if self.buffer is None or self.buffer.size == 0:
            self.buffer = audio.copy()
        else:
            self.buffer = np.concatenate((self.buffer, audio))
        if self.buffer.size > self.max_buffer_samples:
            self.buffer = self.buffer[-self.max_buffer_samples :]
        self.last_activity = time.monotonic()

    def trim(self, reset: bool) -> None:
        if reset or self.overlap_samples <= 0:
            self.buffer = None
            if reset:
                self.last_text = ""
            return
        if self.buffer is None or self.buffer.size == 0:
            return
        self.buffer = self.buffer[-self.overlap_samples :]

    def duration(self) -> float:
        if self.buffer is None or self.buffer.size == 0:
            return 0.0
        return self.buffer.size / float(self.sample_rate)

    def copy_audio(self) -> "np.ndarray":
        if self.buffer is None:
            return np.zeros(0, dtype=np.float32)
        return self.buffer.copy()

    def has_audio(self) -> bool:
        return self.buffer is not None and self.buffer.size > 0

    def incremental_text(self, text: str) -> Optional[str]:
        clean = text.strip()
        if not clean:
            return None
        if self.last_text and clean.startswith(self.last_text):
            diff = clean[len(self.last_text) :].strip()
        else:
            diff = clean
        self.last_text = clean
        return diff or None


class WhisperService:
    def __init__(
        self,
        model_name: str,
        device: str = "cpu",
        sample_rate: int = 16000,
        context_seconds: float = 8.0,
        overlap_seconds: float = 2.0,
        min_chunk_seconds: float = 1.5,
        flush_silence_seconds: float = 0.8,
        vad_rms_threshold: float = 0.003,
        session_ttl_seconds: float = 60.0,
        noise_gate_floor: float = 0.0002,
    ) -> None:
        self.model_name = model_name
        self.device = device
        self.sample_rate = sample_rate
        self.context_seconds = max(context_seconds, overlap_seconds)
        self.overlap_seconds = overlap_seconds
        self.min_chunk_seconds = min_chunk_seconds
        self.flush_silence_seconds = flush_silence_seconds
        self.vad_rms_threshold = vad_rms_threshold
        self.session_ttl_seconds = session_ttl_seconds
        self.noise_gate_floor = noise_gate_floor

        self.max_buffer_samples = int(self.sample_rate * self.context_seconds)
        self.overlap_samples = int(self.sample_rate * self.overlap_seconds)

        self._model = None
        self._lock = asyncio.Lock()
        self._sessions: dict[str, _SessionState] = {}

    async def transcribe_base64(self, meeting_id: uuid.UUID | str, chunk_base64: str) -> Optional[str]:
        if not chunk_base64:
            return None

        await self._ensure_model()
        model = self._model
        if model is None:
            raise STTNotAvailableError("Whisper model failed to load.")

        if np is None:
            raise STTNotAvailableError("NumPy is required for Whisper transcription.")

        audio_bytes = base64.b64decode(chunk_base64, validate=False)
        meeting_key = str(meeting_id)

        if len(audio_bytes) < 2:
            return None

        if len(audio_bytes) % 2:
            audio_bytes = audio_bytes[:-1]

        audio_samples = np.frombuffer(audio_bytes, dtype=np.int16)
        if audio_samples.size == 0:
            return None

        audio = audio_samples.astype(np.float32) / 32768.0
        audio = self._denoise(audio)
        rms = float(np.sqrt(np.mean(np.square(audio))))
        if not np.isfinite(rms):
            return None

        session = self._get_session(meeting_key)
        is_silence = rms < self.vad_rms_threshold

        if not is_silence:
            session.append(audio)

        if not session.has_audio():
            return None

        duration_seconds = session.duration()
        should_flush = duration_seconds >= self.min_chunk_seconds
        if is_silence and duration_seconds >= self.flush_silence_seconds:
            should_flush = True

        if not should_flush:
            return None

        loop = asyncio.get_running_loop()
        audio_for_model = session.copy_audio()
        result = await loop.run_in_executor(
            None,
            lambda: model.transcribe(
                audio_for_model,
                fp16=False,
                language="ko",
                task="transcribe",
                condition_on_previous_text=True,
                temperature=0.0,
                beam_size=3,
                best_of=1,
            ),
        )

        text = (result or {}).get("text", "")
        text = text.strip() if isinstance(text, str) else ""
        incremental = session.incremental_text(text) or text
        incremental = self._clean_text(incremental)
        session.trim(reset=is_silence)
        self._cleanup_sessions()
        return incremental

    def _denoise(self, audio: "np.ndarray") -> "np.ndarray":
        """Apply a light noise gate to suppress low-level background noise."""
        if audio.size == 0:
            return audio
        # Remove DC offset
        audio = audio - np.mean(audio)
        # Noise gate based on median absolute amplitude (soft)
        median_amp = np.median(np.abs(audio))
        threshold = max(self.noise_gate_floor, median_amp * 0.8)
        return np.where(np.abs(audio) < threshold, 0.0, audio)

    async def _ensure_model(self) -> None:
        if self._model is None:
            async with self._lock:
                if self._model is None:
                    self._model = await self._load_model()

    async def _load_model(self):
        if whisper is None:
            raise STTNotAvailableError(
                "openai-whisper is not installed. Run `pip install openai-whisper`."
            )
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(
            None, lambda: whisper.load_model(self.model_name, device=self.device)
        )

    def _get_session(self, meeting_key: str) -> _SessionState:
        session = self._sessions.get(meeting_key)
        if session is None:
            session = _SessionState(
                sample_rate=self.sample_rate,
                max_buffer_samples=self.max_buffer_samples,
                overlap_samples=self.overlap_samples,
            )
            self._sessions[meeting_key] = session
        return session

    def _clean_text(self, text: Optional[str]) -> Optional[str]:
        if not text:
            return None
        return text.strip() or None

    def _cleanup_sessions(self) -> None:
        if not self._sessions:
            return
        now = time.monotonic()
        expired = [
            key
            for key, session in self._sessions.items()
            if now - session.last_activity > self.session_ttl_seconds
        ]
        for key in expired:
            self._sessions.pop(key, None)


_whisper_service: WhisperService | None = None


def get_whisper_service() -> WhisperService:
    global _whisper_service
    if _whisper_service is None:
        _whisper_service = WhisperService(WHISPER_MODEL, device=WHISPER_DEVICE)
    return _whisper_service


_stt_service: Any | None = None


def get_stt_service():
    """Return the configured STT provider instance."""
    global _stt_service
    if _stt_service is not None:
        return _stt_service

    provider = (STT_PROVIDER or "whisper").lower()
    if provider == "google":
        try:
            from .stt_google import GoogleSpeechService
        except ImportError as exc:  # pragma: no cover - optional dependency
            raise STTNotAvailableError(
                "google-cloud-speech is not installed. Run `pip install google-cloud-speech`."
            ) from exc

        _stt_service = GoogleSpeechService(language_code=STT_LANGUAGE)
    else:
        _stt_service = get_whisper_service()

    return _stt_service
