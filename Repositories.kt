package com.wayai.infrastructure.db

import com.wayai.domain.*
import java.util.UUID

// ============================================================
// Repository interfaces (ports in hexagonal architecture).
// Implementations live in infrastructure/db/impl/.
// ============================================================

interface UserRepository {
    suspend fun findById(id: UUID): User?
    suspend fun findByFirebaseUid(uid: String): User?
    suspend fun findByEmail(email: String): User?
    suspend fun save(user: User): User
    suspend fun update(user: User): User
    suspend fun getPreferences(userId: UUID): UserPreferences?
    suspend fun savePreferences(prefs: UserPreferences): UserPreferences
}

interface SurveyRepository {
    suspend fun findById(id: UUID): Survey?
    suspend fun findByUserId(userId: UUID): List<Survey>
    suspend fun save(survey: Survey): Survey
    suspend fun updateStatus(
        id: UUID,
        status: SurveyStatus,
        errorMessage: String? = null,
    ): Survey
}

interface RouteRepository {
    suspend fun findById(id: UUID): Route?
    suspend fun findByUserId(userId: UUID): List<Route>
    suspend fun findBySurveyId(surveyId: UUID): List<Route>
    suspend fun findActiveByUserId(userId: UUID): Route?
    suspend fun save(route: Route): Route
    suspend fun update(route: Route): Route
    suspend fun confirm(id: UUID): Route
    suspend fun archive(id: UUID): Route
}

interface BookingRepository {
    suspend fun findById(id: UUID): Booking?
    suspend fun findByUserId(userId: UUID): List<Booking>
    suspend fun findByRouteEventId(eventId: UUID): Booking?
    suspend fun save(booking: Booking): Booking
    suspend fun update(booking: Booking): Booking
}

interface NotificationRepository {
    suspend fun findPendingToSend(): List<Notification>
    suspend fun findByUserId(userId: UUID): List<Notification>
    suspend fun save(notification: Notification): Notification
    suspend fun markSent(id: UUID, apnsId: String): Notification
    suspend fun markRead(id: UUID): Notification
}

interface AiConversationRepository {
    suspend fun findByRouteId(routeId: UUID): List<AiMessage>
    suspend fun findBySurveyId(surveyId: UUID): List<AiMessage>
    suspend fun save(message: AiMessage): AiMessage
    suspend fun saveAll(messages: List<AiMessage>): List<AiMessage>
}

interface DeviceTokenRepository {
    suspend fun findActiveByUserId(userId: UUID): List<DeviceToken>
    suspend fun save(token: DeviceToken): DeviceToken
    suspend fun deactivate(token: String)
    suspend fun deactivateAllForUser(userId: UUID)
}
