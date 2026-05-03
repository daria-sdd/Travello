package com.wayai.domain

import java.math.BigDecimal
import java.time.Instant
import java.util.UUID

// ============================================================
// BOOKING
// A confirmed reservation tied to a RouteEvent.
// ============================================================

data class Booking(
    val id: UUID = UUID.randomUUID(),
    val userId: UUID,
    val routeEventId: UUID?,
    val status: BookingStatus = BookingStatus.PENDING,

    val bookingRef: String?,               // PNR / confirmation number
    val providerName: String?,             // "Turkish Airlines"
    val providerLogo: String?,
    val bookingUrl: String?,

    val bookedAt: Instant? = null,
    val validFrom: Instant? = null,
    val validTo: Instant? = null,

    val amountPaid: BigDecimal? = null,
    val currency: String = "USD",

    val qrCodeUrl: String? = null,
    val ticketPdfUrl: String? = null,
    val rawData: Map<String, Any?> = emptyMap(),

    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
)

enum class BookingStatus { PENDING, CONFIRMED, CANCELLED, COMPLETED }

// ============================================================
// NOTIFICATION
// Scheduled smart notification (AI-driven).
// ============================================================

data class Notification(
    val id: UUID = UUID.randomUUID(),
    val userId: UUID,
    val routeId: UUID?,
    val type: NotificationType,

    val title: String,
    val body: String,
    val deepLink: String?,                 // e.g. "wayai://route/123"

    val scheduledAt: Instant,
    val sentAt: Instant? = null,
    val readAt: Instant? = null,
    val isSent: Boolean = false,
    val isRead: Boolean = false,

    val apnsId: String? = null,
    val deviceToken: String? = null,

    val createdAt: Instant = Instant.now(),
)

enum class NotificationType {
    CHECKIN_REMINDER,      // online check-in 24h before flight
    DEPART_REMINDER,       // leave for airport
    DAILY_TIP,             // AI tip of the day
    WEATHER_ALERT,         // weather changed
    BOOKING_EXPIRY,        // fare about to expire
    ROUTE_READY,           // AI finished generating plan
    CUSTOM,
}

// ============================================================
// AI CONVERSATION LOG
// Full message history for a route (used for NLP edits).
// ============================================================

data class AiMessage(
    val id: UUID = UUID.randomUUID(),
    val userId: UUID,
    val routeId: UUID?,
    val surveyId: UUID?,
    val role: AiRole,
    val content: String,
    val toolCalls: List<AiToolCall> = emptyList(),
    val toolResults: List<AiToolResult> = emptyList(),
    val tokensUsed: Int? = null,
    val model: String? = null,
    val createdAt: Instant = Instant.now(),
)

enum class AiRole { USER, ASSISTANT, TOOL_RESULT }

data class AiToolCall(
    val toolName: String,
    val input: Map<String, Any?>,
)

data class AiToolResult(
    val toolName: String,
    val output: Map<String, Any?>,
    val isError: Boolean = false,
)

// ============================================================
// DEVICE TOKEN
// APNs push token (multiple devices per user).
// ============================================================

data class DeviceToken(
    val id: UUID = UUID.randomUUID(),
    val userId: UUID,
    val token: String,
    val platform: String = "ios",
    val isActive: Boolean = true,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
)
