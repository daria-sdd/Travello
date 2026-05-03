package com.wayai.domain

import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

// ============================================================
// SURVEY
// What the user filled in (or left blank for AI to decide).
// ============================================================

data class Survey(
    val id: UUID = UUID.randomUUID(),
    val userId: UUID,
    val status: SurveyStatus = SurveyStatus.PENDING,

    // Departure
    val departFrom: String? = null,          // null = AI picks cheapest hub

    // Dates — both null = AI picks best season
    val dateFrom: LocalDate? = null,
    val dateTo: LocalDate? = null,
    val flexibleDates: Boolean = false,

    // Destinations — empty list = AI picks destination from scratch
    val destinations: List<SurveyDestination> = emptyList(),

    // Budget
    val budgetAmount: BigDecimal? = null,    // null = AI assumes medium budget
    val budgetCurrency: String = "USD",
    val budgetIncludes: List<BudgetItem> = listOf(BudgetItem.FLIGHTS, BudgetItem.ACCOMMODATION),

    // Preferences
    val tags: List<String> = emptyList(),    // e.g. ["beach", "history", "food"]
    val extraWishes: String? = null,
    val travellerCount: Int = 1,
    val travellerNotes: String? = null,      // "2 adults, 1 child 5yo"

    val createdAt: Instant = Instant.now(),
    val processingStartedAt: Instant? = null,
    val processingFinishedAt: Instant? = null,
    val errorMessage: String? = null,
)

data class SurveyDestination(
    val name: String,                        // "Turkey", "Istanbul", "Europe"
    val type: DestinationType,
    val order: Int,
)

enum class DestinationType { COUNTRY, CITY, REGION, ANY }

enum class SurveyStatus {
    PENDING,      // submitted, waiting for Kafka consumer
    PROCESSING,   // AI is working on it
    COMPLETED,    // route variants ready
    FAILED        // AI or API error
}

enum class BudgetItem { FLIGHTS, ACCOMMODATION, FOOD, ACTIVITIES }
