# Teamapp Architecture & Testing Quickstart

## 구조 요약
- 클라이언트(Flutter): 라우팅 Goroute `frontend/lib/app/router.dart`, 상태 `riverpod`, 세션 저장 `frontend/lib/core/services/auth_service.dart` + `shared_preferences`. 대시보드/회의 화면은 `frontend/lib/features/**`.
- 서버(FastAPI): 엔트리 `backend/server/main.py`, 인증/권한 `backend/server/deps.py`, 도메인 라우터 `backend/server/routers/*`. DB는 `DATABASE_URL` 기반 async SQLAlchemy, 실시간 오디오/이벤트는 Redis(`backend/server/redis.py`)로 송수신 후 STT 워커가 처리.
- AI/음성: LLM 요약·액션아이템 `backend/server/services/llm.py`, STT 필터·처리 `backend/server/workers/stt_worker.py`.

## 데이터 흐름
- REST: Auth `POST /api/auth/login|register|refresh`; 팀/회의/액션아이템 CRUD `backend/server/routers/{teams,meetings,action_items}.py`; 대시보드/회의 화면에서 `frontend/lib/features/**/data/*_api.dart`를 통해 호출.
- WebSocket: `/ws/meetings/{id}`로 실시간 오디오 청크 업로드(`audio_chunk` 메시지) 및 서버 푸시 이벤트 수신(`backend/server/routers/realtime.py`).
- 서버 내부: 오디오 청크 → Redis 큐 → STT 워커 `_is_silence_base64`로 무음 필터 → STT 제공자 호출 → Transcript DB 저장 → Redis pub/sub로 프런트에 푸시.

## 테스트
- 서버: 간단한 헬스체크 및 STT 무음 필터 검사 (`backend/tests/test_health.py`).
  ```bash
  cd /Users/jjh/team-app
  PYTHONPATH=. pytest backend/tests -q
  ```
- 프런트: SharedPreferences 기반 세션 저장/삭제 검증 (`frontend/test/auth_service_test.dart`) + 기본 부트 테스트 (`frontend/test/widget_test.dart`).
  ```bash
  cd /Users/jjh/team-app/frontend
  flutter test
  ```

## 라이선스
- 프로젝트 라이선스: MIT (`LICENSE`)
- 사용한 서드파티 라이브러리와 라이선스 요약: `THIRD_PARTY_NOTICES.md`
