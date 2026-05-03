package com.wayai.api

import com.wayai.api.dto.DeviceTokenRequest
import com.wayai.infrastructure.db.DeviceTokenRepository
import com.wayai.infrastructure.db.NotificationRepository
import com.wayai.domain.DeviceToken
import kotlinx.coroutines.runBlocking
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.*
import java.util.UUID

// ============================================================
// NOTIFICATION CONTROLLER
// GET  /api/v1/notifications          — список уведомлений пользователя
// POST /api/v1/notifications/{id}/read — пометить прочитанным
// POST /api/v1/devices                — зарегистрировать APNs токен
// DELETE /api/v1/devices/{token}      — удалить токен при logout
// ============================================================

@RestController
@RequestMapping("/api/v1")
class NotifController(
    private val notificationRepository: NotificationRepository,
    private val deviceTokenRepository: DeviceTokenRepository,
) {

    @GetMapping("/notifications")
    fun list(
        @AuthenticationPrincipal firebaseUid: String,
        @RequestParam(defaultValue = "false") unreadOnly: Boolean,
    ): ResponseEntity<List<NotificationDto>> = runBlocking {
        val userId = resolveUserId(firebaseUid) ?: return@runBlocking ResponseEntity.notFound().build()
        val notifs = notificationRepository.findByUserId(userId)
            .let { if (unreadOnly) it.filter { n -> !n.isRead } else it }
            .map { NotificationDto.from(it) }
        ResponseEntity.ok(notifs)
    }

    @PostMapping("/notifications/{id}/read")
    fun markRead(
        @PathVariable id: UUID,
        @AuthenticationPrincipal firebaseUid: String,
    ): ResponseEntity<Unit> = runBlocking {
        runCatching { notificationRepository.markRead(id) }
        ResponseEntity.noContent().build()
    }

    @PostMapping("/devices")
    fun registerDevice(
        @RequestBody request: DeviceTokenRequest,
        @AuthenticationPrincipal firebaseUid: String,
    ): ResponseEntity<Unit> = runBlocking {
        val userId = resolveUserId(firebaseUid) ?: return@runBlocking ResponseEntity.notFound().build()
        deviceTokenRepository.save(DeviceToken(
            userId   = userId,
            token    = request.token,
            platform = request.platform,
        ))
        ResponseEntity.ok().build()
    }

    @DeleteMapping("/devices/{token}")
    fun removeDevice(
        @PathVariable token: String,
        @AuthenticationPrincipal firebaseUid: String,
    ): ResponseEntity<Unit> = runBlocking {
        deviceTokenRepository.deactivate(token)
        ResponseEntity.noContent().build()
    }

    // В реальном проекте — через UserRepository.findByFirebaseUid()
    // Упрощено для краткости
    private suspend fun resolveUserId(firebaseUid: String): UUID? = runCatching {
        UUID.fromString(firebaseUid)
    }.getOrNull()
}

data class NotificationDto(
    val id: UUID,
    val type: String,
    val title: String,
    val body: String,
    val deepLink: String?,
    val isRead: Boolean,
    val scheduledAt: String,
    val routeId: UUID?,
) {
    companion object {
        fun from(n: com.wayai.domain.Notification) = NotificationDto(
            id          = n.id,
            type        = n.type.name.lowercase(),
            title       = n.title,
            body        = n.body,
            deepLink    = n.deepLink,
            isRead      = n.isRead,
            scheduledAt = n.scheduledAt.toString(),
            routeId     = n.routeId,
        )
    }
}
