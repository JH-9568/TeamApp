from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import constr, Field

from .base import SchemaBase


class MeetingAttendeeCreateRequest(SchemaBase):
    user_id: Optional[UUID] = None
    guest_name: Optional[constr(min_length=1, max_length=100)] = None


class MeetingAttendeeResponse(SchemaBase):
    id: UUID
    user_id: Optional[UUID] = None
    user_name: Optional[str] = Field(None, alias="userName")
    guest_name: Optional[str] = None
    joined_at: Optional[datetime] = None


class MeetingAttendeeListResponse(SchemaBase):
    attendees: List[MeetingAttendeeResponse]


class MeetingAttendeeEnvelope(SchemaBase):
    attendee: MeetingAttendeeResponse
