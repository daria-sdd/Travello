package com.wayai.infrastructure.db.impl

import com.wayai.domain.*
import com.wayai.infrastructure.db.*
import kotlinx.coroutines.Dispatchers
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
import org.jetbrains.exposed.sql.transactions.experimental.newSuspendedTransaction
import java.time.Instant
import java.util.UUID

// Shorthand: run a DB operation on the IO dispatcher
private suspend fun <T> dbQuery(block: suspend Transaction.() -> T): T =
    newSuspendedTransaction(Dispatchers.IO) { block() }

// ============================================================
// USER REPOSITORY
// ============================================================

class UserRepositoryImpl : UserRepository {

    override suspend fun findById(id: UUID): User? = dbQuery {
        UsersTable.selectAll()
            .where { UsersTable.id eq id }
            .singleOrNull()
            ?.toUser()
    }

    override suspend fun findByFirebaseUid(uid: String): User? = dbQuery {
        UsersTable.selectAll()
            .where { UsersTable.firebaseUid eq uid }
            .singleOrNull()
            ?.toUser()
    }

    override suspend fun findByEmail(email: String): User? = dbQuery {
        UsersTable.selectAll()
            .where { UsersTable.email eq email }
            .singleOrNull()
            ?.toUser()
    }

    override suspend fun save(user: User): User = dbQuery {
        UsersTable.insert {
            it[id]          = user.id
            it[firebaseUid] = user.firebaseUid
            it[email]       = user.email
            it[displayName] = user.displayName
            it[avatarUrl]   = user.avatarUrl
            it[locale]      = user.locale
            it[currency]    = user.currency
            it[createdAt]   = user.createdAt
            it[updatedAt]   = user.updatedAt
        }
        user
    }

    override suspend fun update(user: User): User = dbQuery {
        UsersTable.update({ UsersTable.id eq user.id }) {
            it[displayName] = user.displayName
            it[avatarUrl]   = user.avatarUrl
            it[locale]      = user.locale
            it[currency]    = user.currency
            it[updatedAt]   = Instant.now()
        }
        user
    }

    override suspend fun getPreferences(userId: UUID): UserPreferences? = dbQuery {
        UserPreferencesTable.selectAll()
            .where { UserPreferencesTable.userId eq userId }
            .singleOrNull()
            ?.toPreferences()
    }

    override suspend fun savePreferences(prefs: UserPreferences): UserPreferences = dbQuery {
        UserPreferencesTable.upsert {
            it[userId]             = prefs.userId
            it[preferredTags]      = prefs.preferredTags
            it[budgetTier]         = prefs.budgetTier.name.lowercase()
            it[preferredAirlines]  = prefs.preferredAirlines
            it[seatClass]          = prefs.seatClass.name.lowercase()
            it[dietaryNotes]       = prefs.dietaryNotes
            it[accessibilityNotes] = prefs.accessibilityNotes
            it[updatedAt]          = Instant.now()
        }
        prefs
    }

    // ---- Row mappers ----

    private fun ResultRow.toUser() = User(
        id          = this[UsersTable.id].value,
        firebaseUid = this[UsersTable.firebaseUid],
        email       = this[UsersTable.email],
        displayName = this[UsersTable.displayName],
        avatarUrl   = this[UsersTable.avatarUrl],
        locale      = this[UsersTable.locale],
        currency    = this[UsersTable.currency],
        createdAt   = this[UsersTable.createdAt],
        updatedAt   = this[UsersTable.updatedAt],
    )

    private fun ResultRow.toPreferences() = UserPreferences(
        userId             = this[UserPreferencesTable.userId].value,
        preferredTags      = this[UserPreferencesTable.preferredTags],
        budgetTier         = BudgetTier.valueOf(this[UserPreferencesTable.budgetTier].uppercase()),
        preferredAirlines  = this[UserPreferencesTable.preferredAirlines],
        seatClass          = SeatClass.valueOf(this[UserPreferencesTable.seatClass].uppercase()),
        dietaryNotes       = this[UserPreferencesTable.dietaryNotes],
        accessibilityNotes = this[UserPreferencesTable.accessibilityNotes],
        updatedAt          = this[UserPreferencesTable.updatedAt],
    )
}

// ============================================================
// SURVEY REPOSITORY
// ============================================================

class SurveyRepositoryImpl : SurveyRepository {

    override suspend fun findById(id: UUID): Survey? = dbQuery {
        SurveysTable.selectAll()
            .where { SurveysTable.id eq id }
            .singleOrNull()
            ?.toSurvey()
    }

    override suspend fun findByUserId(userId: UUID): List<Survey> = dbQuery {
        SurveysTable.selectAll()
            .where { SurveysTable.userId eq userId }
            .orderBy(SurveysTable.createdAt, SortOrder.DESC)
            .map { it.toSurvey() }
    }

    override suspend fun save(survey: Survey): Survey = dbQuery {
        SurveysTable.insert {
            it[id]             = survey.id
            it[userId]         = survey.userId
            it[status]         = survey.status.name.lowercase()
            it[departFrom]     = survey.departFrom
            it[dateFrom]       = survey.dateFrom
            it[dateTo]         = survey.dateTo
            it[flexibleDates]  = survey.flexibleDates
            it[destinations]   = survey.destinations.toJsonb()
            it[budgetAmount]   = survey.budgetAmount
            it[budgetCurrency] = survey.budgetCurrency
            it[budgetIncludes] = survey.budgetIncludes.map { b -> b.name.lowercase() }
            it[tags]           = survey.tags
            it[extraWishes]    = survey.extraWishes
            it[travellerCount] = survey.travellerCount
            it[travellerNotes] = survey.travellerNotes
            it[createdAt]      = survey.createdAt
        }
        survey
    }

    override suspend fun updateStatus(
        id: UUID,
        status: SurveyStatus,
        errorMessage: String?,
    ): Survey = dbQuery {
        SurveysTable.update({ SurveysTable.id eq id }) {
            it[SurveysTable.status] = status.name.lowercase()
            it[SurveysTable.errorMessage] = errorMessage
            when (status) {
                SurveyStatus.PROCESSING -> it[processingStartedAt] = Instant.now()
                SurveyStatus.COMPLETED,
                SurveyStatus.FAILED     -> it[processingFinishedAt] = Instant.now()
                else -> {}
            }
        }
        findById(id)!!
    }

    private fun ResultRow.toSurvey(): Survey = Survey(
        id             = this[SurveysTable.id].value,
        userId         = this[SurveysTable.userId].value,
        status         = SurveyStatus.valueOf(this[SurveysTable.status].uppercase()),
        departFrom     = this[SurveysTable.departFrom],
        dateFrom       = this[SurveysTable.dateFrom],
        dateTo         = this[SurveysTable.dateTo],
        flexibleDates  = this[SurveysTable.flexibleDates],
        destinations   = this[SurveysTable.destinations].parseDestinations(),
        budgetAmount   = this[SurveysTable.budgetAmount],
        budgetCurrency = this[SurveysTable.budgetCurrency],
        budgetIncludes = this[SurveysTable.budgetIncludes].map { BudgetItem.valueOf(it.uppercase()) },
        tags           = this[SurveysTable.tags],
        extraWishes    = this[SurveysTable.extraWishes],
        travellerCount = this[SurveysTable.travellerCount],
        travellerNotes = this[SurveysTable.travellerNotes],
        createdAt      = this[SurveysTable.createdAt],
        processingStartedAt   = this[SurveysTable.processingStartedAt],
        processingFinishedAt  = this[SurveysTable.processingFinishedAt],
        errorMessage          = this[SurveysTable.errorMessage],
    )
}

// ============================================================
// ROUTE REPOSITORY
// ============================================================

class RouteRepositoryImpl : RouteRepository {

    override suspend fun findById(id: UUID): Route? = dbQuery {
        RoutesTable.selectAll()
            .where { RoutesTable.id eq id }
            .singleOrNull()
            ?.toRoute()
    }

    override suspend fun findByUserId(userId: UUID): List<Route> = dbQuery {
        RoutesTable.selectAll()
            .where { RoutesTable.userId eq userId }
            .orderBy(RoutesTable.createdAt, SortOrder.DESC)
            .map { it.toRoute() }
    }

    override suspend fun findBySurveyId(surveyId: UUID): List<Route> = dbQuery {
        RoutesTable.selectAll()
            .where { RoutesTable.surveyId eq surveyId }
            .orderBy(RoutesTable.variantIndex, SortOrder.ASC)
            .map { it.toRoute() }
    }

    override suspend fun findActiveByUserId(userId: UUID): Route? = dbQuery {
        RoutesTable.selectAll()
            .where {
                (RoutesTable.userId eq userId) and
                (RoutesTable.status eq "active")
            }
            .orderBy(RoutesTable.confirmedAt, SortOrder.DESC)
            .limit(1)
            .singleOrNull()
            ?.toRoute()
    }

    override suspend fun save(route: Route): Route = dbQuery {
        RoutesTable.insert {
            it[id]            = route.id
            it[surveyId]      = route.surveyId
            it[userId]        = route.userId
            it[status]        = route.status.name.lowercase()
            it[title]         = route.title
            it[summary]       = route.summary
            it[coverImageUrl] = route.coverImageUrl
            it[totalDays]     = route.totalDays
            it[totalCostEst]  = route.totalCostEst
            it[currency]      = route.currency
            it[planRaw]       = route.days.toJsonb()
            it[variantIndex]  = route.variantIndex
            it[variantLabel]  = route.variantLabel
            it[createdAt]     = route.createdAt
            it[updatedAt]     = route.updatedAt
        }
        // Save normalized days + events
        route.days.forEach { day -> saveDay(day) }
        route
    }

    override suspend fun update(route: Route): Route = dbQuery {
        RoutesTable.update({ RoutesTable.id eq route.id }) {
            it[title]         = route.title
            it[summary]       = route.summary
            it[coverImageUrl] = route.coverImageUrl
            it[totalCostEst]  = route.totalCostEst
            it[planRaw]       = route.days.toJsonb()
            it[updatedAt]     = Instant.now()
        }
        route
    }

    override suspend fun confirm(id: UUID): Route = dbQuery {
        RoutesTable.update({ RoutesTable.id eq id }) {
            it[status]      = "active"
            it[confirmedAt] = Instant.now()
            it[updatedAt]   = Instant.now()
        }
        findById(id)!!
    }

    override suspend fun archive(id: UUID): Route = dbQuery {
        RoutesTable.update({ RoutesTable.id eq id }) {
            it[status]    = "archived"
            it[updatedAt] = Instant.now()
        }
        findById(id)!!
    }

    private fun saveDay(day: RouteDay) {
        RouteDaysTable.insert {
            it[id]          = day.id
            it[routeId]     = day.routeId
            it[dayNumber]   = day.dayNumber
            it[date]        = day.date
            it[city]        = day.city
            it[country]     = day.country
            it[countryCode] = day.countryCode
            it[summary]     = day.summary
            it[weatherNote] = day.weatherNote
        }
        day.events.forEach { event -> saveEvent(event) }
    }

    private fun saveEvent(event: RouteEvent) {
        RouteEventsTable.insert {
            it[id]             = event.id
            it[routeDayId]     = event.routeDayId
            it[routeId]        = event.routeId
            it[eventType]      = event.eventType
            it[sortOrder]      = event.sortOrder
            it[startsAt]       = event.startsAt
            it[endsAt]         = event.endsAt
            it[durationMin]    = event.durationMin
            it[title]          = event.title
            it[description]    = event.description
            it[locationName]   = event.locationName
            it[address]        = event.address
            it[city]           = event.city
            it[countryCode]    = event.countryCode
            it[latitude]       = event.latitude
            it[longitude]      = event.longitude
            it[googlePlaceId]  = event.googlePlaceId
            it[imageUrl]       = event.imageUrl
            it[costEst]        = event.costEst
            it[currency]       = event.currency
            it[isPrepaid]      = event.isPrepaid
            it[externalId]     = event.externalId
            it[externalSource] = event.externalSource?.name?.lowercase()
            it[bookingRef]     = event.bookingRef
            it[aiTip]          = event.aiTip
            it[aiConfidence]   = event.aiConfidence
            it[createdAt]      = event.createdAt
            it[updatedAt]      = event.updatedAt
        }
    }

    private fun ResultRow.toRoute(): Route = Route(
        id            = this[RoutesTable.id].value,
        surveyId      = this[RoutesTable.surveyId].value,
        userId        = this[RoutesTable.userId].value,
        status        = RouteStatus.valueOf(this[RoutesTable.status].uppercase()),
        title         = this[RoutesTable.title],
        summary       = this[RoutesTable.summary],
        coverImageUrl = this[RoutesTable.coverImageUrl],
        totalDays     = this[RoutesTable.totalDays],
        totalCostEst  = this[RoutesTable.totalCostEst],
        currency      = this[RoutesTable.currency],
        days          = this[RoutesTable.planRaw].parseDays(),
        variantIndex  = this[RoutesTable.variantIndex],
        variantLabel  = this[RoutesTable.variantLabel],
        confirmedAt   = this[RoutesTable.confirmedAt],
        createdAt     = this[RoutesTable.createdAt],
        updatedAt     = this[RoutesTable.updatedAt],
    )
}

// ============================================================
// NOTIFICATION REPOSITORY
// ============================================================

class NotificationRepositoryImpl : NotificationRepository {

    override suspend fun findPendingToSend(): List<Notification> = dbQuery {
        NotificationsTable.selectAll()
            .where {
                (NotificationsTable.isSent eq false) and
                (NotificationsTable.scheduledAt lessEq Instant.now())
            }
            .orderBy(NotificationsTable.scheduledAt, SortOrder.ASC)
            .limit(100)
            .map { it.toNotification() }
    }

    override suspend fun findByUserId(userId: UUID): List<Notification> = dbQuery {
        NotificationsTable.selectAll()
            .where { NotificationsTable.userId eq userId }
            .orderBy(NotificationsTable.scheduledAt, SortOrder.DESC)
            .limit(50)
            .map { it.toNotification() }
    }

    override suspend fun save(notification: Notification): Notification = dbQuery {
        NotificationsTable.insert {
            it[id]          = notification.id
            it[userId]      = notification.userId
            it[routeId]     = notification.routeId
            it[type]        = notification.type.name.lowercase()
            it[title]       = notification.title
            it[body]        = notification.body
            it[deepLink]    = notification.deepLink
            it[scheduledAt] = notification.scheduledAt
            it[deviceToken] = notification.deviceToken
            it[createdAt]   = notification.createdAt
        }
        notification
    }

    override suspend fun markSent(id: UUID, apnsId: String): Notification = dbQuery {
        NotificationsTable.update({ NotificationsTable.id eq id }) {
            it[isSent]  = true
            it[sentAt]  = Instant.now()
            it[NotificationsTable.apnsId] = apnsId
        }
        findNotificationById(id)!!
    }

    override suspend fun markRead(id: UUID): Notification = dbQuery {
        NotificationsTable.update({ NotificationsTable.id eq id }) {
            it[isRead] = true
            it[readAt] = Instant.now()
        }
        findNotificationById(id)!!
    }

    private fun findNotificationById(id: UUID): Notification? =
        NotificationsTable.selectAll()
            .where { NotificationsTable.id eq id }
            .singleOrNull()
            ?.toNotification()

    private fun ResultRow.toNotification() = Notification(
        id          = this[NotificationsTable.id].value,
        userId      = this[NotificationsTable.userId].value,
        routeId     = this[NotificationsTable.routeId]?.value,
        type        = NotificationType.valueOf(this[NotificationsTable.type].uppercase()),
        title       = this[NotificationsTable.title],
        body        = this[NotificationsTable.body],
        deepLink    = this[NotificationsTable.deepLink],
        scheduledAt = this[NotificationsTable.scheduledAt],
        sentAt      = this[NotificationsTable.sentAt],
        readAt      = this[NotificationsTable.readAt],
        isSent      = this[NotificationsTable.isSent],
        isRead      = this[NotificationsTable.isRead],
        apnsId      = this[NotificationsTable.apnsId],
        deviceToken = this[NotificationsTable.deviceToken],
        createdAt   = this[NotificationsTable.createdAt],
    )
}

// ============================================================
// JSONB HELPERS (placeholders — implement with Jackson/kotlinx)
// ============================================================

private fun List<SurveyDestination>.toJsonb(): String =
    com.fasterxml.jackson.module.kotlin.jacksonObjectMapper()
        .writeValueAsString(this)

private fun String.parseDestinations(): List<SurveyDestination> =
    com.fasterxml.jackson.module.kotlin.jacksonObjectMapper()
        .readValue(this, object : com.fasterxml.jackson.core.type.TypeReference<List<SurveyDestination>>() {})

private fun List<RouteDay>.toJsonb(): String =
    com.fasterxml.jackson.module.kotlin.jacksonObjectMapper()
        .writeValueAsString(this)

private fun String.parseDays(): List<RouteDay> =
    com.fasterxml.jackson.module.kotlin.jacksonObjectMapper()
        .readValue(this, object : com.fasterxml.jackson.core.type.TypeReference<List<RouteDay>>() {})
