from __future__ import annotations

import json
from dataclasses import dataclass, field
from decimal import Decimal
from datetime import datetime, date
from typing import AsyncIterator
from uuid import UUID, uuid4

import anthropic
import structlog

from app.clients.amadeus import AmadeusClient
from app.clients.external import GooglePlacesClient, OpenWeatherClient
from app.config import get_settings
from app.models import (
    Route, RouteDay, RouteEvent,
    EventType, ExternalSource, Survey,
)
from app.prompts.prompts import (
    ROUTE_GENERATION_SYSTEM, ROUTE_EDIT_SYSTEM,
    build_route_generation_prompt, build_route_edit_prompt,
    build_daily_tip_prompt,
)
from app.tools.tools import TOOL_DEFINITIONS, ToolExecutor

log = structlog.get_logger()


# ── Progress events ───────────────────────────────────────────

@dataclass
class StepProgress:
    current: int
    total:   int
    message: str

@dataclass
class DoneProgress:
    survey_id:       UUID
    route_ids:       list[UUID]
    generation_notes: str | None

@dataclass
class FailedProgress:
    reason: str

GenerationProgress = StepProgress | DoneProgress | FailedProgress


# ── Edit result ───────────────────────────────────────────────

@dataclass
class RouteEditResult:
    updated_route:  Route
    change_summary: str


# ── Orchestrator ──────────────────────────────────────────────

class AiOrchestrator:
    """
    Ядро AI сервиса.

    Алгоритм генерации:
    1. Строим prompt из Survey
    2. Запускаем agentic loop: Claude → tool_use → execute → tool_result → Claude → ...
    3. Claude сам решает когда остановиться (stop_reason == "end_turn")
    4. Финальный ответ — JSON с 3 вариантами маршрута
    5. Парсим JSON → domain Route объекты → сохраняем в PostgreSQL
    """

    def __init__(
        self,
        amadeus: AmadeusClient,
        weather: OpenWeatherClient,
        places: GooglePlacesClient,
    ) -> None:
        cfg = get_settings()
        self._claude   = anthropic.AsyncAnthropic(api_key=cfg.anthropic_api_key)
        self._model    = cfg.anthropic_model
        self._max_tokens = cfg.anthropic_max_tokens
        self._temperature = cfg.anthropic_temperature
        self._executor = ToolExecutor(amadeus, weather, places)

    # ── Route generation ──────────────────────────────────────

    async def generate_routes(
        self, survey: Survey
    ) -> AsyncIterator[GenerationProgress]:
        log.info("orchestrator.generate_routes.start", survey_id=str(survey.id))

        yield StepProgress(1, 5, "Анализирую ваши предпочтения...")

        prompt   = build_route_generation_prompt(survey)
        messages = [{"role": "user", "content": prompt}]

        yield StepProgress(2, 5, "Ищу рейсы и отели...")

        # ── Agentic loop ──────────────────────────────────────
        # Claude вызывает инструменты пока не готов дать финальный ответ.
        # stop_reason == "tool_use" → выполняем инструменты, продолжаем.
        # stop_reason == "end_turn" → финальный JSON ответ готов.

        raw_response: str | None = None
        tool_rounds = 0

        while True:
            response = await self._claude.messages.create(
                model       = self._model,
                max_tokens  = self._max_tokens,
                temperature = self._temperature,
                system      = ROUTE_GENERATION_SYSTEM,
                tools       = TOOL_DEFINITIONS,
                messages    = messages,
            )

            log.debug(
                "orchestrator.claude_response",
                stop_reason  = response.stop_reason,
                content_types = [b.type for b in response.content],
                input_tokens  = response.usage.input_tokens,
                output_tokens = response.usage.output_tokens,
            )

            # Добавляем ответ Claude в историю
            messages.append({"role": "assistant", "content": response.content})

            if response.stop_reason == "end_turn":
                # Claude закончил — извлекаем текстовый блок с JSON
                for block in response.content:
                    if block.type == "text":
                        raw_response = block.text
                        break
                break

            if response.stop_reason == "tool_use":
                tool_rounds += 1
                if tool_rounds > 20:
                    # Safety limit: не даём Claude зациклиться
                    log.warning("orchestrator.tool_limit_reached", survey_id=str(survey.id))
                    break

                # Обновляем прогресс на каждом втором раунде инструментов
                if tool_rounds == 2:
                    yield StepProgress(3, 5, "ИИ составляет маршруты...")

                # Выполняем все tool_use блоки параллельно
                tool_results = []
                for block in response.content:
                    if block.type != "tool_use":
                        continue
                    log.info(
                        "orchestrator.tool_call",
                        tool   = block.name,
                        inputs = block.input,
                    )
                    result_str = await self._executor.execute(block.name, block.input)
                    tool_results.append({
                        "type":        "tool_result",
                        "tool_use_id": block.id,
                        "content":     result_str,
                    })

                messages.append({"role": "user", "content": tool_results})
                continue

            # max_tokens или другая причина остановки
            log.warning(
                "orchestrator.unexpected_stop",
                stop_reason = response.stop_reason,
                survey_id   = str(survey.id),
            )
            break

        yield StepProgress(4, 5, "Собираю финальный план...")

        if not raw_response:
            yield FailedProgress("Claude не вернул финальный ответ")
            return

        # Парсим JSON
        try:
            # Claude иногда оборачивает JSON в ```json ... ``` — чистим
            clean = raw_response.strip()
            if clean.startswith("```"):
                clean = clean.split("```")[1]
                if clean.startswith("json"):
                    clean = clean[4:]
            data = json.loads(clean.strip())
        except json.JSONDecodeError as e:
            log.error("orchestrator.json_parse_error", error=str(e), raw=raw_response[:500])
            yield FailedProgress(f"Ошибка парсинга ответа AI: {e}")
            return

        # Маппим в domain объекты
        routes = [
            _map_variant_to_route(variant, survey)
            for variant in data.get("variants", [])
        ]

        yield StepProgress(5, 5, "Сохраняю варианты...")

        yield DoneProgress(
            survey_id        = survey.id,
            route_ids        = [r.id for r in routes],
            generation_notes = data.get("generation_notes"),
        )

        # Реальное сохранение в БД происходит в caller (KafkaConsumer)
        # чтобы orchestrator оставался без зависимости от БД напрямую
        log.info(
            "orchestrator.generate_routes.done",
            survey_id = str(survey.id),
            variants  = len(routes),
        )

        # Возвращаем routes через атрибут — caller заберёт их из DoneProgress
        self._last_routes = routes

    # ── NLP route edit ────────────────────────────────────────

    async def apply_edit(
        self,
        route: Route,
        user_message: str,
        conversation_history: list[dict],
    ) -> RouteEditResult:
        log.info("orchestrator.apply_edit", route_id=str(route.id), message=user_message[:80])

        plan_summary = _build_plan_summary(route)
        prompt       = build_route_edit_prompt(user_message, plan_summary)

        # Восстанавливаем историю диалога + добавляем новый запрос
        messages = [*conversation_history, {"role": "user", "content": prompt}]

        # Короткий agentic loop для правок (обычно 1–3 вызова инструментов)
        raw_response: str | None = None
        while True:
            response = await self._claude.messages.create(
                model       = self._model,
                max_tokens  = self._max_tokens,
                temperature = self._temperature,
                system      = ROUTE_EDIT_SYSTEM,
                tools       = TOOL_DEFINITIONS,
                messages    = messages,
            )
            messages.append({"role": "assistant", "content": response.content})

            if response.stop_reason == "end_turn":
                for block in response.content:
                    if block.type == "text":
                        raw_response = block.text
                break

            if response.stop_reason == "tool_use":
                tool_results = []
                for block in response.content:
                    if block.type != "tool_use":
                        continue
                    result_str = await self._executor.execute(block.name, block.input)
                    tool_results.append({
                        "type": "tool_result", "tool_use_id": block.id, "content": result_str,
                    })
                messages.append({"role": "user", "content": tool_results})
                continue
            break

        if not raw_response:
            raise ValueError("Claude did not return a response for the edit")

        clean = raw_response.strip().lstrip("```json").lstrip("```").rstrip("```").strip()
        data  = json.loads(clean)

        updated_route = _apply_edit_data_to_route(route, data)
        return RouteEditResult(
            updated_route  = updated_route,
            change_summary = data.get("change_summary", "Маршрут обновлён"),
        )

    # ── Daily tip ─────────────────────────────────────────────

    async def generate_daily_tip(
        self,
        user_name: str,
        today_events: str,
        tomorrow_events: str,
        weather_today: str,
        weather_tomorrow: str,
    ) -> str:
        prompt = build_daily_tip_prompt(
            user_name, today_events, tomorrow_events, weather_today, weather_tomorrow
        )
        # Один вызов без инструментов — быстро
        response = await self._claude.messages.create(
            model      = self._model,
            max_tokens = 256,
            system     = "You are WayAI, a friendly travel assistant.",
            messages   = [{"role": "user", "content": prompt}],
        )
        return response.content[0].text.strip()


# ── Mappers ───────────────────────────────────────────────────

def _map_variant_to_route(variant: dict, survey: Survey) -> Route:
    route_id = uuid4()
    days = []
    for ai_day in variant.get("days", []):
        day_id = uuid4()
        events = [
            _map_event(ev, day_id, route_id)
            for ev in ai_day.get("events", [])
        ]
        days.append(RouteDay(
            id          = day_id,
            route_id    = route_id,
            day_number  = ai_day["day_number"],
            date        = _parse_date(ai_day.get("date")),
            city        = ai_day.get("city"),
            country     = ai_day.get("country"),
            country_code = ai_day.get("country_code"),
            summary     = ai_day.get("day_summary"),
            weather_note = ai_day.get("weather_note"),
            events      = events,
        ))
    return Route(
        id              = route_id,
        survey_id       = survey.id,
        user_id         = survey.user_id,
        status          = "draft",
        title           = variant.get("title"),
        summary         = variant.get("summary"),
        total_days      = variant.get("total_days"),
        total_cost_est  = Decimal(str(variant.get("total_cost_est", 0))),
        currency        = variant.get("currency", "USD"),
        days            = days,
        variant_index   = variant.get("variant_index", 0),
        variant_label   = variant.get("variant_label"),
    )


def _map_event(ev: dict, day_id: UUID, route_id: UUID) -> RouteEvent:
    type_map = {
        "flight": EventType.FLIGHT, "accommodation": EventType.ACCOMMODATION,
        "transport": EventType.TRANSPORT, "activity": EventType.ACTIVITY,
        "restaurant": EventType.RESTAURANT, "note": EventType.NOTE,
    }
    source_map = {
        "amadeus": ExternalSource.AMADEUS,
        "google_places": ExternalSource.GOOGLE_PLACES,
    }
    ext_id, ext_src = None, None
    if ev.get("amadeus_offer_id"):
        ext_id, ext_src = ev["amadeus_offer_id"], ExternalSource.AMADEUS
    elif ev.get("hotel_id"):
        ext_id, ext_src = ev["hotel_id"], ExternalSource.AMADEUS
    elif ev.get("google_place_id"):
        ext_id, ext_src = ev["google_place_id"], ExternalSource.GOOGLE_PLACES

    return RouteEvent(
        id             = uuid4(),
        route_day_id   = day_id,
        route_id       = route_id,
        event_type     = type_map.get(ev.get("event_type", ""), EventType.FREE_TIME),
        sort_order     = ev.get("sort_order", 0),
        starts_at      = _parse_dt(ev.get("starts_at")),
        ends_at        = _parse_dt(ev.get("ends_at")),
        duration_min   = ev.get("duration_min"),
        title          = ev.get("title"),
        description    = ev.get("description"),
        location_name  = ev.get("location_name"),
        address        = ev.get("address"),
        latitude       = ev.get("latitude"),
        longitude      = ev.get("longitude"),
        google_place_id = ev.get("google_place_id"),
        image_url      = ev.get("image_url"),
        cost_est       = Decimal(str(ev["cost_est"])) if ev.get("cost_est") is not None else None,
        currency       = ev.get("currency", "USD"),
        is_prepaid     = ev.get("is_prepaid", False),
        external_id    = ext_id,
        external_source = ext_src,
        ai_tip         = ev.get("ai_tip"),
        ai_confidence  = ev.get("ai_confidence"),
    )


def _apply_edit_data_to_route(route: Route, data: dict) -> Route:
    updated_days = []
    for ai_day in data.get("updated_days", []):
        existing = next((d for d in route.days if d.day_number == ai_day["day_number"]), None)
        day_id   = existing.id if existing else uuid4()
        events   = [_map_event(ev, day_id, route.id) for ev in ai_day.get("events", [])]
        updated_days.append(RouteDay(
            id          = day_id,
            route_id    = route.id,
            day_number  = ai_day["day_number"],
            date        = _parse_date(ai_day.get("date")),
            city        = ai_day.get("city"),
            country     = ai_day.get("country"),
            country_code = ai_day.get("country_code"),
            summary     = ai_day.get("day_summary"),
            weather_note = ai_day.get("weather_note"),
            events      = events,
        ))
    from dataclasses import replace
    return replace(
        route,
        days           = updated_days,
        total_cost_est = Decimal(str(data.get("total_cost_est", route.total_cost_est or 0))),
        updated_at     = datetime.utcnow(),
    )


def _build_plan_summary(route: Route) -> str:
    lines = [f"Title: {route.title}", f"Total cost: ${route.total_cost_est} {route.currency}", ""]
    for day in route.days:
        lines.append(f"Day {day.day_number} — {day.date}: {day.city}, {day.country}")
        lines.append(f"  Summary: {day.summary}")
        for ev in day.events:
            cost = f" (${ev.cost_est})" if ev.cost_est else ""
            lines.append(f"  - [{ev.event_type.value}] {ev.title}{cost}")
        lines.append("")
    return "\n".join(lines)


def _parse_date(s: str | None) -> date | None:
    if not s:
        return None
    try:
        return date.fromisoformat(s)
    except ValueError:
        return None


def _parse_dt(s: str | None) -> datetime | None:
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None
