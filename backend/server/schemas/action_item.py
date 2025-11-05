from datetime import date
from typing import List, Optional
from uuid import UUID

from pydantic import Field, constr

from .base import SchemaBase


class ActionItemCreateRequest(SchemaBase):
    type: constr(min_length=1, max_length=20)
    assignee: constr(min_length=1, max_length=100)
    content: constr(min_length=1)
    status: str = "pending"
    due_date: Optional[date] = Field(None, alias="dueDate")
    assignee_user_id: Optional[UUID] = Field(None, alias="assigneeUserId")


class ActionItemUpdateRequest(SchemaBase):
    type: Optional[constr(min_length=1, max_length=20)] = None
    assignee: Optional[constr(min_length=1, max_length=100)] = None
    content: Optional[constr(min_length=1)] = None
    status: Optional[str] = None
    due_date: Optional[date] = Field(None, alias="dueDate")
    assignee_user_id: Optional[UUID] = Field(None, alias="assigneeUserId")


class ActionItemResponse(SchemaBase):
    id: UUID
    meeting_id: UUID = Field(..., alias="meetingId")
    type: str
    assignee: str
    assignee_user_id: Optional[UUID] = Field(None, alias="assigneeUserId")
    content: str
    status: str
    due_date: Optional[date] = Field(None, alias="dueDate")


class ActionItemListItem(ActionItemResponse):
    meeting_title: Optional[str] = Field(None, alias="meetingTitle")
    meeting_date: Optional[date] = Field(None, alias="meetingDate")


class ActionItemListResponse(SchemaBase):
    action_items: List[ActionItemListItem] = Field(..., alias="actionItems")
