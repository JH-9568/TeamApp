import uuid
from datetime import datetime
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..db import get_db
from ..deps import get_current_user, ensure_team_member, ensure_team_owner
from ..models import Team, TeamMember, User
from ..schemas import (
    TeamListResponse,
    TeamResponse,
    TeamCreateRequest,
    TeamEnvelope,
    TeamJoinRequest,
    TeamDetailEnvelope,
    TeamDetailResponse,
    TeamMemberResponse,
    TeamUpdateRequest,
)

router = APIRouter(prefix="/api/teams", tags=["teams"])


def serialize_team(team: Team) -> TeamResponse:
    return TeamResponse(id=team.id, name=team.name, invite_code=team.invite_code)


@router.get("", response_model=TeamListResponse)
async def list_my_teams(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> TeamListResponse:
    stmt = (
        select(Team)
        .join(TeamMember, TeamMember.team_id == Team.id)
        .where(TeamMember.user_id == current_user.id)
    )
    res = await db.execute(stmt)
    teams = res.scalars().all()

    return TeamListResponse(teams=[serialize_team(team) for team in teams])


@router.post("", response_model=TeamEnvelope, status_code=status.HTTP_201_CREATED)
async def create_team(
    payload: TeamCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> TeamEnvelope:
    now = datetime.utcnow()
    invite_code = uuid.uuid4().hex[:8].upper()

    team = Team(
        id=uuid.uuid4(),
        name=payload.name,
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

    return TeamEnvelope(team=serialize_team(team))


@router.get("/{team_id}", response_model=TeamDetailEnvelope)
async def get_team(
    team_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> TeamDetailEnvelope:
    stmt = (
        select(Team)
        .options(selectinload(Team.members).selectinload(TeamMember.user))
        .where(Team.id == team_id)
    )
    res = await db.execute(stmt)
    team = res.scalar_one_or_none()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    await ensure_team_member(db, team.id, current_user.id)

    members: List[TeamMemberResponse] = []
    for member in team.members:
        members.append(
            TeamMemberResponse(
                id=member.user.id if member.user else member.id,
                name=member.user.name if member.user else "Guest",
                email=member.user.email if member.user else None,
                role=member.role,
                avatar=member.user.avatar_url if member.user else None,
            )
        )

    return TeamDetailEnvelope(
        team=TeamDetailResponse(
            id=team.id,
            name=team.name,
            invite_code=team.invite_code,
            members=members,
        )
    )


@router.post("/join", response_model=TeamEnvelope)
async def join_team(
    payload: TeamJoinRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> TeamEnvelope:
    invite_code = payload.invite_code.strip().upper()

    stmt = select(Team).where(Team.invite_code == invite_code)
    res = await db.execute(stmt)
    team = res.scalar_one_or_none()
    if not team:
        raise HTTPException(status_code=404, detail="Invalid invite code")

    stmt_member = (
        select(TeamMember)
        .where(TeamMember.team_id == team.id, TeamMember.user_id == current_user.id)
    )
    res_member = await db.execute(stmt_member)
    member = res_member.scalar_one_or_none()
    if member:
        raise HTTPException(status_code=400, detail="Already a member of this team")

    now = datetime.utcnow()
    new_member = TeamMember(
        id=uuid.uuid4(),
        team_id=team.id,
        user_id=current_user.id,
        role="member",
        joined_at=now,
    )
    db.add(new_member)
    await db.commit()
    await db.refresh(team)

    return TeamEnvelope(team=serialize_team(team))


@router.patch("/{team_id}", response_model=TeamEnvelope)
async def update_team(
    team_id: UUID,
    payload: TeamUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> TeamEnvelope:
    if payload.name is None:
        raise HTTPException(status_code=400, detail="No fields provided")

    stmt = select(Team).where(Team.id == team_id)
    res = await db.execute(stmt)
    team = res.scalar_one_or_none()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    await ensure_team_owner(db, team.id, current_user.id)

    team.name = payload.name
    team.updated_at = datetime.utcnow()
    db.add(team)
    await db.commit()
    await db.refresh(team)

    return TeamEnvelope(team=serialize_team(team))
