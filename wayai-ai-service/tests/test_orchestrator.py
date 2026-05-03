"""
Tests for AiOrchestrator — проверяем agentic loop без реальных API.
Все внешние клиенты заменены stub-объектами.
"""
from __future__ import annotations

import json
from datetime import date
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest
import pytest_asyncio

from app.clients.amadeus import FlightSearchResult, FlightOffer, HotelSearchResult
from app.clients.external import WeatherForecastResult, PlacesSearchResult, ClimateInfoResult
from app.models import Survey, SurveyDestination, DestinationType
from app.orchestrator import AiOrchestrator, StepProgress, DoneProgress, FailedProgress


# ── Fixtures ──────────────────────────────────────────────────

@pytest.fixture
def sample_survey() -> Survey:
    return Survey(
        id              = uuid4(),
        user_id         = uuid4(),
        depart_from     = "Moscow",
        date_from       = date(2025, 10, 1),
        date_to         = date(2025, 10, 8),
        destinations    = [SurveyDestination("Turkey", DestinationType.COUNTRY, 0)],
        budget_amount   = Decimal("2000"),
        tags            = ["beach", "history"],
        traveller_count = 2,
    )

@pytest.fixture
def stub_amadeus():
    amadeus = MagicMock()
    amadeus.search_flights = AsyncMock(return_value=FlightSearchResult(
        found=True,
        offers=[FlightOffer(
            offer_id="offer-1", airline="TK", flight_number="TK412",
            departure_time="2025-10-01T08:00:00", arrival_time="2025-10-01T11:30:00",
            duration_hours=3.5, stops=0, price_per_person=320.0, currency="USD",
            cabin_class="ECONOMY", baggage_included=True, seats_available=8,
        )],
        search_summary="Found 1 flight. Cheapest: $320/person.",
    ))
    amadeus.search_hotels = AsyncMock(return_value=HotelSearchResult(
        found=True, hotels=[], search_summary="Found 0 hotels.",
    ))
    amadeus.find_cheapest_dates       = AsyncMock(return_value=MagicMock(cheapest_options=[]))
    amadeus.find_destination_inspiration = AsyncMock(return_value=MagicMock(destinations=[]))
    return amadeus

@pytest.fixture
def stub_weather():
    weather = MagicMock()
    weather.get_forecast = AsyncMock(return_value=WeatherForecastResult(
        city="Istanbul", days=[], summary="22°C, partly cloudy.",
    ))
    weather.get_climate_info = MagicMock(return_value=ClimateInfoResult(
        location="Turkey", month=10, avg_temp_c=22.0,
        avg_rainy_days=5, tourist_season="Shoulder",
        summary="Pleasant 22°C. Ideal for sightseeing.",
    ))
    return weather

@pytest.fixture
def stub_places():
    places = MagicMock()
    places.search_places   = AsyncMock(return_value=PlacesSearchResult("Istanbul", "SIGHTSEEING", []))
    places.get_place_details = AsyncMock(return_value=MagicMock(
        name="Hagia Sophia", full_description="Historic mosque.", opening_hours={},
        is_open_now=True, admission_price_eur=25.0, recommended_visit_duration_min=90,
        best_time_to_visit="Morning", insider_tip="Arrive early.", website_url=None, phone_number=None,
    ))
    places.get_travel_time = AsyncMock(return_value=MagicMock(
        walking_minutes=15, transit_minutes=10, taxi_minutes=8, taxi_cost_est=5.0, distance_km=1.2,
    ))
    return places


# ── Helpers ───────────────────────────────────────────────────

def make_claude_response(content: list, stop_reason: str = "end_turn"):
    """Создаёт mock ответа Anthropic API."""
    resp = MagicMock()
    resp.stop_reason = stop_reason
    resp.content     = content
    resp.usage       = MagicMock(input_tokens=500, output_tokens=800)
    return resp

def text_block(text: str):
    block = MagicMock()
    block.type = "text"
    block.text = text
    return block

def tool_use_block(name: str, tool_id: str, inputs: dict):
    block = MagicMock()
    block.type  = "tool_use"
    block.name  = name
    block.id    = tool_id
    block.input = inputs
    return block

VALID_GENERATION_RESPONSE = json.dumps({
    "variants": [
        {
            "variant_index": 0,
            "variant_label": "Budget",
            "title": "Turkey on a Budget",
            "summary": "7 days exploring Turkey affordably.",
            "total_days": 7,
            "total_cost_est": 1200.0,
            "currency": "USD",
            "cost_breakdown": {"flights": 640, "accommodation": 350, "activities": 100, "food": 80, "transport_local": 30, "other": 0},
            "why_this_variant": "Maximum value.",
            "days": [
                {
                    "day_number": 1, "date": "2025-10-01",
                    "city": "Istanbul", "country": "Turkey", "country_code": "TR",
                    "day_summary": "Arrival day.",
                    "weather_note": "22°C, sunny.",
                    "events": [
                        {
                            "event_type": "flight", "sort_order": 0,
                            "title": "SVO → IST TK412",
                            "departure_time": "2025-10-01T08:00:00",
                            "arrival_time": "2025-10-01T11:30:00",
                            "amadeus_offer_id": "offer-1",
                            "airline": "Turkish Airlines",
                            "cost_est": 640.0, "currency": "USD",
                            "is_prepaid": True,
                        }
                    ],
                }
            ],
        }
    ],
    "generation_notes": "Budget variant chosen for cost savings.",
})


# ── Tests ─────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_generate_routes_success(sample_survey, stub_amadeus, stub_weather, stub_places):
    """Успешная генерация: Claude возвращает JSON с одним вариантом."""
    orchestrator = AiOrchestrator(stub_amadeus, stub_weather, stub_places)

    with patch.object(orchestrator._claude.messages, "create", new_callable=AsyncMock) as mock_create:
        mock_create.return_value = make_claude_response([text_block(VALID_GENERATION_RESPONSE)])

        events = []
        async for event in orchestrator.generate_routes(sample_survey):
            events.append(event)

    steps = [e for e in events if isinstance(e, StepProgress)]
    done  = [e for e in events if isinstance(e, DoneProgress)]

    assert len(steps) >= 3
    assert len(done) == 1
    assert len(done[0].route_ids) == 1
    assert done[0].generation_notes == "Budget variant chosen for cost savings."
    assert hasattr(orchestrator, "_last_routes")
    assert len(orchestrator._last_routes) == 1
    assert orchestrator._last_routes[0].title == "Turkey on a Budget"


@pytest.mark.asyncio
async def test_generate_routes_with_tool_call(sample_survey, stub_amadeus, stub_weather, stub_places):
    """Claude делает один вызов инструмента, потом возвращает JSON."""
    orchestrator = AiOrchestrator(stub_amadeus, stub_weather, stub_places)

    tool_response  = make_claude_response(
        [tool_use_block("search_flights", "tool-1", {
            "origin": "Moscow", "destination": "Istanbul",
            "departure_date": "2025-10-01",
        })],
        stop_reason="tool_use",
    )
    final_response = make_claude_response([text_block(VALID_GENERATION_RESPONSE)])

    with patch.object(orchestrator._claude.messages, "create", new_callable=AsyncMock) as mock_create:
        mock_create.side_effect = [tool_response, final_response]

        events = []
        async for event in orchestrator.generate_routes(sample_survey):
            events.append(event)

    # search_flights должен быть вызван через executor
    stub_amadeus.search_flights.assert_called_once()
    assert any(isinstance(e, DoneProgress) for e in events)
    # Claude вызван дважды: первый раз → tool_use, второй раз → end_turn
    assert mock_create.call_count == 2


@pytest.mark.asyncio
async def test_generate_routes_json_parse_error(sample_survey, stub_amadeus, stub_weather, stub_places):
    """Claude вернул невалидный JSON — должен прийти FailedProgress."""
    orchestrator = AiOrchestrator(stub_amadeus, stub_weather, stub_places)

    with patch.object(orchestrator._claude.messages, "create", new_callable=AsyncMock) as mock_create:
        mock_create.return_value = make_claude_response([text_block("This is not JSON at all.")])

        events = []
        async for event in orchestrator.generate_routes(sample_survey):
            events.append(event)

    failed = [e for e in events if isinstance(e, FailedProgress)]
    assert len(failed) == 1
    assert "парсинга" in failed[0].reason


@pytest.mark.asyncio
async def test_generate_routes_api_error(sample_survey, stub_amadeus, stub_weather, stub_places):
    """Anthropic API недоступен — должен прийти FailedProgress."""
    orchestrator = AiOrchestrator(stub_amadeus, stub_weather, stub_places)

    with patch.object(orchestrator._claude.messages, "create", new_callable=AsyncMock) as mock_create:
        mock_create.side_effect = Exception("Connection refused")

        events = []
        async for event in orchestrator.generate_routes(sample_survey):
            events.append(event)

    failed = [e for e in events if isinstance(e, FailedProgress)]
    assert len(failed) == 1


@pytest.mark.asyncio
async def test_tool_executor_search_flights(stub_amadeus, stub_weather, stub_places):
    """ToolExecutor корректно вызывает AmadeusClient.search_flights."""
    from app.tools.tools import ToolExecutor
    executor = ToolExecutor(stub_amadeus, stub_weather, stub_places)

    result_str = await executor.execute("search_flights", {
        "origin": "SVO", "destination": "IST", "departure_date": "2025-10-01",
    })
    result = json.loads(result_str)

    stub_amadeus.search_flights.assert_called_once()
    assert result["found"] is True
    assert result["offers"][0]["offer_id"] == "offer-1"


@pytest.mark.asyncio
async def test_tool_executor_unknown_tool(stub_amadeus, stub_weather, stub_places):
    """Неизвестный инструмент — возвращает error, не бросает исключение."""
    from app.tools.tools import ToolExecutor
    executor = ToolExecutor(stub_amadeus, stub_weather, stub_places)

    result_str = await executor.execute("nonexistent_tool", {})
    result = json.loads(result_str)
    assert "error" in result


def test_build_generation_prompt_with_full_survey(sample_survey):
    """Промпт содержит все ключевые данные из survey."""
    from app.prompts.prompts import build_route_generation_prompt
    prompt = build_route_generation_prompt(sample_survey)

    assert "Moscow" in prompt
    assert "Turkey" in prompt
    assert "2025-10-01" in prompt
    assert "beach" in prompt
    assert "2" in prompt  # traveller_count


def test_build_generation_prompt_empty_survey():
    """Пустой survey — промпт должен содержать инструкцию 'сюрприз'."""
    from app.prompts.prompts import build_route_generation_prompt
    empty = Survey(id=uuid4(), user_id=uuid4())
    prompt = build_route_generation_prompt(empty)

    assert "flexible" in prompt.lower() or "best option" in prompt.lower()
    assert "surprise" in prompt.lower() or "best value" in prompt.lower()
