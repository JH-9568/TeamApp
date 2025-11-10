from __future__ import annotations

import json
from typing import Any, List, Optional

try:
    import httpx
except ImportError:  # pragma: no cover
    httpx = None  # type: ignore

try:
    from langchain_core.prompts import ChatPromptTemplate
    from langchain_core.output_parsers import StrOutputParser
    from langchain_google_genai import ChatGoogleGenerativeAI
    from langchain_openai import ChatOpenAI

    LANGCHAIN_AVAILABLE = True
except ImportError:  # pragma: no cover
    LANGCHAIN_AVAILABLE = False

from ..config import AI_PREFERRED_MODEL, GEMINI_API_KEY, OPENAI_API_KEY

TranscriptPayload = List[dict[str, str]]


class LLMNotConfiguredError(RuntimeError):
    """Raised when no LLM provider credentials are available."""


class LLMService:
    def __init__(self) -> None:
        self.provider: Optional[str] = None
        self.model = AI_PREFERRED_MODEL
        if GEMINI_API_KEY:
            self.provider = "gemini"
            self.api_key = GEMINI_API_KEY
        elif OPENAI_API_KEY:
            self.provider = "openai"
            self.api_key = OPENAI_API_KEY
        else:
            self.api_key = None

        self.use_langchain = False
        self.summary_chain = None
        self.action_chain = None

        if LANGCHAIN_AVAILABLE and self.provider and self.api_key:
            try:
                self._init_langchain_chains()
                self.use_langchain = True
            except Exception:
                self.use_langchain = False

    async def summarize(self, transcript: TranscriptPayload) -> str:
        if not transcript:
            return "현재까지 기록된 발화가 없습니다."

        if self.use_langchain and self.summary_chain is not None:
            formatted = self._format_transcript(transcript)
            try:
                return await self.summary_chain.ainvoke({"transcript": formatted})
            except Exception:
                pass

        prompt = self._build_summary_prompt(transcript)

        if self.provider == "gemini":
            return await self._call_gemini(prompt, temperature=0.3)
        if self.provider == "openai":
            return await self._call_openai(prompt)

        return self._fallback_summary(transcript)

    async def extract_action_items(self, transcript: TranscriptPayload) -> list[dict[str, Any]]:
        if not transcript:
            return []

        if self.use_langchain and self.action_chain is not None:
            formatted = self._format_transcript(transcript)
            try:
                response = await self.action_chain.ainvoke({"transcript": formatted})
                parsed = self._try_parse_action_json(response)
                if parsed is not None:
                    return parsed
            except Exception:
                pass

        prompt = self._build_action_item_prompt(transcript)

        if self.provider == "gemini":
            data = await self._call_gemini(prompt, temperature=0.1)
            parsed = self._try_parse_action_json(data)
            if parsed is not None:
                return parsed
            return self._fallback_actions(transcript)

        if self.provider == "openai":
            data = await self._call_openai(prompt)
            parsed = self._try_parse_action_json(data)
            if parsed is not None:
                return parsed
            return self._fallback_actions(transcript)

        return self._fallback_actions(transcript)

    def _init_langchain_chains(self) -> None:
        if not self.provider or not self.api_key:
            raise LLMNotConfiguredError("LLM provider is not configured")

        if self.provider == "gemini":
            llm = ChatGoogleGenerativeAI(
                model=self.model or "gemini-pro",
                google_api_key=self.api_key,
                convert_system_message_to_human=True,
            )
        elif self.provider == "openai":
            llm = ChatOpenAI(
                model=self.model or "gpt-4o-mini",
                api_key=self.api_key,
                temperature=0.2,
            )
        else:
            raise LLMNotConfiguredError("Unsupported provider for LangChain")

        summary_prompt = ChatPromptTemplate.from_messages(
            [
                (
                    "system",
                    "너는 회의 요약을 만드는 어시스턴트야. 회의 transcript를 참고해서 "
                    "결정사항/액션아이템/다음 단계를 bullet로 간결하게 정리해.",
                ),
                (
                    "user",
                    "회의 기록:\n{transcript}\n\n한국어로 3~5개의 bullet로 요약해줘.",
                ),
            ]
        )
        action_prompt = ChatPromptTemplate.from_messages(
            [
                (
                    "system",
                    "너는 회의 transcript에서 실행 항목을 뽑아 JSON 배열로 반환하는 어시스턴트야. "
                    "반드시 JSON만 출력해. 각 항목은 "
                    '{"type":"task","assignee":"이름","content":"API 문서 정리처럼 짧은 명사형 작업명",'
                    '"dueDate":"YYYY-MM-DD 또는 이번주 목요일과 같은 상대 날짜"} 형식을 지켜. '
                    "dueDate는 빈 문자열이나 null을 허용하지 않고, 발화 내용을 바탕으로 가장 그럴듯한 마감을 추론해서 "
                    "YYYY-MM-DD 또는 '이번주 목요일' 같은 표현으로 채워.",
                ),
                (
                    "user",
                    "회의 기록:\n{transcript}\n\nJSON 배열만 출력해.",
                ),
            ]
        )

        parser = StrOutputParser()
        self.summary_chain = summary_prompt | llm | parser
        self.action_chain = action_prompt | llm | parser

    async def _call_gemini(self, prompt: str, temperature: float = 0.2) -> str:
        if not GEMINI_API_KEY:
            raise LLMNotConfiguredError("GEMINI_API_KEY is not configured")
        if httpx is None:
            raise RuntimeError("httpx is required for Gemini calls. Install httpx>=0.25.")

        url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/{self.model}:generateContent"
        )
        params = {"key": GEMINI_API_KEY}
        payload = {
            "contents": [{"role": "user", "parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": temperature, "topK": 32, "topP": 0.95},
        }

        async with httpx.AsyncClient(timeout=60) as client:
            res = await client.post(url, params=params, json=payload)
            res.raise_for_status()
            data = res.json()

        try:
            text = data["candidates"][0]["content"]["parts"][0]["text"]
        except (KeyError, IndexError):
            text = ""
        return text.strip() or "요약을 생성하지 못했습니다."

    async def _call_openai(self, prompt: str) -> str:
        if not OPENAI_API_KEY:
            raise LLMNotConfiguredError("OPENAI_API_KEY is not configured")
        if httpx is None:
            raise RuntimeError("httpx is required for OpenAI calls. Install httpx>=0.25.")

        url = "https://api.openai.com/v1/chat/completions"
        payload = {
            "model": self.model or "gpt-4o-mini",
            "messages": [
                {"role": "system", "content": "You are a helpful AI for meeting analytics."},
                {"role": "user", "content": prompt},
            ],
            "temperature": 0.2,
        }
        headers = {"Authorization": f"Bearer {OPENAI_API_KEY}"}

        async with httpx.AsyncClient(timeout=60) as client:
            res = await client.post(url, json=payload, headers=headers)
            res.raise_for_status()
            data = res.json()

        try:
            text = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError):
            text = ""
        return text.strip() or "요약을 생성하지 못했습니다."

    @staticmethod
    def _build_summary_prompt(transcript: TranscriptPayload) -> str:
        lines = "\n".join(f"{item.get('speaker', 'Speaker')}: {item.get('text', '')}" for item in transcript)
        return (
            "다음 회의 대화록을 한국어로 3~5개의 bullet 요약으로 정리해줘. "
            "결정사항과 다음 단계가 있다면 강조해줘.\n\n"
            f"{lines}"
        )

    @staticmethod
    def _build_action_item_prompt(transcript: TranscriptPayload) -> str:
        lines = "\n".join(
            f"{item.get('speaker', 'Speaker')}: {item.get('text', '')}"
            for item in transcript
        )
        return (
            "다음 회의 대화록에서 실행 항목을 JSON 배열로 추출해줘. "
            "각 항목은 {\"type\": \"task\", \"assignee\": \"이름\", "
            "\"content\": \"API 문서 정리 처럼 짧은 명사형 작업명\", "
            "\"dueDate\": \"YYYY-MM-DD\" 혹은 \"이번주 목요일\" 같은 상대 날짜 표현} 포맷을 지켜. "
            "dueDate는 비워두지 말고 발화에서 유추되는 가장 그럴듯한 날짜를 반드시 넣어.\n\n"
            f"{lines}"
        )

    @staticmethod
    def _fallback_summary(transcript: TranscriptPayload) -> str:
        excerpts = []
        for item in transcript[:4]:
            speaker = item.get("speaker", "Speaker")
            text = item.get("text", "")[:140]
            excerpts.append(f"- {speaker}: {text}")
        if not excerpts:
            return "회의 내용이 없습니다."
        return "간이 요약 (LLM 미구현)\n" + "\n".join(excerpts)

    @staticmethod
    def _format_transcript(transcript: TranscriptPayload) -> str:
        return "\n".join(
            f"{item.get('speaker', 'Speaker')}: {item.get('text', '')}"
            for item in transcript
        )

    @staticmethod
    def _fallback_actions(transcript: TranscriptPayload) -> list[dict[str, Any]]:
        keywords = ("해야", "작업", "task", "action", "필요", "follow up", "확인", "까지", "할게")
        items: list[dict[str, Any]] = []
        for chunk in transcript:
            text = chunk.get("text", "")
            if any(keyword in text.lower() for keyword in keywords):
                content = text.strip()
                for suffix in ("할게", "할께", "하겠습니다", "할 예정입니다", "할 예정이에요", "할 것 같습니다"):
                    if content.endswith(suffix):
                        content = content[: -len(suffix)].rstrip()
                        break
                if content.endswith(("입니다", "입니다.", "에요", "예요")):
                    content = content.rstrip("입니다.에요예요 ").strip()
                content = content or text.strip()
                items.append(
                    {
                        "type": "task",
                        "assignee": chunk.get("speaker"),
                        "content": content,
                        "dueDate": None,
                    }
                )
        return items[:5]

    @staticmethod
    def _try_parse_action_json(raw_text: str) -> Optional[list[dict[str, Any]]]:
        raw_text = raw_text.strip()
        if not raw_text:
            return None
        start = raw_text.find("[")
        end = raw_text.rfind("]")
        snippet = raw_text if (start == -1 or end == -1) else raw_text[start : end + 1]
        try:
            data = json.loads(snippet)
            if isinstance(data, list):
                return [item for item in data if isinstance(item, dict)]
        except json.JSONDecodeError:
            return None
        return None


llm_service = LLMService()
