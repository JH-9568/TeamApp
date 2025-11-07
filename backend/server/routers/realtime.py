from __future__ import annotations

import asyncio
import contextlib
import json
import uuid
from datetime import datetime
from typing import Any
from uuid import UUID

from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect, status

from ..db import AsyncSessionLocal
from ..deps import authenticate_token, ensure_meeting_access
from ..redis import get_redis, meeting_audio_key, meeting_channel, serialize_message

router = APIRouter(tags=["realtime"])


async def _stream_pubsub_to_websocket(pubsub, websocket: WebSocket) -> None:
    try:
        async for message in pubsub.listen():
            if message.get("type") != "message":
                continue
            payload = message.get("data")
            if payload is None:
                continue
            try:
                data = json.loads(payload)
            except (json.JSONDecodeError, TypeError):
                data = {"type": "broadcast", "data": payload}
            await websocket.send_json(data)
    except WebSocketDisconnect:
        return


@router.websocket("/ws/meetings/{meeting_id}")
async def meeting_ws(websocket: WebSocket, meeting_id: UUID) -> None:
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Missing token")
        return

    async with AsyncSessionLocal() as db:
        try:
            user = await authenticate_token(token, db)
            meeting = await ensure_meeting_access(db, meeting_id, user.id)
        except HTTPException as exc:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason=exc.detail)
            return
        except Exception:
            await websocket.close(
                code=status.WS_1011_INTERNAL_ERROR,
                reason="Unable to authenticate websocket connection",
            )
            return

    await websocket.accept()

    redis = get_redis()
    channel = meeting_channel(meeting.id)
    audio_key = meeting_audio_key(meeting.id)
    pubsub = redis.pubsub()
    await pubsub.subscribe(channel)

    forward_task = asyncio.create_task(_stream_pubsub_to_websocket(pubsub, websocket))

    await websocket.send_json(
        {
            "type": "ready",
            "data": {
                "meetingId": str(meeting.id),
                "userId": str(user.id),
            },
        }
    )

    try:
        while True:
            message = await websocket.receive_json()
            message_type = message.get("type")
            payload: dict[str, Any] = message.get("data", {}) or {}

            if message_type == "audio_chunk":
                await redis.rpush(
                    audio_key,
                    json.dumps(
                        {
                            "userId": str(user.id),
                            "chunk": payload.get("data"),
                            "receivedAt": datetime.utcnow().isoformat(),
                        }
                    ),
                )

                transcript_stub = {
                    "id": str(uuid.uuid4()),
                    "speaker": payload.get("speaker") or user.name,
                    "text": payload.get("preview") or "Processing audio chunk...",
                    "timestamp": payload.get("timestamp") or "00:00:00",
                }
                await redis.publish(channel, serialize_message("transcript_segment", transcript_stub))

                await websocket.send_json(
                    {
                        "type": "ack",
                        "data": {"message": "audio_chunk queued"},
                    }
                )
            elif message_type == "summary_request":
                summary_stub = {
                    "summary": payload.get("prompt")
                    or "Summary generation has been queued for this meeting.",
                    "requestedAt": datetime.utcnow().isoformat(),
                }
                await redis.publish(channel, serialize_message("summary_update", summary_stub))
            elif message_type == "ping":
                await websocket.send_json({"type": "pong"})
            else:
                await websocket.send_json(
                    {
                        "type": "error",
                        "data": {"message": f"Unsupported message type: {message_type}"},
                    }
                )
    except WebSocketDisconnect:
        pass
    finally:
        forward_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await forward_task
        with contextlib.suppress(Exception):
            await pubsub.unsubscribe(channel)
            await pubsub.close()
