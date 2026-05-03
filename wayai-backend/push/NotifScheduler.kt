package com.wayai.infrastructure.push

import com.wayai.infrastructure.db.NotificationRepository
import kotlinx.coroutines.runBlocking
import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.EnableScheduling
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component

// ============================================================
// NOTIFICATION SCHEDULER
// Каждые 30 секунд проверяет БД и отправляет pending уведомления.
// ============================================================

@EnableScheduling
@Component
class NotifScheduler(
    private val notificationRepository: NotificationRepository,
    private val apnsService: ApnsService,
) {
    private val log = LoggerFactory.getLogger(NotifScheduler::class.java)

    @Scheduled(fixedDelay = 30_000)
    fun dispatch() = runBlocking {
        val pending = notificationRepository.findPendingToSend()
        if (pending.isEmpty()) return@runBlocking

        log.info("Dispatching ${pending.size} pending notifications")
        pending.forEach { notif ->
            runCatching { apnsService.send(notif) }
                .onFailure { e -> log.error("Failed notif=${notif.id}: ${e.message}") }
        }
    }
}
