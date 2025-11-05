from typing import List, Optional
from uuid import UUID

from pydantic import Field, conint, confloat, constr

from .base import SchemaBase


class SpeakerStatisticCreateRequest(SchemaBase):
    speaker: constr(min_length=1, max_length=100)
    speak_time: conint(ge=0) = Field(..., alias="speakTime")
    speak_count: conint(ge=0) = Field(..., alias="speakCount")
    participation_rate: Optional[confloat(ge=0, le=100)] = Field(None, alias="participationRate")
    avg_length: Optional[confloat(ge=0)] = Field(None, alias="avgLength")


class SpeakerStatisticResponse(SchemaBase):
    id: UUID
    speaker: str
    speak_time: int = Field(..., alias="speakTime")
    speak_count: int = Field(..., alias="speakCount")
    participation_rate: Optional[float] = Field(None, alias="participationRate")
    avg_length: Optional[float] = Field(None, alias="avgLength")


class SpeakerStatisticListResponse(SchemaBase):
    speaker_stats: List[SpeakerStatisticResponse] = Field(..., alias="speakerStats")
