import uuid
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_db
from ..deps import ensure_meeting_access, get_current_user
from ..models import MeetingAttendee, User
from ..schemas import (
    MeetingAttendeeCreateRequest,
    MeetingAttendeeEnvelope,
    MeetingAttendeeListResponse,
    MeetingAttendeeResponse,
)

router = APIRouter(prefix="/api/meetings", tags=["attendees"])


@router.post("/{meeting_id}/attendees", response_model=MeetingAttendeeEnvelope, status_code=status.HTTP_201_CREATED)
async def add_attendee(
    meeting_id: UUID,
    payload: MeetingAttendeeCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MeetingAttendeeEnvelope:
    meeting = await ensure_meeting_access(db, meeting_id, current_user.id)

    if payload.user_id is None and not payload.guest_name:
        raise HTTPException(status_code=400, detail="userId or guestName required")

    stmt = select(MeetingAttendee).where(MeetingAttendee.meeting_id == meeting.id)
    if payload.user_id:
        stmt = stmt.where(MeetingAttendee.user_id == payload.user_id)
    elif payload.guest_name:
        stmt = stmt.where(MeetingAttendee.guest_name == payload.guest_name)
    res = await db.execute(stmt)
    existing = res.scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=400, detail="Attendee already added")

    attendee = MeetingAttendee(
        id=uuid.uuid4(),
        meeting_id=meeting.id,
        user_id=payload.user_id,
        guest_name=payload.guest_name,
    )
    db.add(attendee)
    await db.commit()
    await db.refresh(attendee)

    return MeetingAttendeeEnvelope(
        attendee=MeetingAttendeeResponse(
            id=attendee.id,
            user_id=attendee.user_id,
            guest_name=attendee.guest_name,
            joined_at=attendee.joined_at,
        )
    )


@router.get("/{meeting_id}/attendees", response_model=MeetingAttendeeListResponse)
async def list_attendees(
    meeting_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MeetingAttendeeListResponse:
    meeting = await ensure_meeting_access(db, meeting_id, current_user.id)

    stmt = (
        select(MeetingAttendee)
        .where(MeetingAttendee.meeting_id == meeting.id)
        .order_by(MeetingAttendee.joined_at.asc())
    )
    res = await db.execute(stmt)
    attendees = res.scalars().all()

    return MeetingAttendeeListResponse(
        attendees=[
            MeetingAttendeeResponse(
                id=row.id,
                user_id=row.user_id,
                guest_name=row.guest_name,
                joined_at=row.joined_at,
            )
            for row in attendees
        ]
    )
