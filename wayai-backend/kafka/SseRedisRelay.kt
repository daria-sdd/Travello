package com.wayai.infrastructure.kafka

import com.fasterxml.jackson.databind.ObjectMapper
import com.wayai.infrastructure.sse.SsePublisher
import com.wayai.infrastructure.ai.GenerationProgress
import jakarta.annotation.PostConstruct
import jakarta.annotation.PreDestroy
import kotlinx.coroutines.*
import org.slf4j.LoggerFactory
import org.springframework.data.redis.connection.Message
import org.springframework.data.redis.connection.MessageListener
import org.springframework.data.redis.listener.PatternTopic
import org.springframework.data.redis.listener.RedisMessageListenerContainer
import org.springframework.stereotype.Component
import java.util.UUID

// ============================================================
// SSE REDIS RELAY
// Python AI-сервис публикует прогресс генерации в Redis pub/sub.
// Этот компонент подписывается на канал sse:survey:* и
// форвардит события в SseEmitter'ы Kotlin SSE Gateway.
//
// Канал: sse:survey:{surveyId}
// Payload: {"event": "step|done|error", "data": {...}}
// ============================================================

@Component
class SseRedisRelay(
    private val listenerContainer: RedisMessageListenerContainer,
    private val ssePublisher: SsePublisher,
    private val objectMapper: ObjectMapper,
) : MessageListener {

    private val log   = LoggerFactory.getLogger(SseRedisRelay::class.java)
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    @PostConstruct
    fun subscribe() {
        // Подписываемся на все каналы по паттерну
        listenerContainer.addMessageListener(this, PatternTopic("sse:survey:*"))
        log.info("SseRedisRelay subscribed to sse:survey:*")
    }

    @PreDestroy
    fun destroy() {
        scope.cancel()
    }

    override fun onMessage(message: Message, pattern: ByteArray?) {
        val channel = String(message.channel)
        val body    = String(message.body)

        // Извлекаем surveyId из канала "sse:survey:{uuid}"
        val surveyId = runCatching {
            UUID.fromString(channel.substringAfterLast(":"))
        }.getOrElse {
            log.warn("SseRedisRelay: bad channel format: $channel")
            return
        }

        scope.launch {
            runCatching {
                val payload = objectMapper.readTree(body)
                val event   = payload["event"].asText()
                val data    = payload["data"]

                when (event) {
                    "step" -> ssePublisher.publishStep(
                        surveyId,
                        GenerationProgress.Step(
                            current = data["current"].asInt(),
                            total   = data["total"].asInt(),
                            message = data["message"].asText(),
                        ),
                    )
                    "done" -> {
                        val routeIds = data["routeIds"]
                            .map { UUID.fromString(it.asText()) }
                        ssePublisher.publishDone(
                            surveyId,
                            GenerationProgress.Done(
                                surveyId        = surveyId,
                                routeIds        = routeIds,
                                generationNotes = data["generationNotes"]?.asText(),
                            ),
                        )
                    }
                    "error" -> ssePublisher.publishFailed(
                        surveyId,
                        data["reason"].asText("Ошибка генерации"),
                    )
                    else -> log.warn("SseRedisRelay: unknown event '$event' on $channel")
                }
            }.onFailure { e ->
                log.error("SseRedisRelay: error processing message from $channel", e)
            }
        }
    }
}
