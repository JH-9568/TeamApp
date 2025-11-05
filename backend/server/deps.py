from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError

from .config import JWT_SECRET, JWT_ALGORITHM
from .db import get_db
from .models import User, TeamMember, Meeting
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

bearer_scheme = HTTPBearer()

async def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
):
    token = creds.credentials
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id: str = payload.get("sub")
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    stmt = select(User).where(User.id == user_id)
    res = await db.execute(stmt)
    user = res.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return user


async def ensure_team_member(
    db: AsyncSession,
    team_id: UUID,
    user_id: UUID,
) -> TeamMember:
    stmt = (
        select(TeamMember)
        .where(TeamMember.team_id == team_id, TeamMember.user_id == user_id)
    )
    res = await db.execute(stmt)
    member = res.scalar_one_or_none()
    if not member:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not a member of this team",
        )
    return member


async def ensure_team_owner(
    db: AsyncSession,
    team_id: UUID,
    user_id: UUID,
) -> TeamMember:
    member = await ensure_team_member(db, team_id, user_id)
    if member.role != "owner":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Owner permissions required",
        )
    return member


async def ensure_meeting_access(
    db: AsyncSession,
    meeting_id: UUID,
    user_id: UUID,
) -> Meeting:
    stmt = select(Meeting).where(Meeting.id == meeting_id)
    res = await db.execute(stmt)
    meeting = res.scalar_one_or_none()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")

    await ensure_team_member(db, meeting.team_id, user_id)
    return meeting
