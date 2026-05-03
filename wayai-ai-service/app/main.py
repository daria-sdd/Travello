from __future__ import annotations

import asyncio
import os

import asyncpg
import redis.asyncio as aioredis
import structlog
import uvicorn
from fastapi import FastAPI
from fastapi.responses import JSONResponse

from app.clients.amadeus import AmadeusClient
from app.clients.external import OpenWeatherClient, GooglePlacesClient
from app.config import get_settings
from app.consumer import RouteGenerationConsumer, RouteDbWriter, RedisProgressPublisher
from app.orchestrator import AiOrchestrator

log = structlog.get_logger()


# ── FastAPI app ───────────────────────────────────────────────
# HTTP нужен только для health checks и внутренних вызовов от Kotlin.
# Основная работа — через Kafka consumer.

app = FastAPI(title="WayAI — AI Service", version="1.0.0")


@app.get("/health")
async def health() -> JSONResponse:
    return JSONResponse({"status": "ok", "service": "wayai-ai"})


@app.get("/health/ready")
async def ready() -> JSONResponse:
    """Kubernetes readiness probe."""
    cfg = get_settings()
    checks = {}
    try:
        await app.state.db_pool.fetchval("SELECT 1")
        checks["postgres"] = "ok"
    except Exception as e:
        checks["postgres"] = str(e)
    try:
        await app.state.redis.ping()
        checks["redis"] = "ok"
    except Exception as e:
        checks["redis"] = str(e)

    ok = all(v == "ok" for v in checks.values())
    return JSONResponse({"status": "ready" if ok else "degraded", "checks": checks},
                        status_code=200 if ok else 503)


# ── Lifespan ──────────────────────────────────────────────────

@app.on_event("startup")
async def startup() -> None:
    cfg = get_settings()
    structlog.configure(
        processors=[structlog.processors.JSONRenderer()],
        wrapper_class=structlog.BoundLogger,
    )

    # LangSmith трейсинг (если ключ задан)
    if cfg.langchain_tracing_v2 and cfg.langchain_api_key:
        os.environ["LANGCHAIN_TRACING_V2"] = "true"
        os.environ["LANGCHAIN_API_KEY"]    = cfg.langchain_api_key
        os.environ["LANGCHAIN_PROJECT"]    = cfg.langchain_project
        log.info("langsmith.tracing_enabled", project=cfg.langchain_project)

    # Shared clients
    amadeus = AmadeusClient()
    weather = OpenWeatherClient()
    places  = GooglePlacesClient()
    app.state.amadeus = amadeus
    app.state.weather = weather
    app.state.places  = places

    # DB pool
    db_pool = await asyncpg.create_pool(
        cfg.database_url.replace("postgresql+asyncpg://", "postgresql://"),
        min_size=2, max_size=10,
    )
    app.state.db_pool = db_pool

    # Redis
    redis_client = aioredis.from_url(cfg.redis_url, decode_responses=True)
    app.state.redis = redis_client

    # Orchestrator
    orchestrator = AiOrchestrator(amadeus, weather, places)
    app.state.orchestrator = orchestrator

    # Kafka consumer — запускаем в фоне
    db_writer  = RouteDbWriter(db_pool)
    publisher  = RedisProgressPublisher(redis_client)
    consumer   = RouteGenerationConsumer(orchestrator, db_writer, publisher)
    app.state.consumer_task = asyncio.create_task(consumer.run())

    log.info("wayai_ai_service.started")


@app.on_event("shutdown")
async def shutdown() -> None:
    if hasattr(app.state, "consumer_task"):
        app.state.consumer_task.cancel()
    if hasattr(app.state, "db_pool"):
        await app.state.db_pool.close()
    if hasattr(app.state, "redis"):
        await app.state.redis.aclose()
    for client in ("amadeus", "weather", "places"):
        if hasattr(app.state, client):
            await getattr(app.state, client).aclose()
    log.info("wayai_ai_service.stopped")


if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8081, reload=False)


# ============================================================
# INTERNAL API — вызывается только из Kotlin backend
# Не выставляется наружу (nginx/ingress закрывает /internal/*)
# ============================================================

from pydantic import BaseModel
from fastapi import HTTPException

class EditRouteRequest(BaseModel):
    routeId: str
    userId: str
    message: str
    history: list[dict] = []

class EditRouteResponse(BaseModel):
    routeId: str
    changeSummary: str

@app.post("/internal/routes/edit", response_model=EditRouteResponse)
async def edit_route(request: EditRouteRequest):
    from uuid import UUID
    from app.consumer import RouteDbWriter

    db_writer = RouteDbWriter(app.state.db_pool)
    route_id  = UUID(request.routeId)
    user_id   = UUID(request.userId)

    # Загружаем маршрут из БД
    async with app.state.db_pool.acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM routes WHERE id = $1", route_id)
    if not row:
        raise HTTPException(status_code=404, detail=f"Route {route_id} not found")

    # Собираем минимальный Route объект (только для контекста редактирования)
    from app.models import Route
    import json
    route = Route(
        id       = row["id"],
        survey_id = row["survey_id"],
        user_id  = row["user_id"],
        title    = row["title"],
        summary  = row["summary"],
        total_cost_est = row["total_cost_est"],
        currency = row["currency"],
    )

    result = await app.state.orchestrator.apply_edit(
        route                = route,
        user_message         = request.message,
        conversation_history = request.history,
    )

    # Сохраняем обновлённый маршрут
    await db_writer.save_routes([result.updated_route])

    return EditRouteResponse(
        routeId      = request.routeId,
        changeSummary = result.change_summary,
    )
