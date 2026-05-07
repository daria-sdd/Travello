package com.wayai.infrastructure.ai

import com.wayai.domain.Route
import com.wayai.infrastructure.db.AiConversationRepository
import com.wayai.infrastructure.db.RouteRepository
import com.wayai.domain.AiRole
import com.wayai.domain.AiMessage
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import org.springframework.web.client.RestClient
import java.util.UUID

// ============================================================
// AI ORCHESTRATOR (Kotlin side)
// Thin HTTP proxy to the Python AI service.
// All heavy AI logic lives in wayai-ai-service.
// ============================================================

@Component
class AiOrchestrator(
    private val routeRepository: RouteRepository,
    private val conversationRepository: AiConversationRepository,
    @Value("\${wayai.ai-service.url:http://localhost:8081}") private val aiServiceUrl: String,
) {
    private val log    = LoggerFactory.getLogger(AiOrchestrator::class.java)
    private val client = RestClient.create()

    data class EditRequest(val routeId: String, val userId: String, val message: String, val history: List<Map<String, String>>)
    data class EditResponse(val routeId: String, val changeSummary: String)
    data class EditResult(val updatedRoute: Route, val changeSummary: String)

    suspend fun applyEdit(route: Route, message: String, userId: UUID): EditResult {
        val history = conversationRepository.findByRouteId(route.id)
            .takeLast(20)
            .map { mapOf("role" to it.role.name.lowercase(), "content" to it.content) }

        val request = EditRequest(route.id.toString(), userId.toString(), message, history)

        val response = runCatching {
            client.post()
                .uri("$aiServiceUrl/internal/routes/edit")
                .body(request)
                .retrieve()
                .body(EditResponse::class.java)
        }.getOrElse { e ->
            log.error("AI service edit request failed for route=${route.id}", e)
            error("AI service unavailable: ${e.message}")
        } ?: error("Empty response from AI service")

        conversationRepository.save(AiMessage(
            userId  = userId,
            routeId = route.id,
            role    = AiRole.USER,
            content = message,
        ))

        val updated = routeRepository.findById(route.id) ?: route
        log.info("Edit applied: route=${route.id} summary='${response.changeSummary}'")
        return EditResult(updated, response.changeSummary)
    }
}
