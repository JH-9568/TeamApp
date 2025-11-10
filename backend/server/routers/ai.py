from __future__ import annotations

from datetime import datetime, date, timedelta
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_db
from ..deps import ensure_meeting_access, get_current_user
from ..models import ActionItem, Meeting, Transcript, User
from ..schemas import (
    ActionItemExtractionRequest,
    ActionItemExtractionResponse,
    ActionItemSuggestion,
    SummarizeRequest,
    SummarizeResponse,
    TranscriptChunk,
)
from ..services.llm import llm_service

router = APIRouter(prefix="/api/ai", tags=["ai"])


async def _load_transcript_for_meeting(db: AsyncSession, meeting: Meeting) -> List[TranscriptChunk]:
    stmt = (
        select(Transcript)
        .where(Transcript.meeting_id == meeting.id)
        .order_by(Transcript.created_at.asc())
    )
    res = await db.execute(stmt)
    rows = res.scalars().all()
    return [
        TranscriptChunk(
            speaker=row.speaker,
            text=row.text,
            timestamp=row.timestamp,
        )
        for row in rows
    ]


@router.post("/summarize", response_model=SummarizeResponse)
async def summarize_meeting(
    payload: SummarizeRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SummarizeResponse:
    transcript = payload.transcript or []
    meeting: Meeting | None = None

    if payload.meeting_id:
        meeting = await ensure_meeting_access(db, payload.meeting_id, current_user.id)
        transcript = await _load_transcript_for_meeting(db, meeting)

    if not transcript:
        raise HTTPException(status_code=400, detail="Transcript data is required.")

    summary = await llm_service.summarize([chunk.model_dump() for chunk in transcript])

    source = llm_service.provider or "heuristic"
    if meeting:
        meeting.summary = summary
        meeting.updated_at = datetime.utcnow()
        db.add(meeting)
        await db.commit()
        await db.refresh(meeting)
        source = f"{source}-persisted"

    return SummarizeResponse(meeting_id=payload.meeting_id, summary=summary, source=source)


@router.post("/extract-action-items", response_model=ActionItemExtractionResponse)
async def extract_action_items(
    payload: ActionItemExtractionRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ActionItemExtractionResponse:
    transcript = payload.transcript or []
    meeting: Meeting | None = None

    if payload.meeting_id:
        meeting = await ensure_meeting_access(db, payload.meeting_id, current_user.id)
        transcript = await _load_transcript_for_meeting(db, meeting)

    if not transcript:
        raise HTTPException(status_code=400, detail="Transcript data is required.")

    suggestions = await llm_service.extract_action_items(
        [chunk.model_dump() for chunk in transcript]
    )
    if not suggestions:
        return ActionItemExtractionResponse(
            meeting_id=payload.meeting_id,
            action_items=[],
            persisted=False,
        )

    if not meeting:
        return ActionItemExtractionResponse(
            meeting_id=None,
            action_items=[
                ActionItemSuggestion(**item) for item in suggestions
            ],
            persisted=False,
        )

    created: list[ActionItemSuggestion] = []
    now = datetime.utcnow()
    for suggestion in suggestions:
        action_item = ActionItem(
            meeting_id=meeting.id,
            type=suggestion.get("type") or "task",
            assignee=suggestion.get("assignee") or "Unassigned",
            content=suggestion.get("content") or "Action item",
            status="pending",
            due_date=_parse_due_date(
                suggestion.get("dueDate"),
                reference_date=meeting.date if meeting else None,
            ),
            created_at=now,
            updated_at=now,
        )
        db.add(action_item)
        await db.flush()
        created.append(
            ActionItemSuggestion(
                id=action_item.id,
                meeting_id=meeting.id,
                type=action_item.type,
                assignee=action_item.assignee,
                content=action_item.content,
                status=action_item.status,
                due_date=action_item.due_date.isoformat() if action_item.due_date else None,
            )
        )

    await db.commit()

    return ActionItemExtractionResponse(
        meeting_id=meeting.id,
        action_items=created,
        persisted=True,
    )
def _parse_due_date(value: str | None, reference_date: date | None = None) -> date | None:
    if not value:
        return None
    value = value.strip()
    try:
        return datetime.fromisoformat(value).date()
    except ValueError:
        pass

    if reference_date:
        normalized = value.replace(" ", "")
        normalized = normalized.replace("까지", "")
        if "이번주" in normalized or "이번주" in normalized:
            weekday_map = {
                "월요일": 0,
                "화요일": 1,
                "수요일": 2,
                "목요일": 3,
                "금요일": 4,
                "토요일": 5,
                "일요일": 6,
                "일": 6,
            }
            for keyword, weekday_idx in weekday_map.items():
                if keyword in normalized:
                    delta = (weekday_idx - reference_date.weekday()) % 7
                    inferred = reference_date + timedelta(days=delta)
                    return inferred
    return None
