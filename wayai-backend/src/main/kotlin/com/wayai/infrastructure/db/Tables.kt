package com.wayai.infrastructure.db

import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.javatime.timestamp
import org.jetbrains.exposed.sql.javatime.date

// ============================================================
// Exposed DSL Table definitions
// Using Exposed (JetBrains ORM for Kotlin) — works great with
// coroutines via newSuspendedTransaction { }
// ============================================================

object UsersTable : Table("users") {
    val id          = uuid("id").autoGenerate()
    val firebaseUid = varchar("firebase_uid", 128).uniqueIndex()
    val email       = varchar("email", 255).uniqueIndex().nullable()
    val displayName = varchar("display_name", 100).nullable()
    val avatarUrl   = text("avatar_url").nullable()
    val locale      = varchar("locale", 10).default("ru")
    val currency    = varchar("currency", 3).default("USD")
    val createdAt   = timestamp("created_at")
    val updatedAt   = timestamp("updated_at")
    override val primaryKey = PrimaryKey(id)
}

object UserPreferencesTable : Table("user_preferences") {
    val userId             = uuid("user_id").references(UsersTable.id)
    val preferredTags      = array<String>("preferred_tags").default(emptyList())
    val budgetTier         = varchar("budget_tier", 20).default("medium")
    val preferredAirlines  = array<String>("preferred_airlines").default(emptyList())
    val seatClass          = varchar("seat_class", 10).default("economy")
    val dietaryNotes       = text("dietary_notes").nullable()
    val accessibilityNotes = text("accessibility_notes").nullable()
    val updatedAt          = timestamp("updated_at")
    override val primaryKey = PrimaryKey(userId)
}

object SurveysTable : Table("surveys") {
    val id                    = uuid("id").autoGenerate()
    val userId                = uuid("user_id").references(UsersTable.id)
    val status                = varchar("status", 20).default("pending")
    val departFrom            = varchar("depart_from", 100).nullable()
    val dateFrom              = date("date_from").nullable()
    val dateTo                = date("date_to").nullable()
    val flexibleDates         = bool("flexible_dates").default(false)
    val destinations          = jsonb("destinations").default("[]")
    val budgetAmount          = decimal("budget_amount", 12, 2).nullable()
    val budgetCurrency        = varchar("budget_currency", 3).default("USD")
    val budgetIncludes        = array<String>("budget_includes").default(emptyList())
    val tags                  = array<String>("tags").default(emptyList())
    val extraWishes           = text("extra_wishes").nullable()
    val travellerCount        = integer("traveller_count").default(1)
    val travellerNotes        = text("traveller_notes").nullable()
    val createdAt             = timestamp("created_at")
    val processingStartedAt   = timestamp("processing_started_at").nullable()
    val processingFinishedAt  = timestamp("processing_finished_at").nullable()
    val errorMessage          = text("error_message").nullable()
    override val primaryKey   = PrimaryKey(id)
}

object RoutesTable : Table("routes") {
    val id             = uuid("id").autoGenerate()
    val surveyId       = uuid("survey_id").references(SurveysTable.id)
    val userId         = uuid("user_id").references(UsersTable.id)
    val status         = varchar("status", 20).default("draft")
    val title          = varchar("title", 255).nullable()
    val summary        = text("summary").nullable()
    val coverImageUrl  = text("cover_image_url").nullable()
    val totalDays      = integer("total_days").nullable()
    val totalCostEst   = decimal("total_cost_est", 12, 2).nullable()
    val currency       = varchar("currency", 3).default("USD")
    val planRaw        = jsonb("plan_raw").default("{}")
    val variantIndex   = integer("variant_index").default(0)
    val variantLabel   = varchar("variant_label", 50).nullable()
    val confirmedAt    = timestamp("confirmed_at").nullable()
    val createdAt      = timestamp("created_at")
    val updatedAt      = timestamp("updated_at")
    override val primaryKey = PrimaryKey(id)
}

object RouteDaysTable : Table("route_days") {
    val id          = uuid("id").autoGenerate()
    val routeId     = uuid("route_id").references(RoutesTable.id)
    val dayNumber   = integer("day_number")
    val date        = date("date").nullable()
    val city        = varchar("city", 100).nullable()
    val country     = varchar("country", 100).nullable()
    val countryCode = varchar("country_code", 3).nullable()
    val summary     = text("summary").nullable()
    val weatherNote = text("weather_note").nullable()
    override val primaryKey = PrimaryKey(id)
}

object RouteEventsTable : Table("route_events") {
    val id             = uuid("id").autoGenerate()
    val routeDayId     = uuid("route_day_id").references(RouteDaysTable.id)
    val routeId        = uuid("route_id").references(RoutesTable.id)
    val eventType      = enumerationByName("event_type", 20, com.wayai.domain.EventType::class)
    val sortOrder      = integer("sort_order").default(0)
    val startsAt       = timestamp("starts_at").nullable()
    val endsAt         = timestamp("ends_at").nullable()
    val durationMin    = integer("duration_min").nullable()
    val title          = varchar("title", 255).nullable()
    val description    = text("description").nullable()
    val locationName   = varchar("location_name", 255).nullable()
    val address        = text("address").nullable()
    val city           = varchar("city", 100).nullable()
    val countryCode    = varchar("country_code", 3).nullable()
    val latitude       = double("latitude").nullable()
    val longitude      = double("longitude").nullable()
    val googlePlaceId  = varchar("google_place_id", 100).nullable()
    val imageUrl       = text("image_url").nullable()
    val costEst        = decimal("cost_est", 10, 2).nullable()
    val currency       = varchar("currency", 3).default("USD")
    val isPrepaid      = bool("is_prepaid").default(false)
    val externalId     = varchar("external_id", 255).nullable()
    val externalSource = varchar("external_source", 50).nullable()
    val bookingRef     = varchar("booking_ref", 100).nullable()
    val aiTip          = text("ai_tip").nullable()
    val aiConfidence   = float("ai_confidence").nullable()
    val createdAt      = timestamp("created_at")
    val updatedAt      = timestamp("updated_at")
    override val primaryKey = PrimaryKey(id)
}

object BookingsTable : Table("bookings") {
    val id            = uuid("id").autoGenerate()
    val userId        = uuid("user_id").references(UsersTable.id)
    val routeEventId  = uuid("route_event_id").references(RouteEventsTable.id).nullable()
    val status        = varchar("status", 20).default("pending")
    val bookingRef    = varchar("booking_ref", 100).nullable()
    val providerName  = varchar("provider_name", 100).nullable()
    val providerLogo  = text("provider_logo").nullable()
    val bookingUrl    = text("booking_url").nullable()
    val bookedAt      = timestamp("booked_at").nullable()
    val validFrom     = timestamp("valid_from").nullable()
    val validTo       = timestamp("valid_to").nullable()
    val amountPaid    = decimal("amount_paid", 10, 2).nullable()
    val currency      = varchar("currency", 3).default("USD")
    val qrCodeUrl     = text("qr_code_url").nullable()
    val ticketPdfUrl  = text("ticket_pdf_url").nullable()
    val rawData       = jsonb("raw_data").default("{}")
    val createdAt     = timestamp("created_at")
    val updatedAt     = timestamp("updated_at")
    override val primaryKey = PrimaryKey(id)
}

object NotificationsTable : Table("notifications") {
    val id           = uuid("id").autoGenerate()
    val userId       = uuid("user_id").references(UsersTable.id)
    val routeId      = uuid("route_id").references(RoutesTable.id).nullable()
    val type         = varchar("type", 30)
    val title        = varchar("title", 255)
    val body         = text("body")
    val deepLink     = varchar("deep_link", 255).nullable()
    val scheduledAt  = timestamp("scheduled_at")
    val sentAt       = timestamp("sent_at").nullable()
    val readAt       = timestamp("read_at").nullable()
    val isSent       = bool("is_sent").default(false)
    val isRead       = bool("is_read").default(false)
    val apnsId       = varchar("apns_id", 255).nullable()
    val deviceToken  = text("device_token").nullable()
    val createdAt    = timestamp("created_at")
    override val primaryKey = PrimaryKey(id)
}

object AiConversationsTable : Table("ai_conversations") {
    val id          = uuid("id").autoGenerate()
    val userId      = uuid("user_id").references(UsersTable.id)
    val routeId     = uuid("route_id").references(RoutesTable.id).nullable()
    val surveyId    = uuid("survey_id").references(SurveysTable.id).nullable()
    val role        = varchar("role", 20)
    val content     = text("content")
    val toolCalls   = jsonb("tool_calls").default("[]")
    val toolResults = jsonb("tool_results").default("[]")
    val tokensUsed  = integer("tokens_used").nullable()
    val model       = varchar("model", 50).nullable()
    val createdAt   = timestamp("created_at")
    override val primaryKey = PrimaryKey(id)
}

object DeviceTokensTable : Table("device_tokens") {
    val id        = uuid("id").autoGenerate()
    val userId    = uuid("user_id").references(UsersTable.id)
    val token     = text("token").uniqueIndex()
    val platform  = varchar("platform", 10).default("ios")
    val isActive  = bool("is_active").default(true)
    val createdAt = timestamp("created_at")
    val updatedAt = timestamp("updated_at")
    override val primaryKey = PrimaryKey(id)
}
