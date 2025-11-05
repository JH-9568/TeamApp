from __future__ import annotations

from pydantic import EmailStr, constr

from .base import SchemaBase
from .user import UserResponse


class RegisterRequest(SchemaBase):
    email: EmailStr
    password: constr(min_length=8, max_length=128)
    name: constr(min_length=1, max_length=100)


class LoginRequest(SchemaBase):
    email: EmailStr
    password: constr(min_length=8, max_length=128)


class TokenResponse(SchemaBase):
    token: str


class AuthResponse(SchemaBase):
    user: UserResponse
    token: str
