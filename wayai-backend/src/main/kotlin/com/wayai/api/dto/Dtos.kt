package com.wayai.api.dto

import com.wayai.domain.*
import jakarta.validation.Valid
import jakarta.validation.constraints.*
import java.math.BigDecimal
import java.time.LocalDate
import java.util.UUID

// ============================================================
// SURVEY REQUEST
// JSON который приходит с iOS после заполнения опросника.
// Все поля nullable — AI додумает пустые.
// ============================================================

data class SurveyRequest(
    // Откуда летит (город или аэропорт)
    val departFrom: String?,

    // Даты — оба null = AI выбирает лучший момент
    @field:FutureOrPresent val dateFrom: LocalDate?,
    @field:FutureOrPresent val dateTo: LocalDate?,
    val flexibleDates: Boolean = false,

    // Направления в выбранном порядке
    val destinations: List<DestinationRequest> = emptyList(),

    // Бюджет
    @field:DecimalMin("0") val budgetAmount: BigDecimal?,
    val budgetCurrency: String = "USD",
    val budgetIncludes: List<String> = listOf("flights", "accommodation"),

    // Предпочтения
    val tags: List<String> = emptyList(),
    val extraWishes: String?,

    @field:Min(1) @field:Max(20)
    val travellerCount: Int = 1,
    val travellerNotes: String?,
) {
    fun toDomain(userId: UUID) = Survey(
        userId         = userId,
        departFrom     = departFrom?.trim(),
        dateFrom       = dateFrom,
        dateTo         = dateTo,
        flexibleDates  = flexibleDates,
        destinations   = destinations.mapIndexed { i, d ->
            SurveyDestination(
                name  = d.name.trim(),
                type  = runCatching { DestinationType.valueOf(d.type.uppercase()) }
                    .getOrDefault(DestinationType.ANY),
                order = i,
            )
        },
        budgetAmount   = budgetAmount,
        budgetCurrency = budgetCurrency.uppercase(),
        budgetIncludes = budgetIncludes.mapNotNull {
            runCatching { BudgetItem.valueOf(it.uppercase()) }.getOrNull()
        },
        tags           = tags.map { it.lowercase().trim() },
        extraWishes    = extraWishes?.trim(),
        travellerCount = travellerCount,
        travellerNotes = travellerNotes?.trim(),
    )
}

data class DestinationRequest(
    @field:NotBlank val name: String,
    val type: String = "any",          // country | city | region | any
)

// ============================================================
// SURVEY RESPONSE
// ============================================================

data class SurveyResponse(
    val id: UUID,
    val status: String,
    val createdAt: String,
) {
    companion object {
        fun from(survey: Survey) = SurveyResponse(
            id        = survey.id,
            status    = survey.status.name.lowercase(),
            createdAt = survey.createdAt.toString(),
        )
    }
}

// ============================================================
// ROUTE RESPONSE
// Полный маршрут для отображения на клиенте.
// ============================================================

data class RouteResponse(
    val id: UUID,
    val surveyId: UUID,
    val status: String,
    val variantIndex: Int,
    val variantLabel: String?,
    val title: String?,
    val summary: String?,
    val coverImageUrl: String?,
    val totalDays: Int?,
    val totalCostEst: Double?,
    val currency: String,
    val days: List<RouteDayResponse>,
    val confirmedAt: String?,
    val createdAt: String,
) {
    companion object {
        fun from(route: Route) = RouteResponse(
            id            = route.id,
            surveyId      = route.surveyId,
            status        = route.status.name.lowercase(),
            variantIndex  = route.variantIndex,
            variantLabel  = route.variantLabel,
            title         = route.title,
            summary       = route.summary,
            coverImageUrl = route.coverImageUrl,
            totalDays     = route.totalDays,
            totalCostEst  = route.totalCostEst?.toDouble(),
            currency      = route.currency,
            days          = route.days.map { RouteDayResponse.from(it) },
            confirmedAt   = route.confirmedAt?.toString(),
            createdAt     = route.createdAt.toString(),
        )
    }
}

data class RouteDayResponse(
    val id: UUID,
    val dayNumber: Int,
    val date: String?,
    val city: String?,
    val country: String?,
    val countryCode: String?,
    val summary: String?,
    val weatherNote: String?,
    val events: List<RouteEventResponse>,
) {
    companion object {
        fun from(day: RouteDay) = RouteDayResponse(
            id          = day.id,
            dayNumber   = day.dayNumber,
            date        = day.date?.toString(),
            city        = day.city,
            country     = day.country,
            countryCode = day.countryCode,
            summary     = day.summary,
            weatherNote = day.weatherNote,
            events      = day.events.sortedBy { it.sortOrder }.map { RouteEventResponse.from(it) },
        )
    }
}

data class RouteEventResponse(
    val id: UUID,
    val eventType: String,
    val sortOrder: Int,
    val title: String?,
    val description: String?,
    val startsAt: String?,
    val endsAt: String?,
    val durationMin: Int?,
    val locationName: String?,
    val address: String?,
    val latitude: Double?,
    val longitude: Double?,
    val imageUrl: String?,
    val costEst: Double?,
    val currency: String,
    val isPrepaid: Boolean,
    val bookingRef: String?,
    val externalSource: String?,
    val aiTip: String?,
) {
    companion object {
        fun from(event: RouteEvent) = RouteEventResponse(
            id             = event.id,
            eventType      = event.eventType.name.lowercase(),
            sortOrder      = event.sortOrder,
            title          = event.title,
            description    = event.description,
            startsAt       = event.startsAt?.toString(),
            endsAt         = event.endsAt?.toString(),
            durationMin    = event.durationMin,
            locationName   = event.locationName,
            address        = event.address,
            latitude       = event.latitude,
            longitude      = event.longitude,
            imageUrl       = event.imageUrl,
            costEst        = event.costEst?.toDouble(),
            currency       = event.currency,
            isPrepaid      = event.isPrepaid,
            bookingRef     = event.bookingRef,
            externalSource = event.externalSource?.name?.lowercase(),
            aiTip          = event.aiTip,
        )
    }
}

// ============================================================
// ROUTE EDIT REQUEST
// Пользователь вводит текстом что хочет изменить.
// ============================================================

data class RouteEditRequest(
    @field:NotBlank
    @field:Size(max = 500)
    val message: String,
)

data class RouteEditResponse(
    val route: RouteResponse,
    val changeSummary: String,
)

// ============================================================
// DEVICE TOKEN REQUEST
// Регистрация APNs токена при запуске приложения.
// ============================================================

data class DeviceTokenRequest(
    @field:NotBlank val token: String,
    val platform: String = "ios",
)
