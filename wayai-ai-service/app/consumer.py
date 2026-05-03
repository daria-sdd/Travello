from __future__ import annotations

import asyncio
import json
from uuid import UUID
from datetime import datetime, date
from decimal import Decimal

import asyncpg
import structlog
from aiokafka import AIOKafkaConsumer

from app.clients.amadeus import AmadeusClient
from app.clients.external import OpenWeatherClient, GooglePlacesClient
from app.config import get_settings
from app.models import Survey, SurveyStatus, SurveyDestination, DestinationType, BudgetItem
from app.orchestrator import AiOrchestrator, StepProgress, DoneProgress, FailedProgress

log = structlog.get_logger()


# ── DB writer ─────────────────────────────────────────────────
# Пишем результаты напрямую в PostgreSQL через asyncpg.
# ORM здесь избыточен — у нас простые INSERT'ы.

class RouteDbWriter:
    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool

    async def save_routes(self, routes) -> None:
        async with self._pool.acquire() as conn:
            for route in routes:
                # Сохраняем маршрут
                await conn.execute("""
                    INSERT INTO routes (
                        id, survey_id, user_id, status,
                        title, summary, total_days, total_cost_est,
                        currency, plan_raw, variant_index, variant_label,
                        created_at, updated_at
                    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
                    ON CONFLICT (id) DO NOTHING
                """,
                    route.id, route.survey_id, route.user_id, route.status,
                    route.title, route.summary, route.total_days,
                    float(route.total_cost_est or 0),
                    route.currency,
                    json.dumps([]),     # plan_raw — полный JSON дней
                    route.variant_index, route.variant_label,
                    route.created_at, route.updated_at,
                )

                # Сохраняем дни и события
                for day in route.days:
                    await conn.execute("""
                        INSERT INTO route_days (
                            id, route_id, day_number, date,
                            city, country, country_code, summary, weather_note
                        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
                        ON CONFLICT (id) DO NOTHING
                    """,
                        day.id, day.route_id, day.day_number, day.date,
                        day.city, day.country, day.country_code,
                        day.summary, day.weather_note,
                    )
                    for event in day.events:
                        await conn.execute("""
                            INSERT INTO route_events (
                                id, route_day_id, route_id, event_type, sort_order,
                                starts_at, ends_at, duration_min,
                                title, description, location_name, address,
                                city, country_code, latitude, longitude,
                                google_place_id, image_url,
                                cost_est, currency, is_prepaid,
                                external_id, external_source,
                                ai_tip, ai_confidence,
                                created_at, updated_at
                            ) VALUES (
                                $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,
                                $11,$12,$13,$14,$15,$16,$17,$18,
                                $19,$20,$21,$22,$23,$24,$25,$26,$27
                            ) ON CONFLICT (id) DO NOTHING
                        """,
                            event.id, event.route_day_id, event.route_id,
                            event.event_type.value, event.sort_order,
                            event.starts_at, event.ends_at, event.duration_min,
                            event.title, event.description, event.location_name,
                            event.address, event.city, event.country_code,
                            event.latitude, event.longitude, event.google_place_id,
                            event.image_url,
                            float(event.cost_est) if event.cost_est else None,
                            event.currency, event.is_prepaid,
                            event.external_id,
                            event.external_source.value if event.external_source else None,
                            event.ai_tip, event.ai_confidence,
                            datetime.utcnow(), datetime.utcnow(),
                        )

    async def update_survey_status(
        self, survey_id: UUID, status: SurveyStatus, error: str | None = None
    ) -> None:
        async with self._pool.acquire() as conn:
            await conn.execute("""
                UPDATE surveys
                SET status = $2,
                    error_message = $3,
                    processing_started_at = CASE WHEN $2 = 'processing' THEN now() ELSE processing_started_at END,
                    processing_finished_at = CASE WHEN $2 IN ('completed','failed') THEN now() ELSE processing_finished_at END
                WHERE id = $1
            """, survey_id, status.value, error)

    async def load_survey(self, survey_id: UUID) -> Survey | None:
        async with self._pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM surveys WHERE id = $1", survey_id
            )
            if not row:
                return None

            dests_raw = json.loads(row["destinations"] or "[]")
            destinations = [
                SurveyDestination(
                    name  = d["name"],
                    type  = DestinationType(d.get("type", "any")),
                    order = d.get("order", 0),
                )
                for d in dests_raw
            ]
            includes = [BudgetItem(b) for b in (row["budget_includes"] or [])
                        if b in BudgetItem._value2member_map_]

            return Survey(
                id              = row["id"],
                user_id         = row["user_id"],
                status          = SurveyStatus(row["status"]),
                depart_from     = row["depart_from"],
                date_from       = row["date_from"],
                date_to         = row["date_to"],
                flexible_dates  = row["flexible_dates"],
                destinations    = destinations,
                budget_amount   = Decimal(str(row["budget_amount"])) if row["budget_amount"] else None,
                budget_currency = row["budget_currency"],
                budget_includes = includes,
                tags            = list(row["tags"] or []),
                extra_wishes    = row["extra_wishes"],
                traveller_count = row["traveller_count"],
                traveller_notes = row["traveller_notes"],
                created_at      = row["created_at"],
            )


# ── Redis SSE publisher ───────────────────────────────────────
# Публикуем прогресс в Redis pub/sub.
# Kotlin SSE Gateway подписан и форвардит клиенту.

class RedisProgressPublisher:
    def __init__(self, redis_client) -> None:
        self._redis = redis_client

    async def publish_step(self, survey_id: UUID, step: StepProgress) -> None:
        await self._publish(survey_id, "step", {
            "current": step.current, "total": step.total, "message": step.message,
        })

    async def publish_done(self, survey_id: UUID, done: DoneProgress) -> None:
        await self._publish(survey_id, "done", {
            "surveyId":        str(done.survey_id),
            "routeIds":        [str(r) for r in done.route_ids],
            "generationNotes": done.generation_notes,
        })

    async def publish_failed(self, survey_id: UUID, reason: str) -> None:
        await self._publish(survey_id, "error", {"reason": reason})

    async def _publish(self, survey_id: UUID, event: str, payload: dict) -> None:
        channel = f"sse:survey:{survey_id}"
        message = json.dumps({"event": event, "data": payload})
        await self._redis.publish(channel, message)
        log.debug("redis.published", channel=channel, event=event)


# ── Kafka consumer ────────────────────────────────────────────

class RouteGenerationConsumer:
    def __init__(
        self,
        orchestrator: AiOrchestrator,
        db_writer: RouteDbWriter,
        progress: RedisProgressPublisher,
    ) -> None:
        self._orchestrator = orchestrator
        self._db           = db_writer
        self._progress     = progress
        cfg                = get_settings()
        self._bootstrap    = cfg.kafka_bootstrap_servers
        self._group_id     = cfg.kafka_group_id
        self._topic        = cfg.kafka_topic_route_generation

    async def run(self) -> None:
        consumer = AIOKafkaConsumer(
            self._topic,
            bootstrap_servers = self._bootstrap,
            group_id          = self._group_id,
            auto_offset_reset = "earliest",
            # Ручной коммит offset
            enable_auto_commit = False,
            value_deserializer = lambda v: json.loads(v.decode()),
        )
        await consumer.start()
        log.info("kafka.consumer.started", topic=self._topic, group=self._group_id)

        try:
            async for msg in consumer:
                await self._handle(msg)
                # Коммитим после успешной обработки
                await consumer.commit()
        finally:
            await consumer.stop()

    async def _handle(self, msg) -> None:
        try:
            event    = msg.value
            survey_id = UUID(event["surveyId"])
            log.info("kafka.received", survey_id=str(survey_id), partition=msg.partition)
        except Exception as e:
            log.error("kafka.bad_message", error=str(e), value=msg.value)
            return

        try:
            await self._process(survey_id)
        except Exception as e:
            log.error("kafka.process_error", survey_id=str(survey_id), error=str(e))
            await self._db.update_survey_status(survey_id, SurveyStatus.FAILED, str(e))
            await self._progress.publish_failed(survey_id, "Внутренняя ошибка сервера")

    async def _process(self, survey_id: UUID) -> None:
        # 1. Загружаем survey
        survey = await self._db.load_survey(survey_id)
        if not survey:
            log.warning("kafka.survey_not_found", survey_id=str(survey_id))
            return

        # 2. Помечаем processing
        await self._db.update_survey_status(survey_id, SurveyStatus.PROCESSING)

        # 3. Запускаем agentic loop, стримим прогресс
        routes = []
        async for progress in self._orchestrator.generate_routes(survey):
            match progress:
                case StepProgress():
                    await self._progress.publish_step(survey_id, progress)

                case DoneProgress():
                    # Забираем сгенерированные маршруты
                    routes = getattr(self._orchestrator, "_last_routes", [])
                    await self._db.save_routes(routes)
                    await self._db.update_survey_status(survey_id, SurveyStatus.COMPLETED)
                    await self._progress.publish_done(survey_id, progress)

                case FailedProgress():
                    await self._db.update_survey_status(survey_id, SurveyStatus.FAILED, progress.reason)
                    await self._progress.publish_failed(survey_id, progress.reason)
                    return
