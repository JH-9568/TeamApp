import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from ..db import get_db
from ..models import Team, TeamMember
from ..deps import get_current_user

router = APIRouter(prefix="/api/teams", tags=["teams"])


@router.get("")
async def list_my_teams(
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    stmt = (
        select(Team)
        .join(TeamMember, TeamMember.team_id == Team.id)
        .where(TeamMember.user_id == current_user.id)
    )
    res = await db.execute(stmt)
    teams = res.scalars().all()

    return [
        {
            "id": str(t.id),
            "name": t.name,
            "inviteCode": t.invite_code,
        }
        for t in teams
    ]


@router.post("")
async def create_team(
    payload: dict,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    name = payload.get("name")
    if not name:
        raise HTTPException(status_code=400, detail="name required")

    now = datetime.utcnow()
    invite_code = uuid.uuid4().hex[:8].upper()

    team = Team(
        id=uuid.uuid4(),
        name=name,
        invite_code=invite_code,
        created_by=current_user.id,
        created_at=now,
        updated_at=now,
    )
    db.add(team)
    await db.flush()

    member = TeamMember(
        id=uuid.uuid4(),
        team_id=team.id,
        user_id=current_user.id,
        role="owner",
        joined_at=now,
    )
    db.add(member)

    await db.commit()
    await db.refresh(team)

    return {
        "team": {
            "id": str(team.id),
            "name": team.name,
            "inviteCode": team.invite_code,
        }
    }
