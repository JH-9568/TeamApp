from __future__ import annotations

import uuid
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from google.cloud import storage

from ..config import STORAGE_BASE_URL, STORAGE_BUCKET
from ..db import get_db
from ..deps import ensure_meeting_access, get_current_user
from ..models import Meeting, User
from ..schemas import RecordingUploadResponse

router = APIRouter(prefix="/api/meetings", tags=["recordings"])


@router.post("/{meeting_id}/recording", response_model=RecordingUploadResponse)
async def request_recording_upload(
    meeting_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> RecordingUploadResponse:
    meeting = await ensure_meeting_access(db, meeting_id, current_user.id)
    if not STORAGE_BUCKET:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Storage bucket is not configured.",
        )

    expires_at = datetime.utcnow() + timedelta(minutes=10)
    object_key = f"{meeting.id}/{uuid.uuid4()}.wav"

    try:
        client = storage.Client()
        bucket = client.bucket(STORAGE_BUCKET)
        blob = bucket.blob(object_key)
        upload_url = blob.generate_signed_url(
            expiration=expires_at,
            method="PUT",
            content_type="audio/wav",
            version="v4",
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Failed to create signed upload URL: {exc}",
        )

    base_url = STORAGE_BASE_URL.rstrip("/")
    recording_url = f"{base_url}/{object_key}"

    meeting.recording_url = recording_url
    meeting.updated_at = datetime.utcnow()
    db.add(meeting)
    await db.commit()

    return RecordingUploadResponse(
        upload_url=upload_url,
        recording_url=recording_url,
        expires_at=expires_at,
    )
