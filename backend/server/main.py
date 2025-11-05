from fastapi import FastAPI
from .routers import (
    auth,
    teams,
    users,
    meetings,
    transcripts,
    action_items,
    attendees,
    speaker_stats,
)

app = FastAPI(title="Team Meeting API")

app.include_router(auth.router)
app.include_router(teams.router)
app.include_router(users.router)
app.include_router(meetings.router)
app.include_router(transcripts.router)
app.include_router(action_items.router)
app.include_router(attendees.router)
app.include_router(speaker_stats.router)

@app.get("/api/health")
async def health():
    return {"status": "ok"}
