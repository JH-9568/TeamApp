# Third-Party Licenses (요약)

프로젝트에서 사용하는 주요 오픈소스 라이브러리와 대표 라이선스를 정리했습니다. 세부 조항은 각 패키지의 LICENSE 파일을 참고하세요.

## 클라이언트 (Flutter)
- Flutter SDK — BSD-3-Clause
- cupertino_icons — MIT
- http — BSD-3-Clause
- web_socket_channel — BSD-3-Clause
- flutter_dotenv — MIT
- dio — MIT
- shared_preferences — BSD-3-Clause
- go_router — BSD-3-Clause
- flutter_riverpod — MIT
- record / record_linux — MIT

## 서버 (Python)
- fastapi — MIT
- starlette — BSD-3-Clause
- pydantic / pydantic-core — MIT
- SQLAlchemy — MIT
- redis-py — MIT
- uvicorn — BSD-3-Clause
- httpx — BSD-3-Clause
- python-jose — MIT
- passlib — BSD-like
- anyio — MIT
- uvloop — MIT
- pytest — MIT
- openai — Apache-2.0
- langchain-core / langchain-openai / langchain-google-genai — Apache-2.0
- google-auth / google-api-core / google-cloud-speech / googleapis-common-protos — Apache-2.0
- ffmpeg-python — Apache-2.0
- bcrypt — Apache-2.0
- requests — Apache-2.0
- websockets — BSD

추가 하위 의존성도 포함되어 있으므로, 배포 시에는 lockfile(`pubspec.lock`, `pip freeze`)을 기반으로 전체 목록을 검토하세요.
