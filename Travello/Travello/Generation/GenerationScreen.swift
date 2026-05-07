import SwiftUI
import Combine
import MapKit

// ============================================================
// GENERATION SCREEN
// Показывается пока AI генерирует маршруты.
// — Анимированная карта с пульсирующими точками (фон)
// — Lottie-заглушка самолёта (реальная Lottie через SPM)
// — SSE прогресс — шаг N из 5 + текстовое описание
// — Плавный переход на RouteVariantsSheet по завершении
// ============================================================

struct GenerationScreen: View {
    let surveyId: UUID

    @EnvironmentObject var appState: AppState
    @StateObject private var vm = GenerationViewModel()

    var body: some View {
        ZStack {
            // ── Фон — анимированная карта ────────────────────
            GenerationMapBackground()
                .ignoresSafeArea()

            // ── Затемнение для читаемости текста ────────────
            Color.Travello.cream.opacity(0.55)
                .ignoresSafeArea()

            // ── Контент по центру ────────────────────────────
            VStack(spacing: Spacing.xxl) {
                Spacer()

                // Lottie / fallback анимация
                PlaneAnimation()
                    .frame(width: 120, height: 80)

                // Статус и прогресс
                VStack(spacing: Spacing.lg) {
                    // Шаг
                    Text(vm.stepLabel)
                        .eyebrow(.Travello.mute)
                        .animation(Anim.smooth, value: vm.stepLabel)

                    // Описание шага
                    Text(vm.message)
                        .font(.Travello.h2)
                        .foregroundColor(.Travello.ink)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .animation(Anim.smooth, value: vm.message)
                        .frame(maxWidth: 260)

                    // Прогресс-дорожка
                    SegmentedProgressBar(
                        total: vm.totalSteps,
                        current: vm.currentStep
                    )
                    .frame(width: 160)
                    .padding(.top, Spacing.xs)
                }

                Spacer()

                // Факт о направлении снизу
                if let fact = vm.travelFact {
                    TravelFactView(text: fact)
                        .padding(.horizontal, Spacing.screenPadding)
                        .padding(.bottom, Spacing.xxxl)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .task {
            await vm.start(surveyId: surveyId)
        }
        .onChange(of: vm.routeIds) { _, ids in
            guard !ids.isEmpty else { return }
            Haptics.success()
            // Переход на экран вариантов
            // appState.showRouteVariants(surveyId: surveyId, routeIds: ids)
        }
        .alert("Ошибка генерации", isPresented: $vm.showError) {
            Button("Попробовать снова") { Task { await vm.start(surveyId: surveyId) } }
            Button("Назад", role: .cancel) { /* pop */ }
        } message: {
            Text(vm.errorMessage ?? "Что-то пошло не так. Попробуйте ещё раз.")
        }
    }
}

// ============================================================
// VIEW MODEL
// ============================================================

@MainActor
final class GenerationViewModel: ObservableObject {
    @Published var currentStep  = 0
    @Published var totalSteps   = 5
    @Published var message      = "Подготавливаю запрос…"
    @Published var routeIds:    [UUID] = []
    @Published var showError    = false
    @Published var errorMessage: String?
    @Published var travelFact:  String?

    var stepLabel: String {
        guard totalSteps > 0 else { return "" }
        return "шаг \(String(format: "%02d", currentStep)) · \(String(format: "%02d", totalSteps))"
    }

    private let sseClient = SSEClient()
    private var factTimer: Timer?

    func start(surveyId: UUID) async {
        currentStep = 0
        message = "Подготавливаю запрос…"
        routeIds = []
        showError = false
        startFactRotation()

        let stream = sseClient.stream(.surveyStream(id: surveyId))

        for await event in stream {
            switch event {
            case .step(let payload):
                withAnimation(Anim.smooth) {
                    currentStep = payload.current
                    totalSteps  = payload.total
                    message     = payload.message
                }

            case .done(let payload):
                withAnimation(Anim.smooth) {
                    currentStep = totalSteps
                    message     = "Маршруты готовы!"
                }
                // Короткая пауза для красоты
                try? await Task.sleep(for: .milliseconds(800))
                routeIds = payload.routeIds

            case .error(let reason):
                errorMessage = reason
                showError    = true
                factTimer?.invalidate()
            }
        }
    }

    private func startFactRotation() {
        let facts = [
            "В октябре в Стамбуле ещё тепло — море 22°C и почти нет туристов",
            "Самый дешёвый день для перелётов в Европу — вторник или среда",
            "Анталья основана в 150 году до н.э. царём Атталом II",
            "В Турции 18 объектов Всемирного наследия ЮНЕСКО",
            "Средний чек в кафе Стамбула — около $8 за обед",
        ]
        var index = 0

        // Первый факт с задержкой 4 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(Anim.smooth) { self.travelFact = facts[index] }

            self.factTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { _ in
                index = (index + 1) % facts.count
                withAnimation(Anim.smooth) { self.travelFact = facts[index] }
            }
        }
    }
}

// ============================================================
// PLANE ANIMATION
// Пока Lottie не подключён — SwiftUI-заглушка.
// Когда добавишь пакет Lottie через SPM:
//   https://github.com/airbnb/lottie-spm
// Замени PlaneAnimation на LottieView(name: "plane_globe")
// ============================================================

struct PlaneAnimation: View {
    @State private var angle:  Double = 0
    @State private var wobble: Double = 0

    var body: some View {
        ZStack {
            // Орбита
            Circle()
                .stroke(Color.Travello.terra.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                .frame(width: 100, height: 100)

            // Самолёт по орбите
            Text("✈")
                .font(.custom("Fraunces72pt-Light", size: 28))
                .foregroundColor(.Travello.terra)
                .offset(x: 50)
                .rotationEffect(.degrees(angle), anchor: .center)
                .offset(x: -50)
        }
        .frame(width: 120, height: 120)
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                angle = 360
            }
        }
    }
}

// ============================================================
// SEGMENTED PROGRESS BAR
// 5 сегментов — заполняются по одному.
// ============================================================

struct SegmentedProgressBar: View {
    let total:   Int
    let current: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i < current ? Color.Travello.terra : Color.Travello.line)
                    .frame(height: 3)
                    .animation(Anim.smooth.delay(Double(i) * 0.08), value: current)
            }
        }
    }
}

// ============================================================
// TRAVEL FACT
// Маленький editorial-блок с фактом о путешествии.
// ============================================================

struct TravelFactView: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Rectangle()
                .fill(Color.Travello.terra)
                .frame(width: 2)
                .cornerRadius(1)

            Text(text)
                .font(.Travello.italic)
                .foregroundColor(.Travello.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.Travello.paper.opacity(0.85))
        )
    }
}

// ============================================================
// MAP BACKGROUND
// Лёгкая интерактивная карта — пользователь видит
// регион назначения пока ждёт.
// ============================================================

struct GenerationMapBackground: View {
    // Стамбул как дефолтная позиция (потом передавать из survey)
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
        span:   MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
    )

    @State private var dots: [MapDot] = [
        .init(coord: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784), delay: 0),
        .init(coord: CLLocationCoordinate2D(latitude: 36.8969, longitude: 30.7133), delay: 0.5),
        .init(coord: CLLocationCoordinate2D(latitude: 38.9637, longitude: 35.2433), delay: 1.0),
        .init(coord: CLLocationCoordinate2D(latitude: 37.8744, longitude: 32.4932), delay: 1.5),
    ]

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: dots) { dot in
            MapAnnotation(coordinate: dot.coord) {
                PulsingDot(delay: dot.delay)
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .disabled(true)   // не даём пользователю скроллить карту
    }
}

struct MapDot: Identifiable {
    let id = UUID()
    let coord: CLLocationCoordinate2D
    let delay: Double
}

struct PulsingDot: View {
    let delay: Double
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.Travello.terra.opacity(0.2))
                .frame(width: 24, height: 24)
                .scaleEffect(pulse ? 2.2 : 1.0)
                .opacity(pulse ? 0 : 0.5)

            Circle()
                .fill(Color.Travello.terra)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(
                .easeOut(duration: 1.8)
                .repeatForever(autoreverses: false)
                .delay(delay)
            ) {
                pulse = true
            }
        }
    }
}

// ─── PREVIEW ─────────────────────────────────────────────────

#Preview {
    GenerationScreen(surveyId: UUID())
        .environmentObject(AppState())
}
