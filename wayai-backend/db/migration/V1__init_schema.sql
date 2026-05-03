-- ============================================================
-- WayAI — Database Schema v1
-- PostgreSQL 15+
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- for fuzzy search on place names

-- ============================================================
-- USERS
-- ============================================================

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_uid    VARCHAR(128) UNIQUE NOT NULL,   -- Firebase Auth UID
    email           VARCHAR(255) UNIQUE,
    display_name    VARCHAR(100),
    avatar_url      TEXT,
    locale          VARCHAR(10)  DEFAULT 'ru',       -- ui language
    currency        VARCHAR(3)   DEFAULT 'USD',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_firebase_uid ON users(firebase_uid);

-- ============================================================
-- USER PREFERENCES
-- One-to-one with users. Stores travel style, defaults for the survey.
-- ============================================================

CREATE TABLE user_preferences (
    user_id             UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    preferred_tags      TEXT[]       DEFAULT '{}',   -- e.g. {beach, history, food}
    budget_tier         VARCHAR(20)  DEFAULT 'medium', -- budget | medium | luxury
    preferred_airlines  TEXT[]       DEFAULT '{}',
    seat_class          VARCHAR(10)  DEFAULT 'economy', -- economy | business | first
    dietary_notes       TEXT,                           -- vegetarian, halal, etc.
    accessibility_notes TEXT,
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SURVEYS
-- Raw survey data submitted by user. AI reads from here.
-- ============================================================

CREATE TABLE surveys (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status          VARCHAR(20) NOT NULL DEFAULT 'pending',
    -- ^ pending | processing | completed | failed

    -- Dates (can be null = AI picks best time)
    depart_from     VARCHAR(100),                -- city/airport user flies from
    date_from       DATE,
    date_to         DATE,
    flexible_dates  BOOLEAN NOT NULL DEFAULT FALSE,

    -- Destinations (ordered list, can be empty = AI picks)
    destinations    JSONB NOT NULL DEFAULT '[]',
    -- [{"name": "Turkey", "type": "country", "order": 1}, ...]

    -- Budget
    budget_amount   NUMERIC(12, 2),
    budget_currency VARCHAR(3)   DEFAULT 'USD',
    budget_includes TEXT[]       DEFAULT '{}',
    -- ^ {flights, accommodation, food, activities}

    -- Preferences
    tags            TEXT[]       DEFAULT '{}',   -- selected hashtags
    extra_wishes    TEXT,                        -- free-text field
    traveller_count INT          NOT NULL DEFAULT 1,
    traveller_notes TEXT,                        -- "2 adults, 1 child 5yo"

    -- Meta
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    processing_started_at TIMESTAMPTZ,
    processing_finished_at TIMESTAMPTZ,
    error_message   TEXT
);

CREATE INDEX idx_surveys_user_id   ON surveys(user_id);
CREATE INDEX idx_surveys_status    ON surveys(status);

-- ============================================================
-- ROUTES
-- A generated travel plan. One survey → 2-3 route variants.
-- ============================================================

CREATE TABLE routes (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    survey_id       UUID NOT NULL REFERENCES surveys(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
    status          VARCHAR(20) NOT NULL DEFAULT 'draft',
    -- ^ draft | active | completed | archived

    -- Basic info (computed by AI)
    title           VARCHAR(255),              -- "Осенняя Турция: Фетхие + Стамбул"
    summary         TEXT,                      -- short AI-generated description
    cover_image_url TEXT,

    -- Totals (denormalized for quick display on list screens)
    total_days      INT,
    total_cost_est  NUMERIC(12, 2),
    currency        VARCHAR(3)   DEFAULT 'USD',

    -- AI-generated full plan stored as JSONB for flexibility
    -- Structure defined in RouteDay model below
    plan_raw        JSONB        NOT NULL DEFAULT '{}',

    -- Variant metadata (for the "pick one of 3" screen)
    variant_index   INT          NOT NULL DEFAULT 0,  -- 0, 1, 2
    variant_label   VARCHAR(50),                      -- "Бюджетный", "Балансовый", "Премиум"

    -- User confirmed this route
    confirmed_at    TIMESTAMPTZ,

    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_routes_user_id   ON routes(user_id);
CREATE INDEX idx_routes_survey_id ON routes(survey_id);
CREATE INDEX idx_routes_status    ON routes(status);

-- ============================================================
-- ROUTE DAYS
-- Normalized day-by-day breakdown (also in routes.plan_raw,
-- but normalized here for queries: "what's happening tomorrow").
-- ============================================================

CREATE TABLE route_days (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id        UUID NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    day_number      INT  NOT NULL,                    -- 1-based
    date            DATE,                             -- actual calendar date
    city            VARCHAR(100),
    country         VARCHAR(100),
    country_code    VARCHAR(3),                       -- ISO 3166-1 alpha-2
    summary         TEXT,                             -- "Прилет, заселение, прогулка по набережной"
    weather_note    TEXT,                             -- AI-generated weather forecast hint

    UNIQUE (route_id, day_number)
);

CREATE INDEX idx_route_days_route_id ON route_days(route_id);
CREATE INDEX idx_route_days_date     ON route_days(date);

-- ============================================================
-- ROUTE EVENTS
-- Individual events within a day: flights, hotels, POIs, restaurants.
-- ============================================================

CREATE TYPE event_type AS ENUM (
    'flight',
    'accommodation',
    'transport',     -- train, bus, taxi, car rental
    'activity',      -- sightseeing, tour, excursion
    'restaurant',
    'free_time',
    'note'
);

CREATE TABLE route_events (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_day_id    UUID        NOT NULL REFERENCES route_days(id)   ON DELETE CASCADE,
    route_id        UUID        NOT NULL REFERENCES routes(id)        ON DELETE CASCADE,
    event_type      event_type  NOT NULL,
    sort_order      INT         NOT NULL DEFAULT 0,

    -- Time
    starts_at       TIMESTAMPTZ,
    ends_at         TIMESTAMPTZ,
    duration_min    INT,                    -- estimated duration in minutes

    -- Place / Venue
    title           VARCHAR(255),
    description     TEXT,
    location_name   VARCHAR(255),
    address         TEXT,
    city            VARCHAR(100),
    country_code    VARCHAR(3),
    latitude        DOUBLE PRECISION,
    longitude       DOUBLE PRECISION,
    google_place_id VARCHAR(100),
    image_url       TEXT,

    -- Cost
    cost_est        NUMERIC(10, 2),
    currency        VARCHAR(3)  DEFAULT 'USD',
    is_prepaid      BOOLEAN     NOT NULL DEFAULT FALSE,

    -- External references (for booking cards)
    external_id     VARCHAR(255),    -- Amadeus offer ID, hotel ID, etc.
    external_source VARCHAR(50),     -- 'amadeus' | 'booking' | 'google_places'
    booking_ref     VARCHAR(100),    -- confirmation number (user-entered or parsed)

    -- AI metadata
    ai_tip          TEXT,            -- "Приходите до 9 утра — нет очередей"
    ai_confidence   FLOAT,           -- 0.0 - 1.0

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_route_events_route_id     ON route_events(route_id);
CREATE INDEX idx_route_events_route_day_id ON route_events(route_day_id);
CREATE INDEX idx_route_events_type         ON route_events(event_type);
CREATE INDEX idx_route_events_starts_at    ON route_events(starts_at);

-- ============================================================
-- BOOKINGS
-- Confirmed bookings attached to events. Stores QR, PNR, etc.
-- ============================================================

CREATE TYPE booking_status AS ENUM ('pending', 'confirmed', 'cancelled', 'completed');

CREATE TABLE bookings (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    route_event_id  UUID            REFERENCES route_events(id)   ON DELETE SET NULL,
    status          booking_status  NOT NULL DEFAULT 'pending',

    -- Booking details
    booking_ref     VARCHAR(100),          -- PNR / confirmation number
    provider_name   VARCHAR(100),          -- "Turkish Airlines", "Booking.com"
    provider_logo   TEXT,
    booking_url     TEXT,

    -- Dates
    booked_at       TIMESTAMPTZ,
    valid_from      TIMESTAMPTZ,
    valid_to        TIMESTAMPTZ,

    -- Cost
    amount_paid     NUMERIC(10, 2),
    currency        VARCHAR(3)     DEFAULT 'USD',

    -- Documents (stored in S3, URL here)
    qr_code_url     TEXT,
    ticket_pdf_url  TEXT,
    raw_data        JSONB          DEFAULT '{}',   -- parsed email / API response

    created_at      TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_bookings_user_id        ON bookings(user_id);
CREATE INDEX idx_bookings_route_event_id ON bookings(route_event_id);
CREATE INDEX idx_bookings_status         ON bookings(status);

-- ============================================================
-- NOTIFICATIONS
-- Scheduled AI notifications (push, in-app).
-- ============================================================

CREATE TYPE notification_type AS ENUM (
    'checkin_reminder',       -- check in 24h before flight
    'depart_reminder',        -- leave for airport N hours before
    'daily_tip',              -- AI tip of the day
    'weather_alert',          -- weather changed, plan adjusted
    'booking_expiry',         -- booking about to expire
    'route_ready',            -- AI finished generating the route
    'custom'
);

CREATE TABLE notifications (
    id              UUID                PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID                NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    route_id        UUID                REFERENCES routes(id) ON DELETE CASCADE,
    type            notification_type   NOT NULL,

    title           VARCHAR(255)        NOT NULL,
    body            TEXT                NOT NULL,
    deep_link       VARCHAR(255),       -- e.g. "wayai://route/123/event/456"

    -- Scheduling
    scheduled_at    TIMESTAMPTZ         NOT NULL,
    sent_at         TIMESTAMPTZ,
    read_at         TIMESTAMPTZ,
    is_sent         BOOLEAN             NOT NULL DEFAULT FALSE,
    is_read         BOOLEAN             NOT NULL DEFAULT FALSE,

    -- APNs / FCM delivery
    apns_id         VARCHAR(255),
    device_token    TEXT,

    created_at      TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id      ON notifications(user_id);
CREATE INDEX idx_notifications_scheduled_at ON notifications(scheduled_at) WHERE NOT is_sent;
CREATE INDEX idx_notifications_route_id     ON notifications(route_id);

-- ============================================================
-- AI CONVERSATION LOG
-- Stores the chat history for each route (for NLP edits).
-- ============================================================

CREATE TABLE ai_conversations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    route_id        UUID REFERENCES routes(id) ON DELETE CASCADE,
    survey_id       UUID REFERENCES surveys(id) ON DELETE CASCADE,

    -- 'user' | 'assistant' | 'tool_result'
    role            VARCHAR(20)  NOT NULL,
    content         TEXT         NOT NULL,
    tool_calls      JSONB        DEFAULT '[]',   -- function calls made by AI
    tool_results    JSONB        DEFAULT '[]',   -- results from external APIs

    tokens_used     INT,
    model           VARCHAR(50),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ai_conv_route_id  ON ai_conversations(route_id);
CREATE INDEX idx_ai_conv_user_id   ON ai_conversations(user_id);
CREATE INDEX idx_ai_conv_survey_id ON ai_conversations(survey_id);

-- ============================================================
-- PLACES CACHE
-- Cache for Google Places / Amadeus results to avoid repeat API calls.
-- ============================================================

CREATE TABLE places_cache (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source          VARCHAR(30)  NOT NULL,    -- 'google_places' | 'amadeus_hotel'
    external_id     VARCHAR(100) NOT NULL,
    name            VARCHAR(255),
    category        VARCHAR(100),
    city            VARCHAR(100),
    country_code    VARCHAR(3),
    latitude        DOUBLE PRECISION,
    longitude       DOUBLE PRECISION,
    rating          FLOAT,
    price_level     INT,                      -- 1-4 (Google scale)
    image_url       TEXT,
    raw_data        JSONB        DEFAULT '{}',
    cached_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW() + INTERVAL '7 days',

    UNIQUE (source, external_id)
);

CREATE INDEX idx_places_cache_source    ON places_cache(source, external_id);
CREATE INDEX idx_places_cache_city      ON places_cache(city, country_code);
CREATE INDEX idx_places_cache_expires   ON places_cache(expires_at);

-- ============================================================
-- DEVICE TOKENS
-- APNs device tokens per user (multiple devices supported).
-- ============================================================

CREATE TABLE device_tokens (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token       TEXT NOT NULL UNIQUE,
    platform    VARCHAR(10) NOT NULL DEFAULT 'ios',
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_device_tokens_user_id ON device_tokens(user_id);
CREATE INDEX idx_device_tokens_active  ON device_tokens(user_id) WHERE is_active = TRUE;

-- ============================================================
-- TRIGGER: updated_at auto-maintenance
-- ============================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_routes_updated_at
    BEFORE UPDATE ON routes
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_route_events_updated_at
    BEFORE UPDATE ON route_events
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_bookings_updated_at
    BEFORE UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_device_tokens_updated_at
    BEFORE UPDATE ON device_tokens
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_user_preferences_updated_at
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
