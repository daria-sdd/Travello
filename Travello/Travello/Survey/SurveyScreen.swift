import SwiftUI

// ============================================================
// SURVEY SCREEN
// Главный контейнер опросника.
// Управляет переходами между шагами, прогресс-баром,
// отправкой запроса и переходом на экран генерации.
// ============================================================

struct SurveyScreen: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var surveyState = SurveyState()

    @State private var currentStep: SurveyStep = .dates
    @State private var isSubmitting = false
    @State private var surveyError: String?
    @State private var showError = false

    // Направление анимации при переходе
    @State private var slideDirection: SlideDirection = .forward

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────
            header

            // ── Progress line ─────────────────────────────────
            EditorialProgress(value: progressValue)
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.bottom, Spacing.sm)

            // ── Step content ──────────────────────────────────
            stepContent
                .padding(.horizontal, Spacing.screenPadding)
                .transition(pageTransition)

            // ── Bottom buttons ────────────────────────────────
            bottomButtons
        }
        .background(Color.Travello.cream.ignoresSafeArea())
        .alert("Что-то пошло не так", isPresented: $showError) {
            Button("Попробовать снова") { isSubmitting = false }
        } message: {
            Text(surveyError ?? "Проверьте соединение и попробуйте снова")
        }
    }

    // ─── Header ──────────────────────────────────────────────

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentStep.eyebrow)
                    .eyebrow()
                    .padding(.top, Spacing.lg)

                // Заголовок с italic-акцентом
                (
                    Text(currentStep.plainPrefix)
                        .font(.Travello.h1)
                        .foregroundColor(.Travello.ink)
                    +
                    Text(currentStep.italicAccent)
                        .font(.Travello.h1Italic)
                        .foregroundColor(.Travello.terra)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }

            Spacer()

            // Кнопка пропустить — только для skippable шагов
            if currentStep.isSkippable {
                Button {
                    advance(skip: true)
                } label: {
                    Text("пропустить")
                        .font(.Travello.italic)
                        .foregroundColor(.Travello.mute)
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.lg)
            }
        }
        .padding(.horizontal, Spacing.screenPadding)
        .padding(.bottom, Spacing.md)
    }

    // ─── Step content ─────────────────────────────────────────

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .dates:        Step1_Dates(state: surveyState)
        case .destinations: Step2_Destinations(state: surveyState)
        case .budget:       Step3_Budget(state: surveyState)
        case .tags:         Step4_Tags(state: surveyState)
        case .wishes:       Step5_Wishes(state: surveyState)
        }
    }

    // ─── Bottom buttons ───────────────────────────────────────

    private var bottomButtons: some View {
        VStack(spacing: Spacing.sm) {
            SoftRule()

            VStack(spacing: Spacing.md) {
                // Главная кнопка
                PrimaryButton(
                    title: isLastStep ? "Создать маршрут" : "Продолжить",
                    action: { advance(skip: false) },
                    isLoading: isSubmitting,
                    isDisabled: !surveyState.canProceed(from: currentStep)
                )

                // На последнем шаге — кнопка «Пропустить»
                if currentStep == .wishes {
                    LinkButton(title: "пропустить — займусь позже") {
                        Task { await submit() }
                    }
                }

                // Кнопка «назад» на всех шагах кроме первого
                if currentStep != .dates {
                    Button {
                        goBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 11, weight: .medium))
                            Text("назад")
                                .font(.Travello.italic)
                        }
                        .foregroundColor(.Travello.mute)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.bottom, Spacing.xl)
        }
    }

    // ─── Logic ───────────────────────────────────────────────

    private var isLastStep: Bool { currentStep == .wishes }

    private var progressValue: Double {
        Double(currentStep.rawValue + 1) / Double(SurveyStep.allCases.count)
    }

    private var pageTransition: AnyTransition {
        let insertion: AnyTransition = slideDirection == .forward
            ? .move(edge: .trailing).combined(with: .opacity)
            : .move(edge: .leading).combined(with: .opacity)
        let removal: AnyTransition = slideDirection == .forward
            ? .move(edge: .leading).combined(with: .opacity)
            : .move(edge: .trailing).combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }

    private func advance(skip: Bool) {
        if isLastStep || skip && currentStep == .wishes {
            Task { await submit() }
            return
        }

        guard let next = currentStep.next else {
            Task { await submit() }
            return
        }

        Haptics.tap()
        slideDirection = .forward
        withAnimation(Anim.smooth) {
            currentStep = next
        }
    }

    private func goBack() {
        guard let prev = SurveyStep(rawValue: currentStep.rawValue - 1) else { return }
        Haptics.tap()
        slideDirection = .backward
        withAnimation(Anim.smooth) {
            currentStep = prev
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let request  = surveyState.toRequest()
            let response: SurveyResponseDTO = try await APIClient.shared.request(
                .createSurvey,
                body: request
            )
            Haptics.success()
            // TODO: передать surveyId в GenerationScreen
            // Пока — перейдём на GenerationScreen через AppState
            // appState.startGeneration(surveyId: response.id)
            _ = response
        } catch {
            surveyError = (error as? APIError)?.userFacingMessage ?? error.localizedDescription
            showError = true
            Haptics.error()
        }
    }

    private enum SlideDirection {
        case forward, backward
    }
}

// ─── PREVIEW ─────────────────────────────────────────────────

#Preview("Dates") {
    SurveyScreen().environmentObject(AppState())
}
