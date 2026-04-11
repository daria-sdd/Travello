package com.wayai.infrastructure.ai

import com.wayai.domain.*
import org.springframework.stereotype.Component
import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.UUID

// ============================================================
// AI RESPONSE MAPPER
// Converts Claude's structured JSON output → domain objects.
// Single responsibility: translation between AI world and domain.
// ============================================================

@Component
class AiResponseMapper {

    // ----------------------------------------------------------
    // AiRouteVariant → Route (full domain object)
    // ----------------------------------------------------------

    fun toRoute(variant: AiRouteVariant, survey: Survey): Route {
        val routeId = UUID.randomUUID()

        val days = variant.days.mapIndexed { _, aiDay ->
            val dayId = UUID.randomUUID()
            RouteDay(
                id          = dayId,
                routeId     = routeId,
                dayNumber   = aiDay.dayNumber,
                date        = aiDay.date?.let { LocalDate.parse(it) },
                city        = aiDay.city,
                country     = aiDay.country,
                countryCode = aiDay.countryCode,
                summary     = aiDay.daySummary,
                weatherNote = aiDay.weatherNote,
                events      = aiDay.events.map { aiEvent ->
                    toRouteEvent(aiEvent, dayId, routeId)
                },
            )
        }

        return Route(
            id            = routeId,
            surveyId      = survey.id,
            userId        = survey.userId,
            status        = RouteStatus.DRAFT,
            title         = variant.title,
            summary       = variant.summary,
            coverImageUrl = days.firstOrNull()?.events
                ?.firstOrNull { it.imageUrl != null }?.imageUrl,
            totalDays     = variant.totalDays,
            totalCostEst  = variant.totalCostEst.toBigDecimal(),
            currency      = variant.currency,
            days          = days,
            variantIndex  = variant.variantIndex,
            variantLabel  = variant.variantLabel,
        )
    }

    // ----------------------------------------------------------
    // AiRouteEvent → RouteEvent
    // ----------------------------------------------------------

    private fun toRouteEvent(aiEvent: AiRouteEvent, dayId: UUID, routeId: UUID): RouteEvent {
        val eventType = when (aiEvent.eventType.uppercase()) {
            "FLIGHT"        -> EventType.FLIGHT
            "ACCOMMODATION" -> EventType.ACCOMMODATION
            "TRANSPORT"     -> EventType.TRANSPORT
            "ACTIVITY"      -> EventType.ACTIVITY
            "RESTAURANT"    -> EventType.RESTAURANT
            "NOTE"          -> EventType.NOTE
            else            -> EventType.FREE_TIME
        }

        // Determine external source from event type + available IDs
        val (externalId, externalSource) = when {
            aiEvent.amadeusOfferId != null ->
                Pair(aiEvent.amadeusOfferId, ExternalSource.AMADEUS)
            aiEvent.hotelId != null ->
                Pair(aiEvent.hotelId, ExternalSource.AMADEUS)
            aiEvent.googlePlaceId != null ->
                Pair(aiEvent.googlePlaceId, ExternalSource.GOOGLE_PLACES)
            else -> Pair(null, null)
        }

        return RouteEvent(
            id             = UUID.randomUUID(),
            routeDayId     = dayId,
            routeId        = routeId,
            eventType      = eventType,
            sortOrder      = aiEvent.sortOrder,
            startsAt       = aiEvent.startsAt?.parseToInstant(),
            endsAt         = aiEvent.endsAt?.parseToInstant(),
            durationMin    = aiEvent.durationMin,
            title          = aiEvent.title,
            description    = aiEvent.description,
            locationName   = aiEvent.locationName,
            address        = aiEvent.address,
            latitude       = aiEvent.latitude,
            longitude      = aiEvent.longitude,
            googlePlaceId  = aiEvent.googlePlaceId,
            imageUrl       = aiEvent.imageUrl,
            costEst        = aiEvent.costEst?.toBigDecimal(),
            currency       = aiEvent.currency ?: "USD",
            isPrepaid      = aiEvent.isPrepaid,
            externalId     = externalId,
            externalSource = externalSource,
            aiTip          = aiEvent.aiTip,
            aiConfidence   = aiEvent.aiConfidence,
        )
    }

    // ----------------------------------------------------------
    // Apply edit: merge updated days into existing Route
    // ----------------------------------------------------------

    fun applyEditToRoute(route: Route, edit: RouteEditResponse): Route {
        val updatedDays = edit.updatedDays.map { aiDay ->
            val dayId = route.days
                .find { it.dayNumber == aiDay.dayNumber }?.id
                ?: UUID.randomUUID()

            RouteDay(
                id          = dayId,
                routeId     = route.id,
                dayNumber   = aiDay.dayNumber,
                date        = aiDay.date?.let { LocalDate.parse(it) },
                city        = aiDay.city,
                country     = aiDay.country,
                countryCode = aiDay.countryCode,
                summary     = aiDay.daySummary,
                weatherNote = aiDay.weatherNote,
                events      = aiDay.events.map { aiEvent ->
                    toRouteEvent(aiEvent, dayId, route.id)
                },
            )
        }

        return route.copy(
            days         = updatedDays,
            totalCostEst = edit.totalCostEst.toBigDecimal(),
            updatedAt    = Instant.now(),
        )
    }

    // ----------------------------------------------------------
    // Build a compact text summary of the route for the edit prompt.
    // Claude uses this to understand the current state of the plan.
    // ----------------------------------------------------------

    fun buildPlanSummary(route: Route): String {
        val sb = StringBuilder()
        sb.appendLine("Title: ${route.title}")
        sb.appendLine("Total cost: \$${route.totalCostEst} ${route.currency}")
        sb.appendLine()

        route.days.forEach { day ->
            sb.appendLine("Day ${day.dayNumber} — ${day.date ?: "TBD"}: ${day.city}, ${day.country}")
            sb.appendLine("  Summary: ${day.summary}")
            day.events.forEach { event ->
                val cost = event.costEst?.let { " (\$$it)" } ?: ""
                val time = event.startsAt?.let {
                    " at ${it.atZone(ZoneOffset.UTC).toLocalTime()}"
                } ?: ""
                sb.appendLine("  - [${event.eventType.name}]$time ${event.title}$cost")
                event.aiTip?.let { sb.appendLine("    Tip: $it") }
            }
            sb.appendLine()
        }

        return sb.toString()
    }

    // ----------------------------------------------------------
    // HELPERS
    // ----------------------------------------------------------

    private fun String.parseToInstant(): Instant? = runCatching {
        when {
            // Full ISO datetime: "2024-10-15T09:00:00Z"
            contains("T") -> Instant.parse(this)
            // Time only: "09:00" — can't determine date here, skip
            matches(Regex("\\d{2}:\\d{2}")) -> null
            // Date only: "2024-10-15"
            else -> LocalDate.parse(this).atStartOfDay().toInstant(ZoneOffset.UTC)
        }
    }.getOrNull()
}
