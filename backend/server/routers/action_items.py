import uuid
from datetime import datetime
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_db
from ..deps import ensure_meeting_access, ensure_team_member, get_current_user
from ..models import ActionItem, Meeting, User
from ..schemas import (
    ActionItemCreateRequest,
    ActionItemListItem,
    ActionItemListResponse,
    ActionItemResponse,
    ActionItemUpdateRequest,
)

router = APIRouter(prefix="/api", tags=["action-items"])


@router.get("/teams/{team_id}/action-items", response_model=ActionItemListResponse)
async def list_team_action_items(
    team_id: UUID,
    assignee: Optional[UUID] = Query(None),
    status_filter: Optional[str] = Query(None, alias="status"),
    search: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ActionItemListResponse:
    await ensure_team_member(db, team_id, current_user.id)

    stmt = (
        select(ActionItem, Meeting)
        .join(Meeting, Meeting.id == ActionItem.meeting_id)
        .where(Meeting.team_id == team_id)
        .order_by(ActionItem.due_date.asc().nullslast(), ActionItem.created_at.desc())
    )
    if assignee:
        stmt = stmt.where(ActionItem.assignee_user_id == assignee)
    if status_filter:
        stmt = stmt.where(ActionItem.status == status_filter)
    if search:
        stmt = stmt.where(ActionItem.content.ilike(f"%{search}%"))

    res = await db.execute(stmt)
    rows = res.all()

    return ActionItemListResponse(
        action_items=[
            ActionItemListItem(
                id=action.id,
                meeting_id=action.meeting_id,
                meeting_title=meeting.title,
                meeting_date=meeting.date,
                type=action.type,
                assignee=action.assignee,
                assignee_user_id=action.assignee_user_id,
                content=action.content,
                status=action.status,
                due_date=action.due_date,
            )
            for action, meeting in rows
        ]
    )


@router.post(
    "/meetings/{meeting_id}/action-items",
    response_model=ActionItemResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_action_item(
    meeting_id: UUID,
    payload: ActionItemCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ActionItemResponse:
    meeting = await ensure_meeting_access(db, meeting_id, current_user.id)

    action_item = ActionItem(
        id=uuid.uuid4(),
        meeting_id=meeting.id,
        type=payload.type,
        assignee=payload.assignee,
        assignee_user_id=payload.assignee_user_id,
        content=payload.content,
        status=payload.status,
        due_date=payload.due_date,
    )
    db.add(action_item)
    await db.commit()
    await db.refresh(action_item)

    return ActionItemResponse(
        id=action_item.id,
        meeting_id=action_item.meeting_id,
        type=action_item.type,
        assignee=action_item.assignee,
        assignee_user_id=action_item.assignee_user_id,
        content=action_item.content,
        status=action_item.status,
        due_date=action_item.due_date,
    )


async def _load_action_item(
    db: AsyncSession,
    action_item_id: UUID,
) -> tuple[ActionItem, Meeting]:
    stmt = (
        select(ActionItem, Meeting)
        .join(Meeting, Meeting.id == ActionItem.meeting_id)
        .where(ActionItem.id == action_item_id)
    )
    res = await db.execute(stmt)
    row = res.one_or_none()
    if not row:
        raise HTTPException(status_code=404, detail="Action item not found")
    return row


@router.patch("/action-items/{action_item_id}", response_model=ActionItemResponse)
async def update_action_item(
    action_item_id: UUID,
    payload: ActionItemUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ActionItemResponse:
    action_item, meeting = await _load_action_item(db, action_item_id)
    await ensure_team_member(db, meeting.team_id, current_user.id)

    for field, value in payload.dict(exclude_unset=True).items():
        if field == "due_date":
            action_item.due_date = value
        elif field == "assignee_user_id":
            action_item.assignee_user_id = value
        elif field == "assignee":
            action_item.assignee = value
        elif field == "type":
            action_item.type = value
        elif field == "status":
            action_item.status = value
        elif field == "content":
            action_item.content = value

    action_item.updated_at = datetime.utcnow()
    db.add(action_item)
    await db.commit()
    await db.refresh(action_item)

    return ActionItemResponse(
        id=action_item.id,
        meeting_id=action_item.meeting_id,
        type=action_item.type,
        assignee=action_item.assignee,
        assignee_user_id=action_item.assignee_user_id,
        content=action_item.content,
        status=action_item.status,
        due_date=action_item.due_date,
    )


@router.delete("/action-items/{action_item_id}")
async def delete_action_item(
    action_item_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict:
    action_item, meeting = await _load_action_item(db, action_item_id)
    await ensure_team_member(db, meeting.team_id, current_user.id)

    await db.delete(action_item)
    await db.commit()

    return {"message": "Deleted successfully"}
