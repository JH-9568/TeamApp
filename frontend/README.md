# Team Meeting Frontend

Flutter UI for driving the FastAPI + Whisper backend. The app lets you:

- Configure base URL / JWT / meeting ID
- Hit `/api/health`, transcripts, summarize, and action-item endpoints
- Open a WebSocket connection to `/ws/meetings/{meeting_id}` and inspect realtime messages

## Prerequisites

- Flutter 3.32.x (already installed via Homebrew)
- Backend running locally on `http://127.0.0.1:8000`

## Setup

```bash
cd /Users/jjh/team-app/frontend
cp .env.example .env   # edit API_BASE_URL if needed
flutter pub get
```

The `.env` file currently supports `API_BASE_URL`. Tokens and meeting IDs are entered at runtime.

## Run

```bash
flutter run -d chrome   # or ios, android, macos, etc.
```

1. Enter the backend base URL (pre-filled from `.env`)
2. Paste a JWT from `/api/auth/login`
3. Provide a meeting UUID
4. Use the buttons to call REST APIs or connect to the realtime WebSocket

Logs/responses appear in the lower panels so you can copy/paste into reports or screenshots.  
If you need other endpoints, extend `lib/api_client.dart` with additional helper methods.
