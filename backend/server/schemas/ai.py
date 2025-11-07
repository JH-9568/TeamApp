from __future__ import annotations

from typing import List, Optional
from uuid import UUID

from pydantic import Field

from .base import SchemaBase


class TranscriptChunk(SchemaBase):
    speaker: str
    text: str
    timestamp: Optional[str] = None


class SummarizeRequest(SchemaBase):
    meeting_id: Optional[UUID] = Field(None, alias="meetingId")
    transcript: Optional[List[TranscriptChunk]] = None


class SummarizeResponse(SchemaBase):
    meeting_id: Optional[UUID] = Field(None, alias="meetingId")
    summary: str
    source: str


class ActionItemExtractionRequest(SchemaBase):
    meeting_id: Optional[UUID] = Field(None, alias="meetingId")
    transcript: Optional[List[TranscriptChunk]] = None


class ActionItemSuggestion(SchemaBase):
    id: Optional[UUID] = None
    meeting_id: Optional[UUID] = Field(None, alias="meetingId")
    type: str = "task"
    assignee: Optional[str] = None
    assignee_user_id: Optional[UUID] = Field(None, alias="assigneeUserId")
    content: str
    status: str = "pending"
    due_date: Optional[str] = Field(None, alias="dueDate")


class ActionItemExtractionResponse(SchemaBase):
    meeting_id: Optional[UUID] = Field(None, alias="meetingId")
    action_items: List[ActionItemSuggestion] = Field(default_factory=list, alias="actionItems")
    persisted: bool = False
