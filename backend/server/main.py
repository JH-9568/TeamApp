from fastapi import FastAPI
from .routers import auth, teams

app = FastAPI(title="Team Meeting API")


app.include_router(auth.router)
app.include_router(teams.router)

@app.get("/api/health")
async def health():
    return {"status": "ok"}