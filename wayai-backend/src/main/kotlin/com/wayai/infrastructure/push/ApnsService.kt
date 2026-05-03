package com.wayai.infrastructure.push

import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.*
import com.wayai.domain.Notification
import com.wayai.domain.NotificationType
import com.wayai.infrastructure.db.DeviceTokenRepository
import com.wayai.infrastructure.db.NotificationRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service

// ============================================================
// APNS SERVICE
// Отправляет iOS push через Firebase Cloud Messaging (FCM → APNs).
// ============================================================

@Service
class ApnsService(
    private val firebaseApp: FirebaseApp,
    private val deviceTokenRepository: DeviceTokenRepository,
    private val notificationRepository: NotificationRepository,
) {
    private val log = LoggerFactory.getLogger(ApnsService::class.java)

    suspend fun send(notification: Notification): Result<String> {
        val token = notification.deviceToken
            ?: deviceTokenRepository
                .findActiveByUserId(notification.userId)
                .firstOrNull()?.token

        if (token == null) {
            log.warn("No device token for user=${notification.userId}")
            return Result.failure(IllegalStateException("No device token"))
        }

        return withContext(Dispatchers.IO) {
            runCatching {
                val message = buildMessage(notification, token)
                val messageId = FirebaseMessaging.getInstance(firebaseApp).send(message)
                log.info("Push sent: notif=${notification.id} messageId=$messageId")
                notificationRepository.markSent(notification.id, messageId)
                messageId
            }.onFailure { e ->
                log.error("Push failed for notif=${notification.id}: ${e.message}")
                if (e is FirebaseMessagingException &&
                    e.messagingErrorCode in listOf(
                        MessagingErrorCode.UNREGISTERED,
                        MessagingErrorCode.INVALID_ARGUMENT,
                    )
                ) {
                    deviceTokenRepository.deactivate(token)
                }
            }
        }
    }

    suspend fun sendBatch(notifications: List<Notification>) {
        notifications.forEach { send(it) }
    }

    private fun buildMessage(notif: Notification, token: String): Message =
        Message.builder()
            .setToken(token)
            .setApnsConfig(
                ApnsConfig.builder()
                    .setAps(
                        Aps.builder()
                            .setAlert(ApsAlert.builder().setTitle(notif.title).setBody(notif.body).build())
                            .setSound(if (notif.type in listOf(
                                    NotificationType.CHECKIN_REMINDER,
                                    NotificationType.DEPART_REMINDER,
                                    NotificationType.WEATHER_ALERT)
                                ) "alert.caf" else "default")
                            .setMutableContent(true)
                            .build()
                    )
                    .putHeader("apns-priority", if (notif.type in listOf(
                            NotificationType.CHECKIN_REMINDER,
                            NotificationType.DEPART_REMINDER)
                        ) "10" else "5")
                    .build()
            )
            .putData("notif_id",  notif.id.toString())
            .putData("type",      notif.type.name.lowercase())
            .putData("deep_link", notif.deepLink ?: "")
            .putData("route_id",  notif.routeId?.toString() ?: "")
            .build()
}
