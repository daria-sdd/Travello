package com.wayai.api

import com.wayai.api.dto.*
import com.wayai.application.GenerateRouteUseCase
import com.wayai.infrastructure.db.RouteRepository
import com.wayai.infrastructure.db.SurveyRepository
import com.wayai.infrastructure.sse.SseSessionStore
import com.wayai.infrastructure.ai.AiOrchestrator
import jakarta.validation.Valid
import kotlinx.coroutines.runBlocking
import org.springframework.http.MediaType
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.*
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter
import java.util.UUID

// ============================================================
// SURVEY CONTROLLER
// POST /api/v1/surveys        — создать опрос, начать генерацию
// GET  /api/v1/surveys/{id}   — статус опроса
// ============================================================

@RestController
@RequestMapping("/api/v1/surveys")
class SurveyController(
    private val generateRoute: GenerateRouteUseCase,
    private val surveyRepository: SurveyRepository,
    private val sseStore: SseSessionStore,
) {
    // Создаём survey и кладём в Kafka.
    // Клиент сразу получает surveyId, потом подписывается на SSE.
    @PostMapping
    fun create(
        @Valid @RequestBody request: SurveyRequest,
        @AuthenticationPrincipal userId: UUID,
    ): ResponseEntity<SurveyResponse> = runBlocking {
        val survey = generateRoute.execute(request.toDomain(userId))
        ResponseEntity.accepted().body(SurveyResponse.from(survey))
    }

    @GetMapping("/{id}")
    fun getStatus(
        @PathVariable id: UUID,
        @AuthenticationPrincipal userId: UUID,
    ): ResponseEntity<SurveyResponse> = runBlocking {
        val survey = surveyRepository.findById(id)
            ?: return@runBlocking ResponseEntity.notFound().build()
        if (survey.userId != userId) return@runBlocking ResponseEntity.status(403).build()
        ResponseEntity.ok(SurveyResponse.from(survey))
    }
}

// ============================================================
// SSE CONTROLLER
// GET /api/v1/surveys/{id}/stream — Server-Sent Events поток.
//
// iOS подключается сразу после POST /surveys.
// Получает события: step (прогресс), done (routeIds), error.
//
// Формат событий:
//   event: step
//   data: {"current":2,"total":5,"message":"Ищу рейсы..."}
//
//   event: done
//   data: {"surveyId":"...","routeIds":["...","...","..."]}
//
//   event: error
//   data: {"reason":"Ошибка генерации"}
// ============================================================

@RestController
@RequestMapping("/api/v1/surveys")
class SseController(private val sseStore: SseSessionStore) {

    @GetMapping("/{surveyId}/stream", produces = [MediaType.TEXT_EVENT_STREAM_VALUE])
    fun stream(
        @PathVariable surveyId: UUID,
        @AuthenticationPrincipal userId: UUID,
    ): SseEmitter = sseStore.register(surveyId)
    // Kafka Consumer будет публиковать прогресс в этот emitter
    // через SsePublisher по мере работы AI Orchestrator'а
}

// ============================================================
// ROUTE CONTROLLER
// GET  /api/v1/routes                — все маршруты пользователя
// GET  /api/v1/routes/active         — текущий активный маршрут
// GET  /api/v1/routes/{id}           — конкретный маршрут
// POST /api/v1/routes/{id}/confirm   — утвердить маршрут
// POST /api/v1/routes/{id}/edit      — NLP правка через чат
// GET  /api/v1/surveys/{id}/routes   — варианты для конкретного survey
// ============================================================

@RestController
@RequestMapping("/api/v1")
class RouteController(
    private val routeRepository: RouteRepository,
    private val orchestrator: AiOrchestrator,
) {
    @GetMapping("/routes")
    fun listRoutes(
        @AuthenticationPrincipal userId: UUID,
    ): ResponseEntity<List<RouteResponse>> = runBlocking {
        val routes = routeRepository.findByUserId(userId)
            .map { RouteResponse.from(it) }
        ResponseEntity.ok(routes)
    }

    @GetMapping("/routes/active")
    fun getActiveRoute(
        @AuthenticationPrincipal userId: UUID,
    ): ResponseEntity<RouteResponse> = runBlocking {
        val route = routeRepository.findActiveByUserId(userId)
            ?: return@runBlocking ResponseEntity.noContent().build()
        ResponseEntity.ok(RouteResponse.from(route))
    }

    @GetMapping("/routes/{id}")
    fun getRoute(
        @PathVariable id: UUID,
        @AuthenticationPrincipal userId: UUID,
    ): ResponseEntity<RouteResponse> = runBlocking {
        val route = routeRepository.findById(id)
            ?: return@runBlocking ResponseEntity.notFound().build()
        if (route.userId != userId) return@runBlocking ResponseEntity.status(403).build()
        ResponseEntity.ok(RouteResponse.from(route))
    }

    // Пользователь выбрал один из 3 вариантов и нажал "Утвердить"
    @PostMapping("/routes/{id}/confirm")
    fun confirmRoute(
        @PathVariable id: UUID,
        @AuthenticationPrincipal userId: UUID,
    ): ResponseEntity<RouteResponse> = runBlocking {
        val route = routeRepository.findById(id)
            ?: return@runBlocking ResponseEntity.notFound().build()
        if (route.userId != userId) return@runBlocking ResponseEntity.status(403).build()
        val confirmed = routeRepository.confirm(id)
        ResponseEntity.ok(RouteResponse.from(confirmed))
    }

    // Пользователь написал в чате "замени отель на дешевле"
    @PostMapping("/routes/{id}/edit")
    fun editRoute(
        @PathVariable id: UUID,
        @Valid @RequestBody request: RouteEditRequest,
        @AuthenticationPrincipal userId: UUID,
    ): ResponseEntity<com.wayai.api.dto.RouteEditResponse> = runBlocking {
        val route = routeRepository.findById(id)
            ?: return@runBlocking ResponseEntity.notFound().build()
        if (route.userId != userId) return@runBlocking ResponseEntity.status(403).build()

        val result = orchestrator.applyEdit(route, request.message, userId)
        ResponseEntity.ok(
            com.wayai.api.dto.RouteEditResponse(
                route         = RouteResponse.from(result.updatedRoute),
                changeSummary = result.changeSummary,
            )
        )
    }

    // Все варианты для конкретного survey (для экрана выбора)
    @GetMapping("/surveys/{surveyId}/routes")
    fun getRouteVariants(
        @PathVariable surveyId: UUID,
        @AuthenticationPrincipal userId: UUID,
    ): ResponseEntity<List<RouteResponse>> = runBlocking {
        val routes = routeRepository.findBySurveyId(surveyId)
            .filter { it.userId == userId }
            .map { RouteResponse.from(it) }
        ResponseEntity.ok(routes)
    }
}
