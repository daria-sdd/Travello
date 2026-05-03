from __future__ import annotations

import json
from datetime import date, datetime

from app.clients.amadeus import AmadeusClient
from app.clients.external import GooglePlacesClient, OpenWeatherClient


# ── Tool result serialization helper ─────────────────────────
# Claude receives tool results as strings — we dump dataclasses to JSON.

def _dump(obj) -> str:
    def default(o):
        if hasattr(o, "__dict__"):
            return o.__dict__
        if isinstance(o, (date, datetime)):
            return o.isoformat()
        return str(o)
    return json.dumps(obj, default=default, ensure_ascii=False)


# ── Tool definitions ──────────────────────────────────────────
# Each entry is an Anthropic API tool definition dict.
# The actual Python functions are in ToolExecutor below.

TOOL_DEFINITIONS = [
    {
        "name": "search_flights",
        "description": (
            "Search for available flights between two airports or cities. "
            "Use IATA codes when known (IST, AYT, SVO...). "
            "Returns real flight offers with prices, airlines, and departure times. "
            "Always call this when the user wants flights or to validate a route is reachable."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "origin":         {"type": "string", "description": "Departure city or IATA code, e.g. 'Moscow' or 'SVO'"},
                "destination":    {"type": "string", "description": "Destination city or IATA code, e.g. 'Istanbul' or 'IST'"},
                "departure_date": {"type": "string", "description": "Departure date YYYY-MM-DD"},
                "return_date":    {"type": "string", "description": "Return date YYYY-MM-DD, or empty string for one-way"},
                "adults":         {"type": "integer", "description": "Number of adult passengers", "default": 1},
                "travel_class":   {"type": "string",  "description": "ECONOMY | PREMIUM_ECONOMY | BUSINESS | FIRST", "default": "ECONOMY"},
                "max_results":    {"type": "integer", "description": "Max results 1–10", "default": 5},
            },
            "required": ["origin", "destination", "departure_date"],
        },
    },
    {
        "name": "find_cheapest_flight_dates",
        "description": (
            "Find the cheapest months or dates to fly between two cities. "
            "Use when the user has flexible dates or when you want to suggest "
            "the best time to travel for budget reasons."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "origin":      {"type": "string", "description": "Departure city or IATA code"},
                "destination": {"type": "string", "description": "Destination city or IATA code"},
            },
            "required": ["origin", "destination"],
        },
    },
    {
        "name": "find_cheapest_destinations",
        "description": (
            "Find the cheapest destinations reachable from a given origin city. "
            "Use when the user does not know where to go, or says 'surprise me'. "
            "Returns top destinations sorted by price."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "origin":           {"type": "string", "description": "Departure city or IATA code"},
                "departure_month":  {"type": "string", "description": "YYYY-MM format, or empty for any month"},
                "max_budget":       {"type": "integer", "description": "Max budget per person in USD", "default": 2000},
            },
            "required": ["origin"],
        },
    },
    {
        "name": "search_hotels",
        "description": (
            "Search for hotels in a city with real prices and availability. "
            "Use when building accommodation blocks in the travel plan."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "city":        {"type": "string",  "description": "City name or IATA city code"},
                "check_in":    {"type": "string",  "description": "Check-in date YYYY-MM-DD"},
                "check_out":   {"type": "string",  "description": "Check-out date YYYY-MM-DD"},
                "adults":      {"type": "integer", "description": "Number of guests", "default": 1},
                "budget_tier": {"type": "string",  "description": "BUDGET | MEDIUM | LUXURY", "default": "MEDIUM"},
                "max_results": {"type": "integer", "description": "Max results", "default": 5},
            },
            "required": ["city", "check_in", "check_out"],
        },
    },
    {
        "name": "get_weather_forecast",
        "description": (
            "Get weather forecast for a city for specific dates. "
            "Use to validate weather matches user preferences and add daily weather notes."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "city":      {"type": "string", "description": "City name"},
                "date_from": {"type": "string", "description": "Start date YYYY-MM-DD"},
                "date_to":   {"type": "string", "description": "End date YYYY-MM-DD"},
            },
            "required": ["city", "date_from", "date_to"],
        },
    },
    {
        "name": "get_climate_info",
        "description": (
            "Get historical climate data for a city and month. "
            "Use when dates are flexible — to recommend the best month to visit. "
            "Returns average temperature, rainfall, and tourism season info."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "location": {"type": "string",  "description": "City or country name"},
                "month":    {"type": "integer", "description": "Month number 1–12"},
            },
            "required": ["location", "month"],
        },
    },
    {
        "name": "search_places",
        "description": (
            "Search for tourist attractions, restaurants, museums, beaches etc. "
            "Returns top places with ratings, photos, and tips. "
            "Use to fill activity blocks in the travel plan."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "city":        {"type": "string", "description": "City name"},
                "category":    {"type": "string", "description": "SIGHTSEEING | RESTAURANT | MUSEUM | BEACH | MARKET | PARK | SHOPPING | NIGHTLIFE | SPA"},
                "tags":        {"type": "string", "description": "Comma-separated interest tags, e.g. 'history,architecture'"},
                "max_results": {"type": "integer", "description": "Max results", "default": 8},
            },
            "required": ["city", "category"],
        },
    },
    {
        "name": "get_place_details",
        "description": (
            "Get detailed info about a specific place: opening hours, admission prices, "
            "visit duration, insider tips. Call after search_places for key places."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "place_id": {"type": "string", "description": "Google Place ID from search_places result"},
            },
            "required": ["place_id"],
        },
    },
    {
        "name": "get_travel_time",
        "description": (
            "Calculate travel time between two places in a city. "
            "Use to check that daily itineraries are logistically realistic."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "origin":      {"type": "string", "description": "Origin place name"},
                "destination": {"type": "string", "description": "Destination place name"},
                "city":        {"type": "string", "description": "City for context"},
            },
            "required": ["origin", "destination", "city"],
        },
    },
]


# ── Tool executor ─────────────────────────────────────────────

class ToolExecutor:
    """
    Receives tool_use blocks from Claude's response,
    dispatches to the right client method, returns result string.
    """

    def __init__(
        self,
        amadeus: AmadeusClient,
        weather: OpenWeatherClient,
        places: GooglePlacesClient,
    ) -> None:
        self._amadeus = amadeus
        self._weather = weather
        self._places  = places

    async def execute(self, tool_name: str, tool_input: dict) -> str:
        match tool_name:
            case "search_flights":
                result = await self._amadeus.search_flights(
                    origin        = tool_input["origin"],
                    destination   = tool_input["destination"],
                    depart_date   = date.fromisoformat(tool_input["departure_date"]),
                    return_date   = date.fromisoformat(r) if (r := tool_input.get("return_date", "")) else None,
                    adults        = tool_input.get("adults", 1),
                    travel_class  = tool_input.get("travel_class", "ECONOMY"),
                    max_results   = tool_input.get("max_results", 5),
                )

            case "find_cheapest_flight_dates":
                result = await self._amadeus.find_cheapest_dates(
                    origin      = tool_input["origin"],
                    destination = tool_input["destination"],
                )

            case "find_cheapest_destinations":
                result = await self._amadeus.find_destination_inspiration(
                    origin           = tool_input["origin"],
                    departure_month  = tool_input.get("departure_month", ""),
                    max_budget       = tool_input.get("max_budget", 2000),
                )

            case "search_hotels":
                result = await self._amadeus.search_hotels(
                    city        = tool_input["city"],
                    check_in    = date.fromisoformat(tool_input["check_in"]),
                    check_out   = date.fromisoformat(tool_input["check_out"]),
                    adults      = tool_input.get("adults", 1),
                    budget_tier = tool_input.get("budget_tier", "MEDIUM"),
                    max_results = tool_input.get("max_results", 5),
                )

            case "get_weather_forecast":
                result = await self._weather.get_forecast(
                    city      = tool_input["city"],
                    date_from = date.fromisoformat(tool_input["date_from"]),
                    date_to   = date.fromisoformat(tool_input["date_to"]),
                )

            case "get_climate_info":
                result = self._weather.get_climate_info(
                    location = tool_input["location"],
                    month    = tool_input["month"],
                )

            case "search_places":
                result = await self._places.search_places(
                    city        = tool_input["city"],
                    category    = tool_input["category"],
                    tags        = [t.strip() for t in tool_input.get("tags", "").split(",") if t.strip()],
                    max_results = tool_input.get("max_results", 8),
                )

            case "get_place_details":
                result = await self._places.get_place_details(tool_input["place_id"])

            case "get_travel_time":
                result = await self._places.get_travel_time(
                    origin      = tool_input["origin"],
                    destination = tool_input["destination"],
                    city        = tool_input["city"],
                )

            case _:
                return json.dumps({"error": f"Unknown tool: {tool_name}"})

        return _dump(result)
