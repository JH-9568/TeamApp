from __future__ import annotations

from datetime import date, time
from typing import List, Optional
from uuid import UUID

from pydantic import Field, constr

from .base import SchemaBase
from .transcript import TranscriptItem
from .action_item import ActionItemResponse
from .speaker_stat import SpeakerStatisticResponse


class MeetingCreateRequest(SchemaBase):
    title: constr(min_length=1, max_length=200)
    date: Optional[date] = None
    start_time: Optional[time] = Field(None, alias="startTime")


class MeetingUpdateRequest(SchemaBase):
    end_time: Optional[time] = Field(None, alias="endTime")
    duration: Optional[int] = None
    status: Optional[str] = None
    summary: Optional[str] = None


class MeetingListItem(SchemaBase):
    id: UUID
    team_id: UUID = Field(..., alias="teamId")
    title: str
    date: Optional[str] = None
    start_time: Optional[str] = Field(None, alias="startTime")
    end_time: Optional[str] = Field(None, alias="endTime")
    duration: Optional[int] = None
    status: str
    summary: Optional[str] = None
    action_items_count: int = Field(..., alias="actionItemsCount")


class MeetingListResponse(SchemaBase):
    meetings: List[MeetingListItem]


class MeetingResponse(SchemaBase):
    id: UUID
    team_id: UUID = Field(..., alias="teamId")
    title: str
    date: Optional[str] = None
    start_time: Optional[str] = Field(None, alias="startTime")
    end_time: Optional[str] = Field(None, alias="endTime")
    duration: Optional[int] = None
    status: str
    summary: Optional[str] = None
    recording_url: Optional[str] = Field(None, alias="recordingUrl")


class MeetingEnvelope(SchemaBase):
    meeting: MeetingResponse


class MeetingDetailResponse(SchemaBase):
    id: UUID
    team_id: UUID = Field(..., alias="teamId")
    title: str
    date: Optional[str] = None
    start_time: Optional[str] = Field(None, alias="startTime")
    end_time: Optional[str] = Field(None, alias="endTime")
    duration: Optional[int] = None
    status: str
    summary: Optional[str] = None
    recording_url: Optional[str] = Field(None, alias="recordingUrl")
    transcripts: list[TranscriptItem] = []
    action_items: list[ActionItemResponse] = Field(default_factory=list, alias="actionItems")
    speaker_stats: list[SpeakerStatisticResponse] = Field(default_factory=list, alias="speakerStats")


class MeetingDetailEnvelope(SchemaBase):
    meeting: MeetingDetailResponse
