package com.wayai.domain

import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

// ============================================================
// ROUTE
// A complete AI-generated travel plan.
// ============================================================

data class Route(
    val id: UUID = UUID.randomUUID(),
    val surveyId: UUID,
    val userId: UUID,
    val status: RouteStatus = RouteStatus.DRAFT,

    val title: String?,
    val summary: String?,
    val coverImageUrl: String?,

    val totalDays: Int?,
    val totalCostEst: BigDecimal?,
    val currency: String = "USD",

    // Full AI plan stored as a structured object (serialized to JSONB in DB)
    val days: List<RouteDay> = emptyList(),

    // Which variant this is (0=budget, 1=balanced, 2=premium)
    val variantIndex: Int = 0,
    val variantLabel: String? = null,

    val confirmedAt: Instant? = null,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
)

enum class RouteStatus { DRAFT, ACTIVE, COMPLETED, ARCHIVED }

// ============================================================
// ROUTE DAY
// ============================================================

data class RouteDay(
    val id: UUID = UUID.randomUUID(),
    val routeId: UUID,
    val dayNumber: Int,                  // 1-based
    val date: LocalDate?,
    val city: String?,
    val country: String?,
    val countryCode: String?,            // ISO 3166-1 alpha-2
    val summary: String?,
    val weatherNote: String?,
    val events: List<RouteEvent> = emptyList(),
)

// ============================================================
// ROUTE EVENT
// Single item in a day: flight, hotel, POI, restaurant, etc.
// ============================================================

data class RouteEvent(
    val id: UUID = UUID.randomUUID(),
    val routeDayId: UUID,
    val routeId: UUID,
    val eventType: EventType,
    val sortOrder: Int = 0,

    // Time
    val startsAt: Instant? = null,
    val endsAt: Instant? = null,
    val durationMin: Int? = null,

    // Place / Venue
    val title: String?,
    val description: String?,
    val locationName: String?,
    val address: String?,
    val city: String?,
    val countryCode: String?,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val googlePlaceId: String? = null,
    val imageUrl: String? = null,

    // Cost
    val costEst: BigDecimal? = null,
    val currency: String = "USD",
    val isPrepaid: Boolean = false,

    // External references
    val externalId: String? = null,       // Amadeus offer ID, etc.
    val externalSource: ExternalSource? = null,
    val bookingRef: String? = null,

    // AI metadata
    val aiTip: String? = null,
    val aiConfidence: Float? = null,

    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
)

enum class EventType {
    FLIGHT,
    ACCOMMODATION,
    TRANSPORT,       // train, bus, taxi, car rental
    ACTIVITY,        // sightseeing, tour, excursion
    RESTAURANT,
    FREE_TIME,
    NOTE,
}

enum class ExternalSource {
    AMADEUS,
    BOOKING_COM,
    GOOGLE_PLACES,
    VIATOR,
}
