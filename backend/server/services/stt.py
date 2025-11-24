from __future__ import annotations

import asyncio
import base64
from typing import Optional

from ..config import WHISPER_DEVICE, WHISPER_MODEL

try:
    import whisper  # type: ignore
    import numpy as np
except ImportError:  # pragma: no cover
    whisper = None  # type: ignore
    np = None  # type: ignore


class WhisperNotAvailableError(RuntimeError):
    """Raised when the Whisper dependency is missing."""


class WhisperService:
    def __init__(self, model_name: str, device: str = "cpu") -> None:
        self.model_name = model_name
        self.device = device
        self._model = None
        self._lock = asyncio.Lock()

    async def transcribe_base64(self, chunk_base64: str) -> Optional[str]:
        if not chunk_base64:
            return None

        await self._ensure_model()
        assert self._model is not None  # for mypy

        if np is None:  # pragma: no cover
            raise WhisperNotAvailableError("NumPy is required for Whisper transcription.")

        audio_bytes = base64.b64decode(chunk_base64, validate=False)
        if len(audio_bytes) < 2:
            return None

        # Ensure we only decode complete 16-bit samples
        if len(audio_bytes) % 2:
            audio_bytes = audio_bytes[:-1]

        audio_samples = np.frombuffer(audio_bytes, dtype=np.int16)
        if audio_samples.size == 0:
            return None

        audio = audio_samples.astype(np.float32) / 32768.0
        loop = asyncio.get_running_loop()
        result = await loop.run_in_executor(
            None, lambda: self._model.transcribe(audio, fp16=False)
        )

        text = (result or {}).get("text", "")
        text = text.strip() if isinstance(text, str) else ""
        return text or None

    async def _ensure_model(self) -> None:
        if self._model is None:
            async with self._lock:
                if self._model is None:
                    self._model = await self._load_model()

    async def _load_model(self):
        if whisper is None:
            raise WhisperNotAvailableError(
                "openai-whisper is not installed. Run `pip install openai-whisper`."
            )
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(
            None, lambda: whisper.load_model(self.model_name, device=self.device)
        )


_whisper_service: WhisperService | None = None


def get_whisper_service() -> WhisperService:
    global _whisper_service
    if _whisper_service is None:
        _whisper_service = WhisperService(WHISPER_MODEL, device=WHISPER_DEVICE)
    return _whisper_service
