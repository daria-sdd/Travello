package com.wayai.infrastructure.sse

import com.fasterxml.jackson.databind.ObjectMapper
import com.wayai.infrastructure.ai.GenerationProgress
import org.slf4j.LoggerFactory
import org.springframework.data.redis.core.StringRedisTemplate
import org.springframework.stereotype.Component
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.time.Duration

// ============================================================
// SSE SESSION STORE
// Хранит SseEmitter'ы в памяти (один под).
// Redis pub/sub нужен если подов несколько (scale out).
// ============================================================

@Component
class SseSessionStore(private val redis: StringRedisTemplate) {
    private val log = LoggerFactory.getLogger(SseSessionStore::class.java)

    // In-memory map для текущего пода
    private val emitters = ConcurrentHashMap<UUID, SseEmitter>()

    fun register(surveyId: UUID): SseEmitter {
        // Timeout 5 минут — максимальное время генерации маршрута
        val emitter = SseEmitter(Duration.ofMinutes(5).toMillis())

        emitter.onCompletion  { emitters.remove(surveyId) }
        emitter.onTimeout     { emitters.remove(surveyId); log.warn("SSE timeout for survey=$surveyId") }
        emitter.onError       { emitters.remove(surveyId) }

        emitters[surveyId] = emitter

        // Пингуем сразу чтобы соединение не упало до начала генерации
        runCatching { emitter.send(SseEmitter.event().comment("connected")) }

        log.info("SSE registered for survey=$surveyId (active sessions: ${emitters.size})")
        return emitter
    }

    fun get(surveyId: UUID): SseEmitter? = emitters[surveyId]

    fun remove(surveyId: UUID) { emitters.remove(surveyId) }

    fun activeCount(): Int = emitters.size
}

// ============================================================
// SSE PUBLISHER
// Отправляет события прогресса клиенту.
// ============================================================

@Component
class SsePublisher(
    private val store: SseSessionStore,
    private val objectMapper: ObjectMapper,
) {
    private val log = LoggerFactory.getLogger(SsePublisher::class.java)

    fun publishStep(surveyId: UUID, step: GenerationProgress.Step) {
        send(surveyId, "step", SseStepPayload(
            current = step.current,
            total   = step.total,
            message = step.message,
        ))
    }

    fun publishDone(surveyId: UUID, done: GenerationProgress.Done) {
        send(surveyId, "done", SseDonePayload(
            surveyId        = surveyId,
            routeIds        = done.routeIds,
            generationNotes = done.generationNotes,
        ))
        store.remove(surveyId)
    }

    fun publishFailed(surveyId: UUID, reason: String) {
        send(surveyId, "error", SseErrorPayload(reason = reason))
        store.remove(surveyId)
    }

    private fun send(surveyId: UUID, eventName: String, payload: Any) {
        val emitter = store.get(surveyId) ?: run {
            log.debug("No SSE emitter for survey=$surveyId (client disconnected?)")
            return
        }
        runCatching {
            val json = objectMapper.writeValueAsString(payload)
            emitter.send(
                SseEmitter.event()
                    .name(eventName)
                    .data(json)
                    .id(System.currentTimeMillis().toString())
            )
        }.onFailure { e ->
            log.warn("Failed to send SSE event '$eventName' for survey=$surveyId: ${e.message}")
            store.remove(surveyId)
        }
    }
}

// ============================================================
// SSE PAYLOAD DATA CLASSES
// То, что iOS клиент получает в data поле каждого события.
// ============================================================

data class SseStepPayload(
    val current: Int,
    val total: Int,
    val message: String,
)

data class SseDonePayload(
    val surveyId: UUID,
    val routeIds: List<UUID>,
    val generationNotes: String?,
)

data class SseErrorPayload(
    val reason: String,
)
