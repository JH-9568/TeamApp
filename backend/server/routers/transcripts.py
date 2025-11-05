import uuid
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_db
from ..deps import ensure_meeting_access, get_current_user
from ..models import Transcript, User
from ..schemas import TranscriptCreateRequest, TranscriptEnvelope, TranscriptListResponse, TranscriptItem

router = APIRouter(prefix="/api/meetings", tags=["transcript"])


@router.post("/{meeting_id}/transcript", response_model=TranscriptEnvelope, status_code=status.HTTP_201_CREATED)
async def add_transcript_segment(
    meeting_id: UUID,
    payload: TranscriptCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> TranscriptEnvelope:
    await ensure_meeting_access(db, meeting_id, current_user.id)

    transcript = Transcript(
        id=uuid.uuid4(),
        meeting_id=meeting_id,
        speaker=payload.speaker,
        text=payload.text,
        timestamp=payload.timestamp,
        start_time=payload.start_time,
        end_time=payload.end_time,
    )
    db.add(transcript)
    await db.commit()
    await db.refresh(transcript)

    return TranscriptEnvelope(
        transcript=TranscriptItem(
            id=transcript.id,
            speaker=transcript.speaker,
            text=transcript.text,
            timestamp=transcript.timestamp,
            start_time=transcript.start_time,
            end_time=transcript.end_time,
        )
    )


@router.get("/{meeting_id}/transcript", response_model=TranscriptListResponse)
async def get_transcript(
    meeting_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> TranscriptListResponse:
    await ensure_meeting_access(db, meeting_id, current_user.id)

    stmt = (
        select(Transcript)
        .where(Transcript.meeting_id == meeting_id)
        .order_by(Transcript.created_at.asc())
    )
    res = await db.execute(stmt)
    rows = res.scalars().all()

    return TranscriptListResponse(
        transcript=[
            TranscriptItem(
                id=row.id,
                speaker=row.speaker,
                text=row.text,
                timestamp=row.timestamp,
                start_time=row.start_time,
                end_time=row.end_time,
            )
            for row in rows
        ]
    )
