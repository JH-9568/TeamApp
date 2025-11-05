from typing import List, Optional
from uuid import UUID

from pydantic import Field, constr

from .base import SchemaBase


class TranscriptCreateRequest(SchemaBase):
    speaker: constr(min_length=1, max_length=100)
    text: constr(min_length=1)
    timestamp: constr(min_length=1)
    start_time: Optional[float] = Field(None, alias="startTime")
    end_time: Optional[float] = Field(None, alias="endTime")


class TranscriptItem(SchemaBase):
    id: UUID
    speaker: str
    text: str
    timestamp: str
    start_time: Optional[float] = Field(None, alias="startTime")
    end_time: Optional[float] = Field(None, alias="endTime")


class TranscriptListResponse(SchemaBase):
    transcript: List[TranscriptItem]


class TranscriptEnvelope(SchemaBase):
    transcript: TranscriptItem
