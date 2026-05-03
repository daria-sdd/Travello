from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass, field
from datetime import date
from typing import Any

import httpx
import structlog
from tenacity import retry, stop_after_attempt, wait_exponential

from app.config import get_settings

log = structlog.get_logger()


# ── Result dataclasses ───────────────────────────────────────

@dataclass
class FlightOffer:
    offer_id:         str
    airline:          str
    flight_number:    str
    departure_time:   str
    arrival_time:     str
    duration_hours:   float
    stops:            int
    price_per_person: float
    currency:         str
    cabin_class:      str
    baggage_included: bool
    seats_available:  int | None = None

@dataclass
class FlightSearchResult:
    found:          bool
    offers:         list[FlightOffer]
    search_summary: str

@dataclass
class CheapDateOption:
    departure_date:   str
    return_date:      str | None
    price_per_person: float
    currency:         str

@dataclass
class CheapestDatesResult:
    origin:           str
    destination:      str
    cheapest_options: list[CheapDateOption]

@dataclass
class InspirationDestination:
    destination:    str
    country:        str
    price_from:     float
    currency:       str
    departure_date: str | None
    highlights:     list[str] = field(default_factory=list)

@dataclass
class DestinationInspirationResult:
    origin:       str
    destinations: list[InspirationDestination]

@dataclass
class HotelOffer:
    hotel_id:              str
    name:                  str
    stars:                 int
    rating:                float | None
    review_count:          int | None
    address:               str
    distance_to_center_km: float | None
    price_per_night:       float
    total_price:           float
    currency:              str
    breakfast_included:    bool
    cancellation_policy:   str
    amenities:             list[str]
    image_url:             str | None = None

@dataclass
class HotelSearchResult:
    found:          bool
    hotels:         list[HotelOffer]
    search_summary: str


# ── Token cache ──────────────────────────────────────────────

@dataclass
class _Token:
    access_token: str
    expires_at:   float

    def is_expired(self) -> bool:
        return time.monotonic() >= self.expires_at


# ── Client ───────────────────────────────────────────────────

CITY_TO_IATA: dict[str, str] = {
    "MOSCOW": "SVO", "ISTANBUL": "IST", "ANTALYA": "AYT",
    "FETHIYE": "DLM", "AMSTERDAM": "AMS", "LONDON": "LHR",
    "PARIS": "CDG", "DUBAI": "DXB", "BANGKOK": "BKK",
    "BALI": "DPS", "ROME": "FCO", "BARCELONA": "BCN",
    "PRAGUE": "PRG", "LISBON": "LIS", "ATHENS": "ATH",
    "TOKYO": "NRT", "NEW YORK": "JFK", "DUBAI": "DXB",
}


class AmadeusClient:
    def __init__(self) -> None:
        cfg = get_settings()
        self._client_id     = cfg.amadeus_client_id
        self._client_secret = cfg.amadeus_client_secret
        self._base_url      = cfg.amadeus_base_url
        self._token: _Token | None = None
        self._lock = asyncio.Lock()
        # Единый httpx.AsyncClient переиспользуется — нет overhead на создание соединений
        self._http = httpx.AsyncClient(timeout=15.0)

    # ── Auth ─────────────────────────────────────────────────

    async def _get_token(self) -> str:
        async with self._lock:
            if self._token and not self._token.is_expired():
                return self._token.access_token
            resp = await self._http.post(
                f"{self._base_url}/v1/security/oauth2/token",
                data={
                    "grant_type":    "client_credentials",
                    "client_id":     self._client_id,
                    "client_secret": self._client_secret,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            self._token = _Token(
                access_token=data["access_token"],
                # 30s buffer before expiry
                expires_at=time.monotonic() + data["expires_in"] - 30,
            )
            log.info("amadeus.token_refreshed", expires_in=data["expires_in"])
            return self._token.access_token

    def _headers(self, token: str) -> dict[str, str]:
        return {"Authorization": f"Bearer {token}"}

    def _resolve_airport(self, loc: str) -> str:
        upper = loc.strip().upper()
        if len(upper) == 3:
            return upper
        return CITY_TO_IATA.get(upper, upper[:3])

    def _resolve_city_code(self, city: str) -> str:
        iata = CITY_TO_IATA.get(city.strip().upper())
        return (iata or city.strip().upper())[:3]

    @staticmethod
    def _parse_duration(iso: str) -> float:
        """'PT2H35M' → 2.58"""
        import re
        h = float(re.search(r"(\d+)H", iso).group(1)) if re.search(r"(\d+)H", iso) else 0.0
        m = float(re.search(r"(\d+)M", iso).group(1)) if re.search(r"(\d+)M", iso) else 0.0
        return h + m / 60

    @staticmethod
    def _hotel_ratings(tier: str) -> str:
        return {"BUDGET": "1,2,3", "LUXURY": "4,5"}.get(tier.upper(), "3,4")

    # ── Flights ──────────────────────────────────────────────

    @retry(stop=stop_after_attempt(2), wait=wait_exponential(min=1, max=4))
    async def search_flights(
        self,
        origin: str,
        destination: str,
        depart_date: date,
        return_date: date | None = None,
        adults: int = 1,
        travel_class: str = "ECONOMY",
        max_results: int = 5,
    ) -> FlightSearchResult:
        token = await self._get_token()
        params: dict[str, Any] = {
            "originLocationCode":      self._resolve_airport(origin),
            "destinationLocationCode": self._resolve_airport(destination),
            "departureDate":           depart_date.isoformat(),
            "adults":                  adults,
            "travelClass":             travel_class.upper(),
            "max":                     max_results,
            "currencyCode":            "USD",
        }
        if return_date:
            params["returnDate"] = return_date.isoformat()

        try:
            resp = await self._http.get(
                f"{self._base_url}/v2/shopping/flight-offers",
                headers=self._headers(token),
                params=params,
            )
            resp.raise_for_status()
            data = resp.json().get("data", [])
        except Exception as e:
            log.error("amadeus.flights.error", error=str(e))
            return FlightSearchResult(False, [], f"Flight search failed: {e}. Try alternative airports.")

        offers = []
        for item in data:
            itin = item["itineraries"][0]
            seg  = itin["segments"][0]
            price = float(item["price"]["total"]) / adults
            bags  = (
                item.get("travelerPricings", [{}])[0]
                    .get("fareDetailsBySegment", [{}])[0]
                    .get("includedCheckedBags", {})
                    .get("quantity", 0) > 0
            )
            offers.append(FlightOffer(
                offer_id         = item["id"],
                airline          = seg["carrierCode"],
                flight_number    = f"{seg['carrierCode']}{seg['number']}",
                departure_time   = seg["departure"]["at"],
                arrival_time     = seg["arrival"]["at"],
                duration_hours   = self._parse_duration(itin["duration"]),
                stops            = len(itin["segments"]) - 1,
                price_per_person = round(price, 2),
                currency         = item["price"]["currency"],
                cabin_class      = travel_class,
                baggage_included = bags,
                seats_available  = item.get("numberOfBookableSeats"),
            ))

        summary = (
            f"No flights found for {origin} → {destination} on {depart_date}."
            if not offers else
            f"Found {len(offers)} flights. Cheapest: ${min(o.price_per_person for o in offers):.0f}/person."
        )
        return FlightSearchResult(bool(offers), offers, summary)

    @retry(stop=stop_after_attempt(2), wait=wait_exponential(min=1, max=4))
    async def find_cheapest_dates(self, origin: str, destination: str) -> CheapestDatesResult:
        token = await self._get_token()
        try:
            resp = await self._http.get(
                f"{self._base_url}/v1/shopping/flight-dates",
                headers=self._headers(token),
                params={
                    "origin":      self._resolve_airport(origin),
                    "destination": self._resolve_airport(destination),
                },
            )
            resp.raise_for_status()
            data = resp.json().get("data", [])
        except Exception as e:
            log.error("amadeus.cheapest_dates.error", error=str(e))
            return CheapestDatesResult(origin, destination, [])

        options = [
            CheapDateOption(
                departure_date   = item["departureDate"],
                return_date      = item.get("returnDate"),
                price_per_person = float(item["price"]["total"]),
                currency         = "USD",
            )
            for item in data[:10]
        ]
        return CheapestDatesResult(origin, destination, options)

    @retry(stop=stop_after_attempt(2), wait=wait_exponential(min=1, max=4))
    async def find_destination_inspiration(
        self,
        origin: str,
        departure_month: str = "",
        max_budget: int = 2000,
    ) -> DestinationInspirationResult:
        token = await self._get_token()
        params: dict[str, Any] = {
            "origin":   self._resolve_airport(origin),
            "maxPrice": max_budget,
        }
        if departure_month:
            params["departureDate"] = f"{departure_month}-01"
        try:
            resp = await self._http.get(
                f"{self._base_url}/v1/shopping/flight-destinations",
                headers=self._headers(token),
                params=params,
            )
            resp.raise_for_status()
            data = resp.json().get("data", [])
        except Exception as e:
            log.error("amadeus.inspiration.error", error=str(e))
            return DestinationInspirationResult(origin, [])

        destinations = [
            InspirationDestination(
                destination    = item["destination"],
                country        = item["destination"],
                price_from     = float(item["price"]["total"]),
                currency       = "USD",
                departure_date = item.get("departureDate"),
            )
            for item in data[:10]
        ]
        return DestinationInspirationResult(origin, destinations)

    # ── Hotels ───────────────────────────────────────────────

    @retry(stop=stop_after_attempt(2), wait=wait_exponential(min=1, max=4))
    async def search_hotels(
        self,
        city: str,
        check_in: date,
        check_out: date,
        adults: int = 1,
        budget_tier: str = "MEDIUM",
        max_results: int = 5,
    ) -> HotelSearchResult:
        token = await self._get_token()
        try:
            # Step 1: hotel list by city
            list_resp = await self._http.get(
                f"{self._base_url}/v1/reference-data/locations/hotels/by-city",
                headers=self._headers(token),
                params={
                    "cityCode":   self._resolve_city_code(city),
                    "radius":     5,
                    "radiusUnit": "KM",
                    "ratings":    self._hotel_ratings(budget_tier),
                },
            )
            list_resp.raise_for_status()
            hotel_ids = [h["hotelId"] for h in list_resp.json().get("data", [])[:20]]
            if not hotel_ids:
                return HotelSearchResult(False, [], f"No hotels found in {city}.")

            # Step 2: offers
            offers_resp = await self._http.get(
                f"{self._base_url}/v3/shopping/hotel-offers",
                headers=self._headers(token),
                params={
                    "hotelIds":    ",".join(hotel_ids[:10]),
                    "adults":      adults,
                    "checkInDate": check_in.isoformat(),
                    "checkOutDate": check_out.isoformat(),
                    "currencyCode": "USD",
                    "bestRateOnly": "true",
                },
            )
            offers_resp.raise_for_status()
            items = offers_resp.json().get("data", [])
        except Exception as e:
            log.error("amadeus.hotels.error", city=city, error=str(e))
            return HotelSearchResult(False, [], f"Hotel search failed: {e}")

        nights = (check_out - check_in).days or 1
        hotels = []
        for item in items[:max_results]:
            offer  = item["offers"][0]
            total  = float(offer["price"]["total"])
            hotel  = item["hotel"]
            hotels.append(HotelOffer(
                hotel_id              = hotel["hotelId"],
                name                  = hotel["name"],
                stars                 = int(hotel.get("rating") or 3),
                rating                = None,
                review_count          = None,
                address               = ", ".join(hotel.get("address", {}).get("lines", [city])),
                distance_to_center_km = None,
                price_per_night       = round(total / nights, 2),
                total_price           = round(total, 2),
                currency              = offer["price"]["currency"],
                breakfast_included    = "BREAKFAST" in (offer.get("boardType") or ""),
                cancellation_policy   = (
                    offer.get("policies", {})
                         .get("cancellations", [{}])[0]
                         .get("description", {})
                         .get("text", "See hotel policy")
                ),
                amenities = hotel.get("amenities") or [],
            ))

        summary = (
            f"No available hotels in {city} for those dates."
            if not hotels else
            f"Found {len(hotels)} hotels. Cheapest: ${min(h.price_per_night for h in hotels):.0f}/night."
        )
        return HotelSearchResult(bool(hotels), hotels, summary)

    async def aclose(self) -> None:
        await self._http.aclose()
