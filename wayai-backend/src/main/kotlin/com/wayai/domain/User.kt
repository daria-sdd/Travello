package com.wayai.domain

import java.time.Instant
import java.util.UUID

// ============================================================
// USER
// ============================================================

data class User(
    val id: UUID = UUID.randomUUID(),
    val firebaseUid: String,
    val email: String?,
    val displayName: String?,
    val avatarUrl: String?,
    val locale: String = "ru",
    val currency: String = "USD",
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
)

data class UserPreferences(
    val userId: UUID,
    val preferredTags: List<String> = emptyList(),
    val budgetTier: BudgetTier = BudgetTier.MEDIUM,
    val preferredAirlines: List<String> = emptyList(),
    val seatClass: SeatClass = SeatClass.ECONOMY,
    val dietaryNotes: String? = null,
    val accessibilityNotes: String? = null,
    val updatedAt: Instant = Instant.now(),
)

enum class BudgetTier { BUDGET, MEDIUM, LUXURY }
enum class SeatClass  { ECONOMY, BUSINESS, FIRST }
