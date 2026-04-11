package com.wayai.infrastructure.ai

import com.fasterxml.jackson.databind.ObjectMapper
import com.wayai.domain.*
import com.wayai.infrastructure.db.AiConversationRepository
import com.wayai.infrastructure.db.RouteRepository
import com.wayai.infrastructure.db.SurveyRepository
import dev.langchain4j.agent.tool.ToolSpecification
import dev.langchain4j.data.message.*
import dev.langchain4j.memory.chat.MessageWindowChatMemory
import dev.langchain4j.model.anthropic.AnthropicChatModel
import dev.langchain4j.service.AiServices
import dev.langchain4j.service.tool.ToolExecution
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

// ============================================================
// AI ORCHESTRATOR
// The central brain of WayAI. Receives a Survey, runs Claude
// with Tool Use to gather real data, and produces Route variants.
// ============================================================

@Service
class AiOrchestrator(
    private val anthropicModel: AnthropicChatModel,
    private val tools: TravelAiTools,
    private val surveyRepository: SurveyRepository,
    private val routeRepository: RouteRepository,
    private val conversationRepository: AiConversationRepository,
    private val responseMapper: AiResponseMapper,
    private val objectMapper: ObjectMapper,
) {
    private val log = LoggerFactory.getLogger(AiOrchestrator::class.java)

    // ----------------------------------------------------------
    // ROUTE GENERATION
    // Called by Kafka consumer. Emits SSE progress events.
    // ----------------------------------------------------------

    fun generateRoutes(survey: Survey): Flow<GenerationProgress> = flow {
        log.info("Starting route generation for survey=${survey.id}")

        emit(GenerationProgress.Step(1, 5, "Анализирую ваши предпочтения..."))

        // Build the user prompt from survey
        val context  = survey.toContext()
        val prompt   = AiPrompts.buildRouteGenerationPrompt(context)

        emit(GenerationProgress.Step(2, 5, "Ищу рейсы и отели..."))

        // Build agent with tool-use memory (window of 40 messages)
        val agent = buildAgent()
        val messages = mutableListOf<AiMessage>()

        // Log the initial user message
        messages += AiMessage(
            userId    = survey.userId,
            surveyId  = survey.id,
            role      = AiRole.USER,
            content   = prompt,
            model     = anthropicModel.modelName(),
        )

        emit(GenerationProgress.Step(3, 5, "ИИ составляет маршруты..."))

        // Execute agent — Claude will call tools autonomously
        val rawResponse = runCatching {
            agent.generate(prompt)
        }.getOrElse { e ->
            log.error("Claude API error for survey=${survey.id}", e)
            emit(GenerationProgress.Failed("Ошибка AI: ${e.message}"))
            return@flow
        }

        emit(GenerationProgress.Step(4, 5, "Собираю финальный план..."))

        // Parse Claude's structured JSON response
        val generationResponse = runCatching {
            objectMapper.readValue(rawResponse, RouteGenerationResponse::class.java)
        }.getOrElse { e ->
            log.error("Failed to parse AI response for survey=${survey.id}: $rawResponse", e)
            emit(GenerationProgress.Failed("Ошибка парсинга ответа AI"))
            return@flow
        }

        // Log the assistant response
        messages += AiMessage(
            userId    = survey.userId,
            surveyId  = survey.id,
            role      = AiRole.ASSISTANT,
            content   = rawResponse,
            model     = anthropicModel.modelName(),
        )
        conversationRepository.saveAll(messages)

        // Map AI response to domain Route objects
        val routes = generationResponse.variants.map { variant ->
            responseMapper.toRoute(variant, survey)
        }

        emit(GenerationProgress.Step(5, 5, "Готово! Сохраняю варианты..."))

        // Persist all route variants
        routes.forEach { route -> routeRepository.save(route) }

        emit(GenerationProgress.Done(
            surveyId = survey.id,
            routeIds = routes.map { it.id },
            generationNotes = generationResponse.generationNotes,
        ))

        log.info("Route generation complete: survey=${survey.id}, variants=${routes.size}")
    }

    // ----------------------------------------------------------
    // ROUTE EDIT (NLP)
    // Called when user sends a chat message to modify the route.
    // ----------------------------------------------------------

    suspend fun applyEdit(
        route: Route,
        userMessage: String,
        userId: UUID,
    ): RouteEditResult {
        log.info("Applying edit to route=${route.id}: \"$userMessage\"")

        // Build edit prompt with current plan summary
        val planSummary = responseMapper.buildPlanSummary(route)
        val prompt      = AiPrompts.buildRouteEditPrompt(userMessage, planSummary)

        // Load existing conversation history for context
        val history = conversationRepository.findByRouteId(route.id)

        // Build agent with full history (so Claude remembers previous edits)
        val agent = buildAgentWithHistory(history)

        val rawResponse = runCatching {
            agent.generate(prompt)
        }.getOrElse { e ->
            log.error("Claude edit error for route=${route.id}", e)
            throw AiOrchestratorException("Edit failed: ${e.message}", e)
        }

        val editResponse = runCatching {
            objectMapper.readValue(rawResponse, RouteEditResponse::class.java)
        }.getOrElse { e ->
            throw AiOrchestratorException("Failed to parse edit response", e)
        }

        // Persist conversation turns
        conversationRepository.saveAll(listOf(
            AiMessage(userId = userId, routeId = route.id, role = AiRole.USER,
                content = userMessage, model = anthropicModel.modelName()),
            AiMessage(userId = userId, routeId = route.id, role = AiRole.ASSISTANT,
                content = rawResponse, model = anthropicModel.modelName()),
        ))

        // Apply changes to domain model
        val updatedRoute = responseMapper.applyEditToRoute(route, editResponse)
        routeRepository.update(updatedRoute)

        return RouteEditResult(
            updatedRoute   = updatedRoute,
            changeSummary  = editResponse.changeSummary,
        )
    }

    // ----------------------------------------------------------
    // DAILY TIP
    // Generates a personalized tip for today's push notification.
    // ----------------------------------------------------------

    suspend fun generateDailyTip(
        userName: String,
        todayEvents: String,
        tomorrowEvents: String,
        weatherToday: String,
        weatherTomorrow: String,
    ): String {
        val prompt = AiPrompts.buildDailyTipPrompt(
            userName        = userName,
            todayEvents     = todayEvents,
            tomorrowEvents  = tomorrowEvents,
            weatherToday    = weatherToday,
            weatherTomorrow = weatherTomorrow,
        )

        // Simple single-turn call (no tools needed for a tip)
        val response = anthropicModel.generate(
            SystemMessage.from(AiPrompts.ROUTE_GENERATION_SYSTEM),
            UserMessage.from(prompt),
        )

        return response.content().text().trim()
    }

    // ----------------------------------------------------------
    // AGENT BUILDER
    // Creates a LangChain4j AI service wired to Claude + tools.
    // ----------------------------------------------------------

    private fun buildAgent(): TravelPlannerAgent {
        return AiServices.builder(TravelPlannerAgent::class.java)
            .chatLanguageModel(anthropicModel)
            .tools(tools)
            .systemMessageProvider { AiPrompts.ROUTE_GENERATION_SYSTEM }
            .chatMemory(MessageWindowChatMemory.withMaxMessages(60))
            .build()
    }

    private fun buildAgentWithHistory(history: List<AiMessage>): TravelPlannerAgent {
        val memory = MessageWindowChatMemory.withMaxMessages(60)

        // Restore previous conversation into memory
        history.forEach { msg ->
            when (msg.role) {
                AiRole.USER      -> memory.add(UserMessage.from(msg.content))
                AiRole.ASSISTANT -> memory.add(AiMessage.from(msg.content))
                else             -> { /* tool results already embedded */ }
            }
        }

        return AiServices.builder(TravelPlannerAgent::class.java)
            .chatLanguageModel(anthropicModel)
            .tools(tools)
            .systemMessageProvider { AiPrompts.ROUTE_EDIT_SYSTEM }
            .chatMemory(memory)
            .build()
    }
}

// ============================================================
// LANGCHAIN4J AGENT INTERFACE
// LangChain4j generates the proxy implementation at startup.
// ============================================================

interface TravelPlannerAgent {
    fun generate(userMessage: String): String
}

// ============================================================
// PROGRESS EVENTS
// Emitted during generation for SSE streaming to the client.
// ============================================================

sealed class GenerationProgress {
    data class Step(
        val current: Int,
        val total: Int,
        val message: String,
    ) : GenerationProgress()

    data class Done(
        val surveyId: UUID,
        val routeIds: List<UUID>,
        val generationNotes: String?,
    ) : GenerationProgress()

    data class Failed(val reason: String) : GenerationProgress()
}

// ============================================================
// RESULTS
// ============================================================

data class RouteEditResult(
    val updatedRoute:  Route,
    val changeSummary: String,
)

class AiOrchestratorException(message: String, cause: Throwable? = null) :
    RuntimeException(message, cause)

// ============================================================
// SURVEY → CONTEXT MAPPER (extension function)
// ============================================================

fun Survey.toContext(): SurveyContext {
    val datesDesc = when {
        dateFrom != null && dateTo != null ->
            "From $dateFrom to $dateTo (${java.time.temporal.ChronoUnit.DAYS.between(dateFrom, dateTo)} nights)"
        dateFrom != null ->
            "Departing $dateFrom, duration flexible"
        else ->
            "Dates fully flexible — pick the best option"
    }

    val destDesc = when {
        destinations.isEmpty() ->
            "No destination specified — surprise the traveller with the best value option"
        destinations.size == 1 ->
            destinations[0].name + " (${destinations[0].type.name.lowercase()})"
        else ->
            destinations.sortedBy { it.order }
                .joinToString(" → ") { it.name }
    }

    val budgetDesc = when {
        budgetAmount != null ->
            "\$$budgetAmount $budgetCurrency total for $travellerCount ${if (travellerCount == 1) "person" else "people"}"
        else ->
            "Not specified — generate 3 tiers (budget / medium / luxury)"
    }

    val budgetCovers = if (budgetIncludes.isEmpty()) "flights and accommodation"
    else budgetIncludes.joinToString(", ") { it.name.lowercase() }

    return SurveyContext(
        departFrom             = departFrom,
        datesDescription       = datesDesc,
        flexibleDates          = flexibleDates,
        destinationsDescription = destDesc,
        travellerCount         = travellerCount,
        travellerNotes         = travellerNotes,
        budgetDescription      = budgetDesc,
        budgetCoversDescription = budgetCovers,
        currency               = budgetCurrency,
        tags                   = tags,
        extraWishes            = extraWishes,
    )
}
