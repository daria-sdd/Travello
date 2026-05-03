package com.wayai.application

import com.wayai.infrastructure.db.RouteRepository
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.util.UUID

// ============================================================
// CONFIRM ROUTE USE CASE
// Переводит маршрут draft → active, архивирует остальные
// варианты того же survey, планирует уведомления.
// ============================================================

@Service
class ConfirmRouteUseCase(
    private val routeRepository: RouteRepository,
    private val notificationUseCase: NotificationUseCase,
) {
    private val log = LoggerFactory.getLogger(ConfirmRouteUseCase::class.java)

    suspend fun execute(routeId: UUID, userId: UUID): com.wayai.domain.Route {
        val route = routeRepository.findById(routeId)
            ?: error("Route $routeId not found")
        require(route.userId == userId) { "Access denied" }
        require(route.status == com.wayai.domain.RouteStatus.DRAFT) {
            "Route $routeId is already ${route.status}"
        }

        // Архивируем другие варианты того же survey
        routeRepository.findBySurveyId(route.surveyId)
            .filter { it.id != routeId && it.status == com.wayai.domain.RouteStatus.DRAFT }
            .forEach { routeRepository.archive(it.id) }

        // Подтверждаем выбранный
        val confirmed = routeRepository.confirm(routeId)

        // Планируем умные уведомления
        notificationUseCase.scheduleForRoute(confirmed)

        log.info("Route confirmed: id=$routeId, user=$userId")
        return confirmed
    }
}
