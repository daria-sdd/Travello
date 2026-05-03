package com.wayai.application

import com.wayai.domain.*
import com.wayai.infrastructure.db.DeviceTokenRepository
import com.wayai.infrastructure.db.NotificationRepository
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID

@Service
class NotificationUseCase(
    private val notificationRepository: NotificationRepository,
    private val deviceTokenRepository: DeviceTokenRepository,
) {
    private val log = LoggerFactory.getLogger(NotificationUseCase::class.java)

    suspend fun scheduleForRoute(route: Route) {
        val notifications = mutableListOf<Notification>()
        val deviceToken   = deviceTokenRepository
            .findActiveByUserId(route.userId)
            .firstOrNull()?.token

        route.days.forEach { day ->
            day.events.forEach { event ->
                when (event.eventType) {
                    EventType.FLIGHT -> {
                        event.startsAt?.let { flightTime ->
                            notifications += Notification(
                                userId      = route.userId,
                                routeId     = route.id,
                                type        = NotificationType.CHECKIN_REMINDER,
                                title       = "Время на регистрацию ✈️",
                                body        = "Онлайн-регистрация на ${event.title} открылась. Зарегистрируйтесь сейчас.",
                                deepLink    = "wayai://route/${route.id}/event/${event.id}",
                                scheduledAt = flightTime.minus(24, ChronoUnit.HOURS),
                                deviceToken = deviceToken,
                            )
                            notifications += Notification(
                                userId      = route.userId,
                                routeId     = route.id,
                                type        = NotificationType.DEPART_REMINDER,
                                title       = "Пора выезжать в аэропорт 🚗",
                                body        = "Вылет через 3 часа. Учитывайте время на дорогу.",
                                deepLink    = "wayai://route/${route.id}/day/${day.id}",
                                scheduledAt = flightTime.minus(3, ChronoUnit.HOURS),
                                deviceToken = deviceToken,
                            )
                        }
                    }
                    EventType.ACCOMMODATION -> {
                        event.startsAt?.let { checkIn ->
                            notifications += Notification(
                                userId      = route.userId,
                                routeId     = route.id,
                                type        = NotificationType.CUSTOM,
                                title       = "Заезд в ${event.title} 🏨",
                                body        = "Через 2 часа заезд. Уточните время получения ключей.",
                                deepLink    = "wayai://route/${route.id}/event/${event.id}",
                                scheduledAt = checkIn.minus(2, ChronoUnit.HOURS),
                                deviceToken = deviceToken,
                            )
                        }
                    }
                    else -> {}
                }
            }

            // Ежедневный совет в 8:00 утра
            day.date?.let { travelDate ->
                val tipTime = travelDate.atTime(8, 0).toInstant(java.time.ZoneOffset.UTC)
                if (tipTime.isAfter(Instant.now())) {
                    notifications += Notification(
                        userId      = route.userId,
                        routeId     = route.id,
                        type        = NotificationType.DAILY_TIP,
                        title       = "День ${day.dayNumber}: ${day.city} 🗺",
                        body        = day.summary ?: "Сегодня насыщенный день. Откройте приложение.",
                        deepLink    = "wayai://route/${route.id}/day/${day.id}",
                        scheduledAt = tipTime,
                        deviceToken = deviceToken,
                    )
                }
            }
        }

        // Маршрут подтверждён — сразу
        notifications += Notification(
            userId      = route.userId,
            routeId     = route.id,
            type        = NotificationType.ROUTE_READY,
            title       = "Маршрут подтверждён! 🎉",
            body        = "${route.title}. ${route.totalDays} дней, всё спланировано.",
            deepLink    = "wayai://route/${route.id}",
            scheduledAt = Instant.now().plusSeconds(5),
            deviceToken = deviceToken,
        )

        notifications.forEach { notificationRepository.save(it) }
        log.info("Scheduled ${notifications.size} notifications for route=${route.id}")
    }

    suspend fun scheduleWeatherAlert(userId: UUID, routeId: UUID, message: String, deepLink: String) {
        val token = deviceTokenRepository.findActiveByUserId(userId).firstOrNull()?.token
        notificationRepository.save(Notification(
            userId = userId, routeId = routeId,
            type = NotificationType.WEATHER_ALERT,
            title = "Изменение погоды ⛅", body = message,
            deepLink = deepLink,
            scheduledAt = Instant.now().plusSeconds(10),
            deviceToken = token,
        ))
    }
}
