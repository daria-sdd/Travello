package com.wayai.infrastructure.ai

import java.util.UUID

sealed class GenerationProgress {
    data class Step(val current: Int, val total: Int, val message: String) : GenerationProgress()
    data class Done(val surveyId: UUID, val routeIds: List<UUID>, val generationNotes: String?) : GenerationProgress()
    data class Failed(val reason: String) : GenerationProgress()
}
