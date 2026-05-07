package com.wayai.application

import com.wayai.domain.Survey
import com.wayai.domain.SurveyStatus
import com.wayai.infrastructure.db.SurveyRepository
import com.wayai.infrastructure.kafka.SurveyProducer
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service

// ============================================================
// GENERATE ROUTE USE CASE
// Принимает заполненный Survey, сохраняет в БД,
// публикует событие в Kafka и возвращает survey с pending статусом.
// Клиент подписывается на SSE отдельным запросом.
// ============================================================

@Service
class GenerateRouteUseCase(
    private val surveyRepository: SurveyRepository,
    private val producer: SurveyProducer,
) {
    private val log = LoggerFactory.getLogger(GenerateRouteUseCase::class.java)

    suspend fun execute(survey: Survey): Survey {
        // 1. Сохраняем survey в БД со статусом PENDING
        val saved = surveyRepository.save(survey)
        log.info("Survey saved: id=${saved.id}, user=${saved.userId}")

        // 2. Публикуем в Kafka — генерация начнётся асинхронно
        producer.publishGenerationRequest(saved.id, saved.userId)
        log.info("Generation event published for survey=${saved.id}")

        return saved
    }
}
