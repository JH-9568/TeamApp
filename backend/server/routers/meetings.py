import uuid
from datetime import datetime, date, time
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..db import get_db
from ..deps import ensure_meeting_access, ensure_team_member, get_current_user
from ..models import ActionItem, Meeting, User
from ..schemas import (
    MeetingCreateRequest,
    MeetingListResponse,
    MeetingListItem,
    MeetingResponse,
    MeetingEnvelope,
    MeetingDetailResponse,
    MeetingDetailEnvelope,
    MeetingUpdateRequest,
    TranscriptItem,
    ActionItemResponse,
    SpeakerStatisticResponse,
)

router = APIRouter(prefix="/api", tags=["meetings"])


def format_date(value: Optional[date]) -> Optional[str]:
    return value.isoformat() if value else None


def format_time(value: Optional[time]) -> Optional[str]:
    return value.isoformat(timespec="minutes") if value else None


def serialize_meeting(meeting: Meeting) -> MeetingResponse:
    return MeetingResponse(
        id=meeting.id,
        team_id=meeting.team_id,
        title=meeting.title,
        date=format_date(meeting.date),
        start_time=format_time(meeting.start_time),
        end_time=format_time(meeting.end_time),
        duration=meeting.duration,
        status=meeting.status,
        summary=meeting.summary,
        recording_url=meeting.recording_url,
    )


@router.get("/teams/{team_id}/meetings", response_model=MeetingListResponse)
async def list_team_meetings(
    team_id: UUID,
    status_filter: Optional[str] = Query(None, alias="status"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MeetingListResponse:
    await ensure_team_member(db, team_id, current_user.id)

    stmt = (
        select(
            Meeting,
            func.count(ActionItem.id).label("action_items_count"),
        )
        .outerjoin(ActionItem, ActionItem.meeting_id == Meeting.id)
        .where(Meeting.team_id == team_id)
        .group_by(Meeting.id)
        .order_by(Meeting.date.desc(), Meeting.start_time.desc())
    )
    if status_filter:
        stmt = stmt.where(Meeting.status == status_filter)

    res = await db.execute(stmt)
    meetings = res.all()

    items: list[MeetingListItem] = []
    for meeting, action_items_count in meetings:
        items.append(
            MeetingListItem(
                id=meeting.id,
                team_id=meeting.team_id,
                title=meeting.title,
                date=format_date(meeting.date),
                start_time=format_time(meeting.start_time),
                end_time=format_time(meeting.end_time),
                duration=meeting.duration,
                status=meeting.status,
                summary=meeting.summary,
                action_items_count=action_items_count or 0,
            )
        )

    return MeetingListResponse(meetings=items)


@router.post("/teams/{team_id}/meetings", response_model=MeetingEnvelope, status_code=status.HTTP_201_CREATED)
async def create_meeting(
    team_id: UUID,
    payload: MeetingCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MeetingEnvelope:
    await ensure_team_member(db, team_id, current_user.id)

    now = datetime.utcnow()
    meeting_date = payload.date or now.date()
    meeting_start: time = payload.start_time or now.replace(microsecond=0).time()

    meeting = Meeting(
        id=uuid.uuid4(),
        team_id=team_id,
        title=payload.title,
        date=meeting_date,
        start_time=meeting_start,
        status="in-progress",
        created_at=now,
        updated_at=now,
    )
    db.add(meeting)
    await db.commit()
    await db.refresh(meeting)

    return MeetingEnvelope(meeting=serialize_meeting(meeting))


@router.get("/meetings/{meeting_id}", response_model=MeetingDetailEnvelope)
async def get_meeting(
    meeting_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MeetingDetailEnvelope:
    meeting = await ensure_meeting_access(db, meeting_id, current_user.id)

    stmt = (
        select(Meeting)
        .options(
            selectinload(Meeting.transcripts),
            selectinload(Meeting.action_items),
            selectinload(Meeting.speaker_stats),
            selectinload(Meeting.attendees),
        )
        .where(Meeting.id == meeting.id)
    )
    res = await db.execute(stmt)
    meeting = res.scalar_one()

    transcripts = [
        TranscriptItem(
            id=t.id,
            speaker=t.speaker,
            text=t.text,
            timestamp=t.timestamp,
            start_time=t.start_time,
            end_time=t.end_time,
        )
        for t in sorted(meeting.transcripts, key=lambda item: item.created_at)
    ]

    action_items = [
        ActionItemResponse(
            id=item.id,
            meeting_id=item.meeting_id,
            type=item.type,
            assignee=item.assignee,
            assignee_user_id=item.assignee_user_id,
            content=item.content,
            status=item.status,
            due_date=item.due_date,
        )
        for item in sorted(meeting.action_items, key=lambda entry: entry.created_at, reverse=True)
    ]

    speaker_stats = [
        SpeakerStatisticResponse(
            id=stat.id,
            speaker=stat.speaker,
            speak_time=stat.speak_time,
            speak_count=stat.speak_count,
            participation_rate=stat.participation_rate,
            avg_length=stat.avg_length,
        )
        for stat in sorted(meeting.speaker_stats, key=lambda entry: entry.speak_time, reverse=True)
    ]

    detail = MeetingDetailResponse(
        id=meeting.id,
        team_id=meeting.team_id,
        title=meeting.title,
        date=format_date(meeting.date),
        start_time=format_time(meeting.start_time),
        end_time=format_time(meeting.end_time),
        duration=meeting.duration,
        status=meeting.status,
        summary=meeting.summary,
        recording_url=meeting.recording_url,
        transcripts=transcripts,
        action_items=action_items,
        speaker_stats=speaker_stats,
    )

    return MeetingDetailEnvelope(meeting=detail)


@router.patch("/meetings/{meeting_id}", response_model=MeetingEnvelope)
async def update_meeting(
    meeting_id: UUID,
    payload: MeetingUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MeetingEnvelope:
    meeting = await ensure_meeting_access(db, meeting_id, current_user.id)

    if payload.end_time is not None:
        meeting.end_time = payload.end_time
    if payload.summary is not None:
        meeting.summary = payload.summary
    if payload.status is not None:
        meeting.status = payload.status
    if payload.duration is not None:
        meeting.duration = payload.duration
    elif meeting.end_time and meeting.start_time:
        delta = datetime.combine(date.today(), meeting.end_time) - datetime.combine(
            date.today(), meeting.start_time
        )
        meeting.duration = int(delta.total_seconds() // 60)

    meeting.updated_at = datetime.utcnow()
    db.add(meeting)
    await db.commit()
    await db.refresh(meeting)

    return MeetingEnvelope(meeting=serialize_meeting(meeting))
