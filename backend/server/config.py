import os
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")
JWT_SECRET = os.getenv("JWT_SECRET", "changeme")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))
REFRESH_TOKEN_EXPIRE_MINUTES = int(os.getenv("REFRESH_TOKEN_EXPIRE_MINUTES", "10080"))
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
AI_PREFERRED_MODEL = os.getenv("AI_PREFERRED_MODEL", "gemini-pro")
STORAGE_BUCKET = os.getenv("STORAGE_BUCKET")
STORAGE_BASE_URL = os.getenv("STORAGE_BASE_URL", "https://storage.local")
WHISPER_MODEL = os.getenv("WHISPER_MODEL", "base")
WHISPER_DEVICE = os.getenv("WHISPER_DEVICE", "cpu")
STT_POLL_INTERVAL = float(os.getenv("STT_POLL_INTERVAL", "1.0"))
