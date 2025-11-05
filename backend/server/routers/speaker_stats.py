import uuid
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_db
from ..deps import ensure_meeting_access, get_current_user
from ..models import SpeakerStatistic, User
from ..schemas import (
    SpeakerStatisticCreateRequest,
    SpeakerStatisticListResponse,
    SpeakerStatisticResponse,
)

router = APIRouter(prefix="/api/meetings", tags=["speaker-stats"])


@router.post("/{meeting_id}/speaker-stats", response_model=SpeakerStatisticListResponse)
async def save_speaker_stats(
    meeting_id: UUID,
    payload: List[SpeakerStatisticCreateRequest],
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SpeakerStatisticListResponse:
    meeting = await ensure_meeting_access(db, meeting_id, current_user.id)

    await db.execute(delete(SpeakerStatistic).where(SpeakerStatistic.meeting_id == meeting.id))
    await db.commit()

    stats: list[SpeakerStatisticResponse] = []
    for stat_payload in payload:
        stat = SpeakerStatistic(
            id=uuid.uuid4(),
            meeting_id=meeting.id,
            speaker=stat_payload.speaker,
            speak_time=stat_payload.speak_time,
            speak_count=stat_payload.speak_count,
            participation_rate=stat_payload.participation_rate,
            avg_length=stat_payload.avg_length,
        )
        db.add(stat)
        await db.flush()
        stats.append(
            SpeakerStatisticResponse(
                id=stat.id,
                speaker=stat.speaker,
                speak_time=stat.speak_time,
                speak_count=stat.speak_count,
                participation_rate=stat.participation_rate,
                avg_length=stat.avg_length,
            )
        )

    await db.commit()

    return SpeakerStatisticListResponse(speaker_stats=stats)
