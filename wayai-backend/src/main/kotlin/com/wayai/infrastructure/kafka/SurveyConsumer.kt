package com.wayai.infrastructure.kafka

import com.wayai.infrastructure.ai.AiOrchestrator
import com.wayai.infrastructure.ai.GenerationProgress
import com.wayai.infrastructure.db.SurveyRepository
import com.wayai.infrastructure.sse.SsePublisher
import com.wayai.domain.SurveyStatus
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.launch
import org.apache.kafka.clients.consumer.ConsumerRecord
import org.slf4j.LoggerFactory
import org.springframework.kafka.annotation.KafkaListener
import org.springframework.kafka.support.Acknowledgment
import org.springframework.stereotype.Component

// ============================================================
// SURVEY CONSUMER
// Слушает Kafka топик, запускает AI Orchestrator,
// транслирует прогресс через SSE к клиенту.
// ============================================================

@Component
class SurveyConsumer(
    private val surveyRepository: SurveyRepository,
    private val orchestrator: AiOrchestrator,
    private val ssePublisher: SsePublisher,
) {
    private val log = LoggerFactory.getLogger(SurveyConsumer::class.java)

    // SupervisorJob: падение одной корутины не роняет всю группу
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    @KafkaListener(
        topics     = ["\${wayai.kafka.topics.route-generation}"],
        groupId    = "wayai-route-generator",
        // Ручное подтверждение: ack только после успешной обработки
        containerFactory = "manualAckKafkaListenerContainerFactory",
    )
    fun onGenerationRequest(
        record: ConsumerRecord<String, RouteGenerationEvent>,
        ack: Acknowledgment,
    ) {
        val event = record.value()
        log.info("Received generation event: survey=${event.surveyId}")

        scope.launch {
            runCatching {
                process(event)
            }.onFailure { e ->
                log.error("Unhandled error processing survey=${event.surveyId}", e)
                // Помечаем survey как failed чтобы клиент не ждал вечно
                surveyRepository.updateStatus(event.surveyId, SurveyStatus.FAILED, e.message)
                ssePublisher.publishFailed(event.surveyId, "Произошла внутренняя ошибка. Попробуйте ещё раз.")
            }
            // Подтверждаем offset в любом случае — повторная обработка через retry логику
            ack.acknowledge()
        }
    }

    private suspend fun process(event: RouteGenerationEvent) {
        // 1. Загружаем survey из БД
        val survey = surveyRepository.findById(event.surveyId)
            ?: run {
                log.warn("Survey not found: ${event.surveyId}, skipping")
                return
            }

        // 2. Помечаем как "в обработке"
        surveyRepository.updateStatus(event.surveyId, SurveyStatus.PROCESSING)

        // 3. Запускаем AI Orchestrator — он возвращает Flow с прогрессом
        orchestrator.generateRoutes(survey)
            .catch { e ->
                log.error("AI generation flow error for survey=${event.surveyId}", e)
                surveyRepository.updateStatus(event.surveyId, SurveyStatus.FAILED, e.message)
                ssePublisher.publishFailed(event.surveyId, "Ошибка генерации маршрута")
            }
            .collect { progress ->
                // 4. Каждый шаг прогресса транслируем клиенту через SSE
                when (progress) {
                    is GenerationProgress.Step -> {
                        log.debug("Progress ${progress.current}/${progress.total}: ${progress.message}")
                        ssePublisher.publishStep(event.surveyId, progress)
                    }
                    is GenerationProgress.Done -> {
                        log.info("Generation complete: survey=${event.surveyId}, routes=${progress.routeIds}")
                        surveyRepository.updateStatus(event.surveyId, SurveyStatus.COMPLETED)
                        ssePublisher.publishDone(event.surveyId, progress)
                    }
                    is GenerationProgress.Failed -> {
                        log.error("Generation failed: survey=${event.surveyId}: ${progress.reason}")
                        surveyRepository.updateStatus(event.surveyId, SurveyStatus.FAILED, progress.reason)
                        ssePublisher.publishFailed(event.surveyId, progress.reason)
                    }
                }
            }
    }
}
