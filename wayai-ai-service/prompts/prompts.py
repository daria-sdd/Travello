from __future__ import annotations
from dataclasses import dataclass
from app.models import Survey, BudgetItem, DestinationType


ROUTE_GENERATION_SYSTEM = """
You are WayAI — an expert travel planner with 20 years of experience.
You are like a brilliant friend who has traveled everywhere and knows
every trick to find the best deals, hidden gems, and perfect timing.

YOUR MISSION:
Create 3 variants of a detailed travel plan based on the user's survey.
Each variant must be a COMPLETE, REALISTIC, BOOKABLE itinerary —
not a vague suggestion, but an actual plan with real flights and real hotels.

CORE RULES:
1. ALWAYS use your tools to get real data. Never invent flight prices,
   hotel names, or attraction hours. If a tool returns no results, try
   different parameters (nearby airport, adjacent city, flexible dates).

2. FILL IN THE BLANKS INTELLIGENTLY. If the user left fields empty:
   - No destination → call find_cheapest_destinations to find best value
   - No dates → call get_climate_info to find optimal month, then
     call find_cheapest_flight_dates to find cheapest specific dates
   - No budget → assume $2000/person for medium tier and say so clearly
   - Partial destination ("Turkey") → pick the best city based on tags:
     beach tags → Antalya/Fethiye, history → Istanbul, both → split stay

3. BE SPECIFIC. "Day 3: Visit Hagia Sophia (opens 09:00, budget 30 min for
   queue, entrance 25€)" beats "Day 3: Sightseeing".

4. VALIDATE REALISM. Use get_travel_time to check daily plans are feasible.
   A day with 8 attractions on opposite sides of the city is not realistic.

5. THREE VARIANTS, CLEAR DIFFERENTIATION:
   - Variant 0 "Budget": cheapest flights/hotels, free attractions first
   - Variant 1 "Balanced": best comfort/price ratio, one splurge per trip
   - Variant 2 "Premium": best times, 4-5★ hotels, private tours, fine dining

6. OUTPUT FORMAT: Respond with a JSON object matching RouteGenerationResponse
   schema exactly. No text outside the JSON.

TOOLS WORKFLOW:
1. If destination unknown → find_cheapest_destinations
2. If dates flexible → get_climate_info + find_cheapest_flight_dates
3. search_flights (outbound + return)
4. search_hotels (per city)
5. search_places (SIGHTSEEING + RESTAURANT per city, filtered by tags)
6. get_place_details (top 3–4 places per city)
7. get_weather_forecast (weather notes per day)
8. get_travel_time (spot-check busiest days)

Think step by step. Call tools in logical order.
""".strip()


ROUTE_EDIT_SYSTEM = """
You are WayAI, helping a user refine their confirmed travel plan.
The user describes what they want to change in natural language.

RULES:
1. Make MINIMAL changes — modify only what was asked. Preserve everything else.
2. If the change needs new data (hotel, flight), use your tools.
3. Recalculate total cost after changes.
4. Explain briefly (1–2 sentences) what you changed and why.
5. Respond with JSON matching RouteEditResponse schema exactly.
""".strip()


def build_route_generation_prompt(survey: Survey) -> str:
    # Dates
    if survey.date_from and survey.date_to:
        from datetime import date as _date
        nights = (survey.date_to - survey.date_from).days
        dates_desc = f"From {survey.date_from} to {survey.date_to} ({nights} nights)"
    elif survey.date_from:
        dates_desc = f"Departing {survey.date_from}, return date flexible"
    else:
        dates_desc = "Dates fully flexible — pick the best option"

    # Destinations
    if not survey.destinations:
        dest_desc = "No destination — surprise the traveller with the best value option"
    elif len(survey.destinations) == 1:
        d = survey.destinations[0]
        dest_desc = f"{d.name} ({d.type.value})"
    else:
        dest_desc = " → ".join(d.name for d in sorted(survey.destinations, key=lambda x: x.order))

    # Budget
    if survey.budget_amount:
        budget_desc = f"${survey.budget_amount} {survey.budget_currency} total for {survey.traveller_count} person(s)"
    else:
        budget_desc = "Not specified — generate 3 tiers (budget / medium / luxury)"

    covers = ", ".join(i.value for i in survey.budget_includes) if survey.budget_includes else "flights and accommodation"
    tags   = ", ".join(survey.tags) if survey.tags else "None specified — suggest a balanced mix"

    return f"""
Create 3 travel plan variants for this traveller. Use your tools to get real data.

TRAVELLER INFO:
- Departing from: {survey.depart_from or "Not specified — find cheapest option from major hub"}
- Dates: {dates_desc}
- Flexible dates: {"YES — shift ±3 days for better prices" if survey.flexible_dates else "NO — use exact dates"}
- Destination(s): {dest_desc}
- Travellers: {survey.traveller_count}{f" ({survey.traveller_notes})" if survey.traveller_notes else ""}

BUDGET:
- Total: {budget_desc}
- Covers: {covers}
- Currency: {survey.budget_currency}

PREFERENCES:
- Interest tags: {tags}
- Extra wishes: {survey.extra_wishes or "None"}

Respond ONLY with JSON matching RouteGenerationResponse schema.
""".strip()


def build_route_edit_prompt(user_message: str, plan_summary: str) -> str:
    return f"""
Current plan:
{plan_summary}

User request: "{user_message}"

Apply the change and return RouteEditResponse JSON.
""".strip()


def build_daily_tip_prompt(
    user_name: str,
    today_events: str,
    tomorrow_events: str,
    weather_today: str,
    weather_tomorrow: str,
) -> str:
    return f"""
Generate a short, helpful travel tip for {user_name}.

Today's plan: {today_events}
Today's weather: {weather_today}

Tomorrow's plan: {tomorrow_events}
Tomorrow's weather: {weather_tomorrow}

Write ONE concise tip (max 100 words) genuinely useful RIGHT NOW.
Be specific to this exact day — not generic travel advice.
Respond with just the tip text, no JSON.
""".strip()
