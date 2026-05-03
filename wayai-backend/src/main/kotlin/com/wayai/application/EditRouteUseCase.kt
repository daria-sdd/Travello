package com.wayai.application

import com.wayai.domain.Route
import com.wayai.infrastructure.db.AiConversationRepository
import com.wayai.infrastructure.db.RouteRepository
import com.wayai.domain.AiRole
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.web.client.RestClient
import org.springframework.beans.factory.annotation.Value
import java.util.UUID

// ============================================================
// EDIT ROUTE USE CASE
// Проксирует NLP-запрос на правку в Python AI-сервис.
// Python содержит всю AI-логику — Kotlin только HTTP-клиент.
// ============================================================

@Service
class EditRouteUseCase(
    private val routeRepository: RouteRepository,
    private val conversationRepository: AiConversationRepository,
    @Value("\${wayai.ai-service.url:http://localhost:8081}") private val aiServiceUrl: String,
) {
    private val log    = LoggerFactory.getLogger(EditRouteUseCase::class.java)
    private val client = RestClient.create()

    data class EditRequest(val routeId: String, val userId: String, val message: String, val history: List<Map<String, String>>)
    data class EditResponse(val routeId: String, val changeSummary: String)

    suspend fun execute(routeId: UUID, userId: UUID, message: String): Route {
        val route = routeRepository.findById(routeId) ?: error("Route $routeId not found")
        require(route.userId == userId) { "Access denied" }

        // Загружаем историю диалога для контекста
        val history = conversationRepository.findByRouteId(routeId)
            .takeLast(20)
            .map { mapOf("role" to it.role.name.lowercase(), "content" to it.content) }

        // Отправляем в Python AI-сервис
        val request  = EditRequest(routeId.toString(), userId.toString(), message, history)
        val response = runCatching {
            client.post()
                .uri("$aiServiceUrl/internal/routes/edit")
                .body(request)
                .retrieve()
                .body(EditResponse::class.java)
        }.getOrElse { e ->
            log.error("AI service edit request failed", e)
            error("AI service unavailable: ${e.message}")
        } ?: error("Empty response from AI service")

        // Сохраняем сообщение пользователя в лог
        conversationRepository.save(com.wayai.domain.AiMessage(
            userId    = userId,
            routeId   = routeId,
            role      = AiRole.USER,
            content   = message,
        ))

        log.info("Edit applied: route=$routeId summary='${response.changeSummary}'")
        return routeRepository.findById(routeId)!!
    }
}
