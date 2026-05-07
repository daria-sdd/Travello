package com.wayai.infrastructure.kafka

import java.util.UUID

// ============================================================
// KAFKA EVENTS
// Сообщения, которые ходят через Kafka.
// Простые data class — сериализуются Jackson'ом в JSON.
// ============================================================

data class RouteGenerationEvent(
    val surveyId: UUID,
    val userId: UUID,
    val triggeredAt: Long = System.currentTimeMillis(),
)
