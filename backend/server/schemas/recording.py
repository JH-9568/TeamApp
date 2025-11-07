from __future__ import annotations

from datetime import datetime

from pydantic import Field

from .base import SchemaBase


class RecordingUploadResponse(SchemaBase):
    upload_url: str = Field(..., alias="uploadUrl")
    recording_url: str = Field(..., alias="recordingUrl")
    method: str = "PUT"
    expires_at: datetime = Field(..., alias="expiresAt")
