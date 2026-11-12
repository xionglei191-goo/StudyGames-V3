"""Starlette ASGI server for StudyGames V4 AI Safe Companion (`127.0.0.1:4195`).

Run standalone:
    python -m uvicorn services.ai_companion.app:app --host 127.0.0.1 --port 4195
"""
from __future__ import annotations

from starlette.applications import Starlette
from starlette.middleware import Middleware
from starlette.middleware.cors import CORSMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse
from starlette.routing import Route

from . import __version__
from .npc_companion import generate_npc_reply
from .speech_service import evaluate_follow_along, synthesize_speech
from .stealth_mastery import build_parent_weekly_report, update_irt_mastery


async def health(_request: Request) -> JSONResponse:
    return JSONResponse({"ok": True, "service": "studygames-v4-ai-companion", "version": __version__})


async def npc_chat(request: Request) -> JSONResponse:
    try:
        body = await request.json()
    except Exception:
        return JSONResponse({"ok": False, "error": "invalid_json"}, status_code=400)
    result = await generate_npc_reply(body if isinstance(body, dict) else {})
    return JSONResponse(result)


async def tts_speak(request: Request) -> JSONResponse:
    try:
        body = await request.json()
    except Exception:
        return JSONResponse({"ok": False, "error": "invalid_json"}, status_code=400)
    if not isinstance(body, dict):
        return JSONResponse({"ok": False, "error": "invalid_payload"}, status_code=400)
    result = await synthesize_speech(
        text=str(body.get("text") or ""),
        lang=str(body.get("lang") or "en"),
        voice_hint=str(body.get("voice_hint") or "warm"),
    )
    return JSONResponse(result, status_code=200 if result.get("ok") else 400)


async def mastery_observe(request: Request) -> JSONResponse:
    try:
        body = await request.json()
    except Exception:
        return JSONResponse({"ok": False, "error": "invalid_json"}, status_code=400)
    events = body.get("events") if isinstance(body, dict) and isinstance(body.get("events"), list) else []
    prior = float(body.get("prior_theta", 0.0)) if isinstance(body, dict) else 0.0
    return JSONResponse({"ok": True, "mastery": update_irt_mastery(events, prior_theta=prior)})


async def parent_report(request: Request) -> JSONResponse:
    try:
        body = await request.json()
    except Exception:
        return JSONResponse({"ok": False, "error": "invalid_json"}, status_code=400)
    return JSONResponse(build_parent_weekly_report(body if isinstance(body, dict) else {}))


async def speech_encourage(request: Request) -> JSONResponse:
    try:
        body = await request.json()
    except Exception:
        return JSONResponse({"ok": False, "error": "invalid_json"}, status_code=400)
    return JSONResponse(evaluate_follow_along(body if isinstance(body, dict) else {}))


app = Starlette(
    debug=False,
    middleware=[
        Middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_methods=["GET", "POST", "OPTIONS"],
            allow_headers=["*"],
        )
    ],
    routes=[
        Route("/health", health, methods=["GET"]),
        Route("/api/v4/npc/chat", npc_chat, methods=["POST"]),
        Route("/api/v4/tts/speak", tts_speak, methods=["POST"]),
        Route("/api/v4/speech/encourage", speech_encourage, methods=["POST"]),
        Route("/api/v4/mastery/observe", mastery_observe, methods=["POST"]),
        Route("/api/v4/parent/report", parent_report, methods=["POST"]),
    ],
)
