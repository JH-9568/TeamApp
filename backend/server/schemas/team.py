from typing import List, Optional
from uuid import UUID

from pydantic import Field, constr

from .base import SchemaBase


class TeamMemberResponse(SchemaBase):
    id: UUID
    name: str
    email: Optional[str] = None
    role: str
    avatar: Optional[str] = None


class TeamResponse(SchemaBase):
    id: UUID
    name: str
    invite_code: str = Field(..., alias="inviteCode")


class TeamListResponse(SchemaBase):
    teams: List[TeamResponse]


class TeamCreateRequest(SchemaBase):
    name: constr(min_length=1, max_length=100)


class TeamJoinRequest(SchemaBase):
    invite_code: constr(min_length=1, max_length=20) = Field(..., alias="inviteCode")


class TeamDetailResponse(SchemaBase):
    id: UUID
    name: str
    invite_code: str = Field(..., alias="inviteCode")
    members: List[TeamMemberResponse]


class TeamUpdateRequest(SchemaBase):
    name: Optional[constr(min_length=1, max_length=100)] = None


class TeamEnvelope(SchemaBase):
    team: TeamResponse


class TeamDetailEnvelope(SchemaBase):
    team: TeamDetailResponse
