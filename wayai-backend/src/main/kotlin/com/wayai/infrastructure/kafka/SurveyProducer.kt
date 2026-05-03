package com.wayai.infrastructure.kafka

import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.kafka.core.KafkaTemplate
import org.springframework.stereotype.Component
import java.util.UUID

// ============================================================
// SURVEY PRODUCER
// Публикует событие генерации маршрута в Kafka.
// Survey API → Producer → Kafka → Consumer → AI Orchestrator
// ============================================================

@Component
class SurveyProducer(
    private val kafka: KafkaTemplate<String, RouteGenerationEvent>,
    @Value("\${wayai.kafka.topics.route-generation}") private val topic: String,
) {
    private val log = LoggerFactory.getLogger(SurveyProducer::class.java)

    fun publishGenerationRequest(surveyId: UUID, userId: UUID) {
        val event = RouteGenerationEvent(surveyId = surveyId, userId = userId)

        // Key = userId чтобы события одного пользователя шли в одну партицию по порядку
        kafka.send(topic, userId.toString(), event)
            .whenComplete { result, ex ->
                if (ex != null) {
                    log.error("Failed to publish generation event for survey=$surveyId", ex)
                } else {
                    log.info(
                        "Published generation event: survey=$surveyId " +
                        "partition=${result.recordMetadata.partition()} " +
                        "offset=${result.recordMetadata.offset()}"
                    )
                }
            }
    }
}
