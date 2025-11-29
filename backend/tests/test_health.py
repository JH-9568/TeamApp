import base64

from fastapi.testclient import TestClient

from backend.server.main import app
from backend.server.workers.stt_worker import _is_silence_base64


client = TestClient(app)


def _encode_samples(amplitude: int, samples: int = 400) -> str:
    audio_bytes = b"".join(
        int(amplitude).to_bytes(2, "little", signed=True) for _ in range(samples)
    )
    return base64.b64encode(audio_bytes).decode()


def test_health_endpoint_returns_ok() -> None:
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_is_silence_base64_filters_quiet_audio() -> None:
    encoded = _encode_samples(0)
    assert _is_silence_base64(encoded, threshold=200.0) is True


def test_is_silence_base64_accepts_loud_audio() -> None:
    encoded = _encode_samples(15000)
    assert _is_silence_base64(encoded, threshold=500.0) is False
