from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date

import httpx
import structlog
from tenacity import retry, stop_after_attempt, wait_exponential

from app.config import get_settings

log = structlog.get_logger()


# ── Weather result types ──────────────────────────────────────

@dataclass
class WeatherDay:
    date:             str
    temp_min_c:       float
    temp_max_c:       float
    condition:        str
    rain_probability: int
    humidity:         int
    wind_kmh:         float

@dataclass
class WeatherForecastResult:
    city:    str
    days:    list[WeatherDay]
    summary: str

@dataclass
class ClimateInfoResult:
    location:       str
    month:          int
    avg_temp_c:     float
    avg_rainy_days: int
    tourist_season: str
    summary:        str


# ── Places result types ───────────────────────────────────────

@dataclass
class PlaceResult:
    place_id:          str
    name:              str
    category:          str
    rating:            float | None
    review_count:      int | None
    address:           str
    latitude:          float
    longitude:         float
    price_level:       int | None
    image_url:         str | None
    tags:              list[str]
    short_description: str | None = None

@dataclass
class PlacesSearchResult:
    city:     str
    category: str
    places:   list[PlaceResult]

@dataclass
class PlaceDetailsResult:
    place_id:                      str
    name:                          str
    full_description:              str | None
    opening_hours:                 dict[str, str]
    is_open_now:                   bool | None
    admission_price_eur:           float | None
    recommended_visit_duration_min: int | None
    best_time_to_visit:            str | None
    insider_tip:                   str | None
    website_url:                   str | None
    phone_number:                  str | None

@dataclass
class TravelTimeResult:
    origin:         str
    destination:    str
    walking_minutes: int | None
    transit_minutes: int | None
    taxi_minutes:   int | None
    taxi_cost_est:  float | None
    distance_km:    float | None


# ── Static climate data ───────────────────────────────────────

@dataclass
class _ClimateData:
    avg_temp_c:     float
    avg_rainy_days: int
    season:         str
    summary:        str

_CLIMATE: dict[str, _ClimateData] = {
    "TURKEY_9":    _ClimateData(28.0, 3,  "Shoulder",   "Warm and mostly sunny. Sea still warm (26°C). Less crowded than summer."),
    "TURKEY_10":   _ClimateData(22.0, 5,  "Shoulder",   "Pleasant 22°C. Ideal for sightseeing. Some rain possible but rarely heavy."),
    "TURKEY_11":   _ClimateData(16.0, 8,  "Off-season", "Cooler and quiet. Great for Istanbul culture. Beach resorts closing."),
    "ISTANBUL_9":  _ClimateData(24.0, 5,  "Peak",       "Warm and pleasant. Evenings on the Bosphorus are magical."),
    "BALI_7":      _ClimateData(27.0, 2,  "Peak",       "Dry season peak. Perfect beach weather. Book well in advance."),
    "BALI_1":      _ClimateData(28.0, 18, "Off-season", "Rainy season. Lush greenery but frequent showers. Much cheaper prices."),
    "PARIS_5":     _ClimateData(18.0, 9,  "Shoulder",   "Lovely spring weather. Cafes and gardens in bloom. Pack a light jacket."),
    "PARIS_7":     _ClimateData(25.0, 5,  "Peak",       "Warm and sunny. City is busy. Many locals on holiday."),
    "AMSTERDAM_4": _ClimateData(11.0, 11, "Shoulder",   "Tulip season. Mild but changeable. Perfect for cycling without summer crowds."),
    "ATHENS_9":    _ClimateData(26.0, 2,  "Shoulder",   "Perfect weather. Beaches still warm. Crowds thinner than July/August."),
    "TOKYO_4":     _ClimateData(15.0, 10, "Peak",       "Cherry blossom season. Beautiful but crowded. Book months in advance."),
}


# ── OpenWeather client ────────────────────────────────────────

class OpenWeatherClient:
    def __init__(self) -> None:
        cfg = get_settings()
        self._api_key = cfg.openweather_api_key
        self._http    = httpx.AsyncClient(timeout=10.0)

    @retry(stop=stop_after_attempt(2), wait=wait_exponential(min=1, max=3))
    async def get_forecast(
        self, city: str, date_from: date, date_to: date
    ) -> WeatherForecastResult:
        try:
            resp = await self._http.get(
                "https://api.openweathermap.org/data/2.5/forecast",
                params={"q": city, "appid": self._api_key, "units": "metric", "cnt": 40},
            )
            resp.raise_for_status()
            slots = resp.json().get("list", [])
        except Exception as e:
            log.error("openweather.forecast.error", city=city, error=str(e))
            return WeatherForecastResult(city, [], f"Weather data unavailable for {city}.")

        # Group 3h slots by date, pick daily min/max
        grouped: dict[str, list[dict]] = {}
        for slot in slots:
            d = slot["dt_txt"][:10]
            if date_from.isoformat() <= d <= date_to.isoformat():
                grouped.setdefault(d, []).append(slot)

        days = []
        for d, day_slots in sorted(grouped.items()):
            temps = [s["main"]["temp"] for s in day_slots]
            rain_prob = max(s.get("pop", 0.0) for s in day_slots)
            cond = day_slots[len(day_slots) // 2]["weather"][0]["main"]
            days.append(WeatherDay(
                date             = d,
                temp_min_c       = round(min(temps), 1),
                temp_max_c       = round(max(temps), 1),
                condition        = cond,
                rain_probability = int(rain_prob * 100),
                humidity         = day_slots[0]["main"]["humidity"],
                wind_kmh         = round(day_slots[0]["wind"]["speed"] * 3.6, 1),
            ))

        if not days:
            summary = f"No forecast available for {city}."
        else:
            avg_max = sum(d.temp_max_c for d in days) / len(days)
            rainy   = sum(1 for d in days if d.rain_probability > 40)
            summary = f"Avg high {avg_max:.0f}°C. " + (
                "No rain expected." if not rainy else f"{rainy} day(s) with possible rain."
            )

        return WeatherForecastResult(city, days, summary)

    def get_climate_info(self, location: str, month: int) -> ClimateInfoResult:
        key  = f"{location.upper()}_{month}"
        data = _CLIMATE.get(key)
        if not data:
            # Fallback: find any entry for this location, or generic
            for k, v in _CLIMATE.items():
                if k.startswith(location.upper() + "_"):
                    data = v
                    break
            else:
                data = _ClimateData(20.0, 7, "Unknown", "Climate data not available. Check local sources.")

        return ClimateInfoResult(
            location       = location,
            month          = month,
            avg_temp_c     = data.avg_temp_c,
            avg_rainy_days = data.avg_rainy_days,
            tourist_season = data.season,
            summary        = data.summary,
        )

    async def aclose(self) -> None:
        await self._http.aclose()


# ── Google Places client ──────────────────────────────────────

_CATEGORY_TO_TYPE: dict[str, str] = {
    "RESTAURANT":   "restaurant",
    "MUSEUM":       "museum",
    "BEACH":        "natural_feature",
    "PARK":         "park",
    "SHOPPING":     "shopping_mall",
    "NIGHTLIFE":    "bar",
    "SPA":          "spa",
    "SIGHTSEEING":  "tourist_attraction",
}


class GooglePlacesClient:
    def __init__(self) -> None:
        cfg = get_settings()
        self._places_key = cfg.google_places_api_key
        self._maps_key   = cfg.google_maps_api_key
        self._http       = httpx.AsyncClient(timeout=10.0)

    @retry(stop=stop_after_attempt(2), wait=wait_exponential(min=1, max=3))
    async def search_places(
        self,
        city: str,
        category: str,
        tags: list[str] | None = None,
        max_results: int = 8,
    ) -> PlacesSearchResult:
        tag_str = " ".join((tags or [])[:3])
        query   = f"{category} {tag_str} in {city}".strip()
        g_type  = _CATEGORY_TO_TYPE.get(category.upper(), "tourist_attraction")

        try:
            resp = await self._http.get(
                "https://maps.googleapis.com/maps/api/place/textsearch/json",
                params={"query": query, "key": self._places_key, "type": g_type, "language": "en"},
            )
            resp.raise_for_status()
            results = resp.json().get("results", [])
        except Exception as e:
            log.error("google.places.search.error", city=city, category=category, error=str(e))
            return PlacesSearchResult(city, category, [])

        places = []
        for r in results[:max_results]:
            photo_ref = (r.get("photos") or [{}])[0].get("photo_reference")
            places.append(PlaceResult(
                place_id     = r["place_id"],
                name         = r["name"],
                category     = category,
                rating       = r.get("rating"),
                review_count = r.get("user_ratings_total"),
                address      = r.get("formatted_address") or r.get("vicinity") or city,
                latitude     = r["geometry"]["location"]["lat"],
                longitude    = r["geometry"]["location"]["lng"],
                price_level  = r.get("price_level"),
                image_url    = self._photo_url(photo_ref) if photo_ref else None,
                tags         = r.get("types") or [],
            ))
        return PlacesSearchResult(city, category, places)

    @retry(stop=stop_after_attempt(2), wait=wait_exponential(min=1, max=3))
    async def get_place_details(self, place_id: str) -> PlaceDetailsResult:
        try:
            resp = await self._http.get(
                "https://maps.googleapis.com/maps/api/place/details/json",
                params={
                    "place_id": place_id,
                    "key":      self._places_key,
                    "fields":   "name,editorial_summary,opening_hours,website,formatted_phone_number",
                    "language": "en",
                },
            )
            resp.raise_for_status()
            r = resp.json().get("result", {})
        except Exception as e:
            log.error("google.places.details.error", place_id=place_id, error=str(e))
            return PlaceDetailsResult(place_id, "Unknown", None, {}, None, None, None, None, None, None, None)

        hours_raw   = r.get("opening_hours", {}).get("weekday_text") or []
        hours: dict[str, str] = {}
        for line in hours_raw:
            parts = line.split(": ", 1)
            if len(parts) == 2:
                hours[parts[0]] = parts[1]

        return PlaceDetailsResult(
            place_id                       = place_id,
            name                           = r.get("name", ""),
            full_description               = r.get("editorial_summary", {}).get("overview"),
            opening_hours                  = hours,
            is_open_now                    = r.get("opening_hours", {}).get("open_now"),
            admission_price_eur            = None,
            recommended_visit_duration_min = None,
            best_time_to_visit             = None,
            insider_tip                    = None,
            website_url                    = r.get("website"),
            phone_number                   = r.get("formatted_phone_number"),
        )

    @retry(stop=stop_after_attempt(2), wait=wait_exponential(min=1, max=3))
    async def get_travel_time(
        self, origin: str, destination: str, city: str
    ) -> TravelTimeResult:
        try:
            resp = await self._http.get(
                "https://maps.googleapis.com/maps/api/distancematrix/json",
                params={
                    "origins":      f"{origin}, {city}",
                    "destinations": f"{destination}, {city}",
                    "mode":         "transit",
                    "key":          self._maps_key,
                    "language":     "en",
                },
            )
            resp.raise_for_status()
            el = resp.json()["rows"][0]["elements"][0]
        except Exception as e:
            log.error("google.distance.error", error=str(e))
            return TravelTimeResult(origin, destination, None, None, None, None, None)

        transit_sec = el.get("duration", {}).get("value")
        dist_m      = el.get("distance", {}).get("value")
        dist_km     = dist_m / 1000 if dist_m else None

        return TravelTimeResult(
            origin          = origin,
            destination     = destination,
            walking_minutes = int(dist_km / 5 * 60) if dist_km else None,
            transit_minutes = transit_sec // 60 if transit_sec else None,
            taxi_minutes    = int(dist_km / 30 * 60 + 5) if dist_km else None,
            taxi_cost_est   = round(dist_km * 1.5, 2) if dist_km else None,
            distance_km     = dist_km,
        )

    def _photo_url(self, ref: str) -> str:
        return (
            f"https://maps.googleapis.com/maps/api/place/photo"
            f"?maxwidth=800&photo_reference={ref}&key={self._places_key}"
        )

    async def aclose(self) -> None:
        await self._http.aclose()
