"""
Tests for ToolExecutor — проверяем каждый инструмент изолированно.
Все HTTP вызовы перехвачены через pytest-httpx.
"""
from __future__ import annotations

import json
from datetime import date
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.clients.amadeus import (
    AmadeusClient, FlightSearchResult, FlightOffer,
    HotelSearchResult, CheapestDatesResult, DestinationInspirationResult,
)
from app.clients.external import (
    GooglePlacesClient, OpenWeatherClient,
    WeatherForecastResult, WeatherDay, PlacesSearchResult, PlaceResult,
    ClimateInfoResult, TravelTimeResult, PlaceDetailsResult,
)
from app.tools.tools import ToolExecutor, TOOL_DEFINITIONS


# ── Fixtures ──────────────────────────────────────────────────

@pytest.fixture
def flight_offer():
    return FlightOffer(
        offer_id="off-1", airline="TK", flight_number="TK412",
        departure_time="2025-10-01T08:00:00", arrival_time="2025-10-01T11:30:00",
        duration_hours=3.5, stops=0, price_per_person=320.0, currency="USD",
        cabin_class="ECONOMY", baggage_included=True, seats_available=8,
    )

@pytest.fixture
def stub_amadeus(flight_offer):
    m = MagicMock()
    m.search_flights = AsyncMock(return_value=FlightSearchResult(
        found=True, offers=[flight_offer], search_summary="Found 1 flight. Cheapest: $320/person.",
    ))
    m.find_cheapest_dates = AsyncMock(return_value=CheapestDatesResult(
        origin="SVO", destination="IST",
        cheapest_options=[MagicMock(departure_date="2025-10-01", return_date="2025-10-08",
                                    price_per_person=290.0, currency="USD")],
    ))
    m.find_destination_inspiration = AsyncMock(return_value=DestinationInspirationResult(
        origin="SVO",
        destinations=[MagicMock(destination="IST", country="Turkey", price_from=280.0,
                                currency="USD", departure_date="2025-10-01", highlights=[])],
    ))
    m.search_hotels = AsyncMock(return_value=HotelSearchResult(
        found=True,
        hotels=[MagicMock(hotel_id="h-1", name="Grand Hotel", stars=4, rating=8.5,
                           review_count=1200, address="Istanbul", distance_to_center_km=0.5,
                           price_per_night=85.0, total_price=595.0, currency="USD",
                           breakfast_included=True, cancellation_policy="Free until Oct 1",
                           amenities=["WiFi", "Pool"], image_url=None)],
        search_summary="Found 1 hotel. Cheapest: $85/night.",
    ))
    return m

@pytest.fixture
def stub_weather():
    m = MagicMock()
    m.get_forecast = AsyncMock(return_value=WeatherForecastResult(
        city="Istanbul",
        days=[WeatherDay(date="2025-10-01", temp_min_c=18.0, temp_max_c=24.0,
                          condition="Sunny", rain_probability=10, humidity=60, wind_kmh=12.0)],
        summary="Avg high 24°C. No rain expected.",
    ))
    m.get_climate_info = MagicMock(return_value=ClimateInfoResult(
        location="Turkey", month=10, avg_temp_c=22.0, avg_rainy_days=5,
        tourist_season="Shoulder", summary="Pleasant 22°C.",
    ))
    return m

@pytest.fixture
def stub_places():
    m = MagicMock()
    m.search_places = AsyncMock(return_value=PlacesSearchResult(
        city="Istanbul", category="SIGHTSEEING",
        places=[PlaceResult(place_id="p-1", name="Hagia Sophia", category="SIGHTSEEING",
                             rating=4.8, review_count=50000, address="Sultanahmet",
                             latitude=41.008, longitude=28.980, price_level=2,
                             image_url=None, tags=["museum", "historic"])],
    ))
    m.get_place_details = AsyncMock(return_value=PlaceDetailsResult(
        place_id="p-1", name="Hagia Sophia",
        full_description="Ancient Byzantine church turned mosque.",
        opening_hours={"Monday": "09:00-17:00"}, is_open_now=True,
        admission_price_eur=25.0, recommended_visit_duration_min=90,
        best_time_to_visit="Early morning", insider_tip="Arrive before 9am.",
        website_url="https://ayasofya.gov.tr", phone_number=None,
    ))
    m.get_travel_time = AsyncMock(return_value=TravelTimeResult(
        origin="Hagia Sophia", destination="Blue Mosque",
        walking_minutes=5, transit_minutes=4, taxi_minutes=3,
        taxi_cost_est=2.5, distance_km=0.4,
    ))
    return m

@pytest.fixture
def executor(stub_amadeus, stub_weather, stub_places):
    return ToolExecutor(stub_amadeus, stub_weather, stub_places)


# ── Tool definitions структура ────────────────────────────────

def test_tool_definitions_count():
    """Должно быть ровно 9 инструментов."""
    assert len(TOOL_DEFINITIONS) == 9

def test_tool_definitions_have_required_fields():
    """Каждый инструмент содержит name, description, input_schema."""
    for tool in TOOL_DEFINITIONS:
        assert "name" in tool, f"Missing 'name' in {tool}"
        assert "description" in tool, f"Missing 'description' in {tool}"
        assert "input_schema" in tool, f"Missing 'input_schema' in {tool}"
        assert "properties" in tool["input_schema"]

def test_tool_names_are_unique():
    names = [t["name"] for t in TOOL_DEFINITIONS]
    assert len(names) == len(set(names)), "Duplicate tool names found"

def test_all_required_tools_present():
    names = {t["name"] for t in TOOL_DEFINITIONS}
    expected = {
        "search_flights", "find_cheapest_flight_dates", "find_cheapest_destinations",
        "search_hotels", "get_weather_forecast", "get_climate_info",
        "search_places", "get_place_details", "get_travel_time",
    }
    assert expected == names


# ── search_flights ────────────────────────────────────────────

@pytest.mark.asyncio
async def test_search_flights_basic(executor, stub_amadeus):
    result_str = await executor.execute("search_flights", {
        "origin": "SVO", "destination": "IST", "departure_date": "2025-10-01",
    })
    result = json.loads(result_str)

    stub_amadeus.search_flights.assert_called_once()
    call_kwargs = stub_amadeus.search_flights.call_args
    assert call_kwargs.kwargs["origin"] == "SVO"
    assert call_kwargs.kwargs["destination"] == "IST"
    assert call_kwargs.kwargs["depart_date"] == date(2025, 10, 1)
    assert call_kwargs.kwargs["return_date"] is None

    assert result["found"] is True
    assert result["offers"][0]["offer_id"] == "off-1"
    assert result["offers"][0]["price_per_person"] == 320.0


@pytest.mark.asyncio
async def test_search_flights_with_return_date(executor, stub_amadeus):
    await executor.execute("search_flights", {
        "origin": "SVO", "destination": "IST",
        "departure_date": "2025-10-01", "return_date": "2025-10-08",
        "adults": 2, "travel_class": "BUSINESS",
    })
    call_kwargs = stub_amadeus.search_flights.call_args
    assert call_kwargs.kwargs["return_date"] == date(2025, 10, 8)
    assert call_kwargs.kwargs["adults"] == 2
    assert call_kwargs.kwargs["travel_class"] == "BUSINESS"


@pytest.mark.asyncio
async def test_search_flights_empty_return_date(executor, stub_amadeus):
    """Пустая строка return_date → None (не передаём в Amadeus)."""
    await executor.execute("search_flights", {
        "origin": "SVO", "destination": "IST",
        "departure_date": "2025-10-01", "return_date": "",
    })
    assert stub_amadeus.search_flights.call_args.kwargs["return_date"] is None


# ── find_cheapest_flight_dates ────────────────────────────────

@pytest.mark.asyncio
async def test_find_cheapest_flight_dates(executor, stub_amadeus):
    result_str = await executor.execute("find_cheapest_flight_dates", {
        "origin": "SVO", "destination": "IST",
    })
    result = json.loads(result_str)

    stub_amadeus.find_cheapest_dates.assert_called_once_with(
        origin="SVO", destination="IST",
    )
    assert result["origin"] == "SVO"
    assert len(result["cheapest_options"]) == 1


# ── find_cheapest_destinations ────────────────────────────────

@pytest.mark.asyncio
async def test_find_cheapest_destinations_defaults(executor, stub_amadeus):
    await executor.execute("find_cheapest_destinations", {"origin": "SVO"})
    stub_amadeus.find_destination_inspiration.assert_called_once_with(
        origin="SVO", departure_month="", max_budget=2000,
    )

@pytest.mark.asyncio
async def test_find_cheapest_destinations_with_params(executor, stub_amadeus):
    await executor.execute("find_cheapest_destinations", {
        "origin": "SVO", "departure_month": "2025-10", "max_budget": 1500,
    })
    stub_amadeus.find_destination_inspiration.assert_called_once_with(
        origin="SVO", departure_month="2025-10", max_budget=1500,
    )


# ── search_hotels ─────────────────────────────────────────────

@pytest.mark.asyncio
async def test_search_hotels(executor, stub_amadeus):
    result_str = await executor.execute("search_hotels", {
        "city": "Istanbul", "check_in": "2025-10-01", "check_out": "2025-10-08",
        "adults": 2, "budget_tier": "MEDIUM",
    })
    result = json.loads(result_str)

    stub_amadeus.search_hotels.assert_called_once()
    args = stub_amadeus.search_hotels.call_args.kwargs
    assert args["city"] == "Istanbul"
    assert args["check_in"] == date(2025, 10, 1)
    assert args["check_out"] == date(2025, 10, 8)

    assert result["found"] is True
    assert result["hotels"][0]["name"] == "Grand Hotel"
    assert result["hotels"][0]["price_per_night"] == 85.0


# ── get_weather_forecast ──────────────────────────────────────

@pytest.mark.asyncio
async def test_get_weather_forecast(executor, stub_weather):
    result_str = await executor.execute("get_weather_forecast", {
        "city": "Istanbul", "date_from": "2025-10-01", "date_to": "2025-10-07",
    })
    result = json.loads(result_str)

    stub_weather.get_forecast.assert_called_once_with(
        city="Istanbul",
        date_from=date(2025, 10, 1),
        date_to=date(2025, 10, 7),
    )
    assert result["city"] == "Istanbul"
    assert len(result["days"]) == 1
    assert result["days"][0]["condition"] == "Sunny"


# ── get_climate_info ──────────────────────────────────────────

@pytest.mark.asyncio
async def test_get_climate_info(executor, stub_weather):
    result_str = await executor.execute("get_climate_info", {
        "location": "Turkey", "month": 10,
    })
    result = json.loads(result_str)

    stub_weather.get_climate_info.assert_called_once_with(location="Turkey", month=10)
    assert result["avg_temp_c"] == 22.0
    assert result["tourist_season"] == "Shoulder"


# ── search_places ─────────────────────────────────────────────

@pytest.mark.asyncio
async def test_search_places_basic(executor, stub_places):
    result_str = await executor.execute("search_places", {
        "city": "Istanbul", "category": "SIGHTSEEING",
    })
    result = json.loads(result_str)

    stub_places.search_places.assert_called_once_with(
        city="Istanbul", category="SIGHTSEEING", tags=[], max_results=8,
    )
    assert result["places"][0]["name"] == "Hagia Sophia"
    assert result["places"][0]["place_id"] == "p-1"

@pytest.mark.asyncio
async def test_search_places_with_tags(executor, stub_places):
    await executor.execute("search_places", {
        "city": "Istanbul", "category": "RESTAURANT",
        "tags": "local food, seafood", "max_results": 5,
    })
    args = stub_places.search_places.call_args.kwargs
    assert args["tags"] == ["local food", "seafood"]
    assert args["max_results"] == 5


# ── get_place_details ─────────────────────────────────────────

@pytest.mark.asyncio
async def test_get_place_details(executor, stub_places):
    result_str = await executor.execute("get_place_details", {"place_id": "p-1"})
    result = json.loads(result_str)

    stub_places.get_place_details.assert_called_once_with("p-1")
    assert result["name"] == "Hagia Sophia"
    assert result["admission_price_eur"] == 25.0
    assert result["insider_tip"] == "Arrive before 9am."


# ── get_travel_time ───────────────────────────────────────────

@pytest.mark.asyncio
async def test_get_travel_time(executor, stub_places):
    result_str = await executor.execute("get_travel_time", {
        "origin": "Hagia Sophia",
        "destination": "Blue Mosque",
        "city": "Istanbul",
    })
    result = json.loads(result_str)

    stub_places.get_travel_time.assert_called_once_with(
        origin="Hagia Sophia", destination="Blue Mosque", city="Istanbul",
    )
    assert result["walking_minutes"] == 5
    assert result["distance_km"] == 0.4


# ── unknown tool ──────────────────────────────────────────────

@pytest.mark.asyncio
async def test_unknown_tool_returns_error(executor):
    result_str = await executor.execute("does_not_exist", {"foo": "bar"})
    result = json.loads(result_str)
    assert "error" in result
    assert "does_not_exist" in result["error"]


# ── serialization ─────────────────────────────────────────────

@pytest.mark.asyncio
async def test_result_is_valid_json(executor):
    """Все инструменты возвращают валидный JSON — Claude должен его распарсить."""
    tools_to_test = [
        ("search_flights",            {"origin": "SVO", "destination": "IST", "departure_date": "2025-10-01"}),
        ("find_cheapest_flight_dates", {"origin": "SVO", "destination": "IST"}),
        ("find_cheapest_destinations", {"origin": "SVO"}),
        ("search_hotels",             {"city": "Istanbul", "check_in": "2025-10-01", "check_out": "2025-10-08"}),
        ("get_weather_forecast",      {"city": "Istanbul", "date_from": "2025-10-01", "date_to": "2025-10-07"}),
        ("get_climate_info",          {"location": "Turkey", "month": 10}),
        ("search_places",             {"city": "Istanbul", "category": "SIGHTSEEING"}),
        ("get_place_details",         {"place_id": "p-1"}),
        ("get_travel_time",           {"origin": "A", "destination": "B", "city": "Istanbul"}),
    ]
    for tool_name, inputs in tools_to_test:
        result_str = await executor.execute(tool_name, inputs)
        try:
            json.loads(result_str)
        except json.JSONDecodeError as e:
            pytest.fail(f"Tool '{tool_name}' returned invalid JSON: {e}\nOutput: {result_str}")