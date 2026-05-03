from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, date
from decimal import Decimal
from enum import Enum
from typing import Any
from uuid import UUID, uuid4


# ── Enums ────────────────────────────────────────────────────

class SurveyStatus(str, Enum):
    PENDING    = "pending"
    PROCESSING = "processing"
    COMPLETED  = "completed"
    FAILED     = "failed"

class EventType(str, Enum):
    FLIGHT        = "flight"
    ACCOMMODATION = "accommodation"
    TRANSPORT     = "transport"
    ACTIVITY      = "activity"
    RESTAURANT    = "restaurant"
    FREE_TIME     = "free_time"
    NOTE          = "note"

class ExternalSource(str, Enum):
    AMADEUS       = "amadeus"
    BOOKING_COM   = "booking_com"
    GOOGLE_PLACES = "google_places"
    VIATOR        = "viator"

class DestinationType(str, Enum):
    COUNTRY = "country"
    CITY    = "city"
    REGION  = "region"
    ANY     = "any"

class BudgetItem(str, Enum):
    FLIGHTS       = "flights"
    ACCOMMODATION = "accommodation"
    FOOD          = "food"
    ACTIVITIES    = "activities"


# ── Survey ───────────────────────────────────────────────────

@dataclass
class SurveyDestination:
    name:  str
    type:  DestinationType
    order: int

@dataclass
class Survey:
    id:              UUID
    user_id:         UUID
    status:          SurveyStatus      = SurveyStatus.PENDING
    depart_from:     str | None        = None
    date_from:       date | None       = None
    date_to:         date | None       = None
    flexible_dates:  bool              = False
    destinations:    list[SurveyDestination] = field(default_factory=list)
    budget_amount:   Decimal | None    = None
    budget_currency: str               = "USD"
    budget_includes: list[BudgetItem]  = field(default_factory=lambda: [BudgetItem.FLIGHTS, BudgetItem.ACCOMMODATION])
    tags:            list[str]         = field(default_factory=list)
    extra_wishes:    str | None        = None
    traveller_count: int               = 1
    traveller_notes: str | None        = None
    created_at:      datetime          = field(default_factory=datetime.utcnow)


# ── Route ────────────────────────────────────────────────────

@dataclass
class RouteEvent:
    id:              UUID            = field(default_factory=uuid4)
    route_day_id:    UUID            = field(default_factory=uuid4)
    route_id:        UUID            = field(default_factory=uuid4)
    event_type:      EventType       = EventType.NOTE
    sort_order:      int             = 0
    starts_at:       datetime | None = None
    ends_at:         datetime | None = None
    duration_min:    int | None      = None
    title:           str | None      = None
    description:     str | None      = None
    location_name:   str | None      = None
    address:         str | None      = None
    city:            str | None      = None
    country_code:    str | None      = None
    latitude:        float | None    = None
    longitude:       float | None    = None
    google_place_id: str | None      = None
    image_url:       str | None      = None
    cost_est:        Decimal | None  = None
    currency:        str             = "USD"
    is_prepaid:      bool            = False
    external_id:     str | None      = None
    external_source: ExternalSource | None = None
    booking_ref:     str | None      = None
    ai_tip:          str | None      = None
    ai_confidence:   float | None    = None

@dataclass
class RouteDay:
    id:           UUID            = field(default_factory=uuid4)
    route_id:     UUID            = field(default_factory=uuid4)
    day_number:   int             = 1
    date:         date | None     = None
    city:         str | None      = None
    country:      str | None      = None
    country_code: str | None      = None
    summary:      str | None      = None
    weather_note: str | None      = None
    events:       list[RouteEvent] = field(default_factory=list)

@dataclass
class Route:
    id:             UUID             = field(default_factory=uuid4)
    survey_id:      UUID             = field(default_factory=uuid4)
    user_id:        UUID             = field(default_factory=uuid4)
    status:         str              = "draft"
    title:          str | None       = None
    summary:        str | None       = None
    cover_image_url: str | None      = None
    total_days:     int | None       = None
    total_cost_est: Decimal | None   = None
    currency:       str              = "USD"
    days:           list[RouteDay]   = field(default_factory=list)
    variant_index:  int              = 0
    variant_label:  str | None       = None
    confirmed_at:   datetime | None  = None
    created_at:     datetime         = field(default_factory=datetime.utcnow)
    updated_at:     datetime         = field(default_factory=datetime.utcnow)


# ── Kafka event ──────────────────────────────────────────────

@dataclass
class RouteGenerationEvent:
    surveyId:     str
    userId:       str
    triggeredAt:  int = field(default_factory=lambda: int(datetime.utcnow().timestamp() * 1000))
