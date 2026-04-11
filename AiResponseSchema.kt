package com.wayai.infrastructure.ai

import com.fasterxml.jackson.annotation.JsonProperty

// ============================================================
// AI RESPONSE SCHEMAS
// Claude is instructed to return JSON matching these classes.
// Jackson deserializes the response into these objects,
// which are then mapped to domain models.
// ============================================================

// ----------------------------------------------------------
// Route Generation Response
// Claude returns this after processing a survey.
// ----------------------------------------------------------

data class RouteGenerationResponse(
    @JsonProperty("variants")
    val variants: List<AiRouteVariant>,

    @JsonProperty("generation_notes")
    val generationNotes: String?,           // e.g. "Dates shifted 3 days for cheaper flights"
)

data class AiRouteVariant(
    @JsonProperty("variant_index")
    val variantIndex: Int,                  // 0, 1, 2

    @JsonProperty("variant_label")
    val variantLabel: String,               // "Budget", "Balanced", "Premium"

    @JsonProperty("title")
    val title: String,                      // "Осенняя Турция: Фетхие + Стамбул"

    @JsonProperty("summary")
    val summary: String,                    // 2-3 sentence description

    @JsonProperty("total_days")
    val totalDays: Int,

    @JsonProperty("total_cost_est")
    val totalCostEst: Double,

    @JsonProperty("currency")
    val currency: String,

    @JsonProperty("cost_breakdown")
    val costBreakdown: AiCostBreakdown,

    @JsonProperty("why_this_variant")
    val whyThisVariant: String,             // "Best for travellers who want comfort without splurging"

    @JsonProperty("days")
    val days: List<AiRouteDay>,
)

data class AiCostBreakdown(
    @JsonProperty("flights")
    val flights: Double,

    @JsonProperty("accommodation")
    val accommodation: Double,

    @JsonProperty("activities")
    val activities: Double,

    @JsonProperty("food")
    val food: Double,

    @JsonProperty("transport_local")
    val transportLocal: Double,

    @JsonProperty("other")
    val other: Double,
)

data class AiRouteDay(
    @JsonProperty("day_number")
    val dayNumber: Int,

    @JsonProperty("date")
    val date: String?,                      // YYYY-MM-DD

    @JsonProperty("city")
    val city: String,

    @JsonProperty("country")
    val country: String,

    @JsonProperty("country_code")
    val countryCode: String,

    @JsonProperty("day_summary")
    val daySummary: String,                 // "Arrival day: flight, check-in, evening stroll"

    @JsonProperty("weather_note")
    val weatherNote: String?,               // "24°C, sunny. Perfect for outdoor activities."

    @JsonProperty("events")
    val events: List<AiRouteEvent>,
)

data class AiRouteEvent(
    @JsonProperty("event_type")
    val eventType: String,                  // flight | accommodation | transport | activity | restaurant | note

    @JsonProperty("sort_order")
    val sortOrder: Int,

    @JsonProperty("title")
    val title: String,

    @JsonProperty("description")
    val description: String?,

    @JsonProperty("starts_at")
    val startsAt: String?,                  // ISO 8601 datetime or HH:mm

    @JsonProperty("ends_at")
    val endsAt: String?,

    @JsonProperty("duration_min")
    val durationMin: Int?,

    @JsonProperty("location_name")
    val locationName: String?,

    @JsonProperty("address")
    val address: String?,

    @JsonProperty("latitude")
    val latitude: Double?,

    @JsonProperty("longitude")
    val longitude: Double?,

    @JsonProperty("google_place_id")
    val googlePlaceId: String?,

    @JsonProperty("image_url")
    val imageUrl: String?,

    @JsonProperty("cost_est")
    val costEst: Double?,

    @JsonProperty("currency")
    val currency: String?,

    @JsonProperty("is_prepaid")
    val isPrepaid: Boolean = false,

    // Flight-specific
    @JsonProperty("flight_number")
    val flightNumber: String?,

    @JsonProperty("airline")
    val airline: String?,

    @JsonProperty("amadeus_offer_id")
    val amadeusOfferId: String?,

    // Hotel-specific
    @JsonProperty("hotel_id")
    val hotelId: String?,

    @JsonProperty("hotel_stars")
    val hotelStars: Int?,

    @JsonProperty("nights")
    val nights: Int?,

    @JsonProperty("breakfast_included")
    val breakfastIncluded: Boolean?,

    // AI tip for this specific event
    @JsonProperty("ai_tip")
    val aiTip: String?,

    @JsonProperty("ai_confidence")
    val aiConfidence: Float?,
)

// ----------------------------------------------------------
// Route Edit Response
// Claude returns this after a user requests a change.
// ----------------------------------------------------------

data class RouteEditResponse(
    @JsonProperty("updated_days")
    val updatedDays: List<AiRouteDay>,      // all days, modified as needed

    @JsonProperty("total_cost_est")
    val totalCostEst: Double,

    @JsonProperty("change_summary")
    val changeSummary: String,              // "Replaced the hotel with Melas Resort (−$45/night)"

    @JsonProperty("generation_notes")
    val generationNotes: String?,
)
