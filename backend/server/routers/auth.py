import uuid
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import (
    ACCESS_TOKEN_EXPIRE_MINUTES,
    JWT_ALGORITHM,
    JWT_SECRET,
    REFRESH_TOKEN_EXPIRE_MINUTES,
)
from ..db import get_db
from ..models import User
from ..schemas import (
    AuthResponse,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
    UserResponse,
)

router = APIRouter(prefix="/api/auth", tags=["auth"])

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")


def _create_token(data: dict, minutes: int, token_type: str) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=minutes)
    to_encode.update({"exp": expire, "type": token_type})
    encoded_jwt = jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGORITHM)
    return encoded_jwt


def create_access_token(data: dict) -> str:
    return _create_token(data, ACCESS_TOKEN_EXPIRE_MINUTES, "access")


def create_refresh_token(data: dict) -> str:
    return _create_token(data, REFRESH_TOKEN_EXPIRE_MINUTES, "refresh")


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(payload: RegisterRequest, db: AsyncSession = Depends(get_db)) -> AuthResponse:
    stmt = select(User).where(User.email == payload.email)
    res = await db.execute(stmt)
    existing = res.scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    now = datetime.utcnow()
    user = User(
        id=uuid.uuid4(),
        email=payload.email,
        name=payload.name,
        password_hash=pwd_context.hash(payload.password),
        created_at=now,
        updated_at=now,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    token = create_access_token({"sub": str(user.id)})
    refresh_token = create_refresh_token({"sub": str(user.id)})
    return AuthResponse(
        user=UserResponse.from_orm(user),
        token=token,
        refresh_token=refresh_token,
    )


@router.post("/login", response_model=AuthResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)) -> AuthResponse:
    stmt = select(User).where(User.email == payload.email)
    res = await db.execute(stmt)
    user = res.scalar_one_or_none()

    if not user or not pwd_context.verify(payload.password, user.password_hash):
        raise HTTPException(status_code=400, detail="Invalid credentials")

    token = create_access_token({"sub": str(user.id)})
    refresh_token = create_refresh_token({"sub": str(user.id)})
    return AuthResponse(
        user=UserResponse.from_orm(user),
        token=token,
        refresh_token=refresh_token,
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    payload: RefreshRequest,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    try:
        decoded = jwt.decode(payload.refresh_token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        if decoded.get("type") != "refresh":
            raise HTTPException(status_code=400, detail="Invalid token type")
        user_id: str | None = decoded.get("sub")
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    stmt = select(User).where(User.id == user_id)
    res = await db.execute(stmt)
    user = res.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    access_token = create_access_token({"sub": str(user.id)})
    refresh_token_value = create_refresh_token({"sub": str(user.id)})
    return TokenResponse(token=access_token, refresh_token=refresh_token_value)
