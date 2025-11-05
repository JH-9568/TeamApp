from typing import Optional
from uuid import UUID

from pydantic import EmailStr, constr

from .base import SchemaBase


class UserResponse(SchemaBase):
    id: UUID
    email: EmailStr
    name: str
    avatar: Optional[str] = None


class UserUpdateRequest(SchemaBase):
    name: Optional[constr(min_length=1, max_length=100)] = None
    avatar: Optional[str] = None
