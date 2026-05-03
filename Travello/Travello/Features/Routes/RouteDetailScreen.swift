import SwiftUI

// ============================================================
// ROUTE DETAIL SCREEN
// Полный маршрут со всеми деталями.
//
// Структура:
// — Hero-обложка с параллаксом (название, метаданные)
// — Горизонтальные таб-пилюли дней
// — Погодный блок (4 ячейки)
// — Editorial таймлайн событий дня
// — Кнопка «Утвердить маршрут» снизу
// ============================================================

struct RouteDetailScreen: View {
    let route: Route

    @State private var selectedDay: Int = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isConfirming = false
    @State private var showConfirmAlert = false

    @Environment(\.dismiss) private var dismiss

    private var currentDay: RouteDay? {
        route.days.first { $0.dayNumber == selectedDay + 1 }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Hero с параллаксом ────────────────────
                    HeroHeader(route: route, scrollOffset: $scrollOffset)

                    // ── Тело ─────────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {

                        // Горизонтальный ряд дней
                        dayTabs
                            .padding(.top, Spacing.lg)

                        Rule().padding(.vertical, Spacing.md)

                        // Город и резюме дня
                        if let day = currentDay {
                            dayHeader(day)
                                .padding(.bottom, Spacing.md)

                            // Блок погоды
                            if let weather = day.weatherNote {
                                WeatherNoteView(text: weather)
                                    .padding(.bottom, Spacing.xl)
                            }

                            // Таймлайн событий
                            timelineSection(day)
                        }
                    }
                    .padding(.horizontal, Spacing.screenPadding)
                    .padding(.bottom, 120)
                }
                // Трекаем скролл для параллакса hero
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ScrollOffsetKey.self,
                                        value: geo.frame(in: .named("scroll")).minY)
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }
            .ignoresSafeArea(edges: .top)

            // ── Кнопка утверждения ────────────────────────────
            if route.isDraft {
                bottomBar
            }
        }
        .background(Color.Travello.cream)
        .alert("Утвердить маршрут?", isPresented: $showConfirmAlert) {
            Button("Утвердить") { Task { await confirm() } }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Остальные варианты будут архивированы. Маршрут можно редактировать в любое время.")
        }
    }

    // ─── Day tabs ─────────────────────────────────────────────

    private var dayTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(route.days) { day in
                    DayTab(
                        day:        day,
                        isSelected: day.dayNumber == selectedDay + 1
                    ) {
                        withAnimation(Anim.spring) { selectedDay = day.dayNumber - 1 }
                        Haptics.select()
                    }
                    .padding(.trailing, 1)   // Тонкая линия между табами
                }
            }
        }
        .background(
            Rectangle()
                .fill(Color.Travello.ink)
                .frame(height: Stroke.hairline),
            alignment: .bottom
        )
    }

    // ─── Day header ───────────────────────────────────────────

    @ViewBuilder
    private func dayHeader(_ day: RouteDay) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(day.city ?? "")
                    .font(.Travello.h2)
                    .foregroundColor(.Travello.ink)

                if let summary = day.summary {
                    Text(summary)
                        .font(.Travello.italic)
                        .foregroundColor(.Travello.mute)
                        .lineSpacing(3)
                }
            }
            Spacer()

            if let date = day.displayDate {
                VStack(alignment: .trailing, spacing: 2) {
                    if let dow = day.shortDayOfWeek {
                        Text(dow).eyebrowSmall()
                    }
                    Text(date)
                        .font(.Travello.h3)
                        .foregroundColor(.Travello.ink)
                }
            }
        }
    }

    // ─── Timeline ─────────────────────────────────────────────

    @ViewBuilder
    private func timelineSection(_ day: RouteDay) -> some View {
        let events = day.events

        // Группируем по типу для eyebrow-разделителей
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(events.enumerated()), id: \.element.id) { idx, event in
                // Eyebrow-строка при смене типа события
                if idx == 0 || events[idx - 1].eventType != event.eventType {
                    EyebrowLine(text: event.eventType.label)
                        .padding(.bottom, Spacing.sm)
                        .padding(.top, idx == 0 ? 0 : Spacing.lg)
                }

                RouteEventCard(
                    event:  event,
                    isLast: idx == events.count - 1
                )
                // Spring-появление с задержкой (лесенка)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(
                    Anim.spring.delay(Double(idx) * Anim.cardCascade),
                    value: selectedDay
                )
            }
        }
        .id(selectedDay)   // пересоздаём при смене дня → сбрасываем анимации
    }

    // ─── Bottom bar ───────────────────────────────────────────

    private var bottomBar: some View {
        VStack(spacing: 0) {
            SoftRule()
            VStack(spacing: Spacing.sm) {
                PrimaryButton(
                    title:     "Утвердить маршрут",
                    action:    { showConfirmAlert = true },
                    isLoading: isConfirming
                )
                Text("После утверждения другие варианты будут архивированы")
                    .font(.Travello.caption)
                    .foregroundColor(.Travello.mute)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.vertical, Spacing.md)
            .background(Color.Travello.cream)
        }
    }

    // ─── Confirm ──────────────────────────────────────────────

    private func confirm() async {
        isConfirming = true
        defer { isConfirming = false }
        _ = try? await APIClient.shared.requestVoid(.confirmRoute(id: route.id))
        Haptics.success()
        dismiss()
    }
}

// ============================================================
// HERO HEADER
// Градиентная обложка с параллакс-эффектом при скролле.
// ============================================================

struct HeroHeader: View {
    let route: Route
    @Binding var scrollOffset: CGFloat

    // Высота hero в покое
    private let baseHeight: CGFloat = 240

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Градиентный фон
            LinearGradient(
                colors: [.Travello.apricot, .Travello.terra],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )
            // Параллакс: hero двигается в 0.4× скорости скролла
            .scaleEffect(
                max(1, 1 - scrollOffset / (baseHeight * 4)),
                anchor: .top
            )
            .offset(y: min(0, scrollOffset * 0.4))

            // Декоративная нумерация
            Text(String(format: "%02d", route.variantIndex + 1))
                .font(.Travello.numeralLarge)
                .foregroundColor(.white.opacity(0.18))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 60)
                .padding(.trailing, Spacing.screenPadding)

            // Затемнение снизу
            LinearGradient(
                colors: [.clear, .black.opacity(0.45)],
                startPoint: .top,
                endPoint:   .bottom
            )

            // Текст
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Eyebrow — страна, дата
                if let country = route.days.first?.country {
                    Text(country.uppercased())
                        .eyebrow(.white.opacity(0.8))
                }

                // Название
                Text(route.title)
                    .font(.Travello.h1)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Мета-строка
                HStack(spacing: Spacing.sm) {
                    MetaChip(text: "\(route.totalDays) дней")
                    if let cost = route.totalCostEst {
                        MetaChip(text: "$\(Int(cost))")
                    }
                    MetaChip(text: "\(route.days.compactMap(\.city).unique.count) города")
                }
            }
            .padding(Spacing.screenPadding)
            .padding(.bottom, Spacing.md)
        }
        .frame(height: baseHeight - min(0, scrollOffset))
        .clipped()
    }
}

private struct MetaChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.Travello.eyebrowSmall)
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Color.white.opacity(0.22))
            )
    }
}

// ============================================================
// DAY TAB
// ============================================================

private struct DayTab: View {
    let day: RouteDay
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                if let dow = day.shortDayOfWeek {
                    Text(dow)
                        .eyebrowSmall(isSelected ? .Travello.terra : .Travello.mute)
                }
                Text(String(format: "%02d", day.dayNumber))
                    .font(.Travello.h3)
                    .foregroundColor(isSelected ? .Travello.terra : .Travello.ink)
            }
            .frame(minWidth: 44)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.sm)
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle()
                        .fill(Color.Travello.terra)
                        .frame(height: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(Anim.microSpring, value: isSelected)
    }
}

// ============================================================
// WEATHER NOTE
// ============================================================

struct WeatherNoteView: View {
    let text: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "sun.max")
                .font(.system(size: 16))
                .foregroundColor(.Travello.apricot)
                .frame(width: 24)

            Text(text)
                .font(.Travello.italic)
                .foregroundColor(.Travello.inkSoft)
                .lineSpacing(3)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.Travello.apricot.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Color.Travello.apricot.opacity(0.3), lineWidth: Stroke.hairline)
        )
    }
}

// ============================================================
// HELPERS
// ============================================================

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension Array where Element: Hashable {
    var unique: [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// ─── PREVIEW ─────────────────────────────────────────────────

#Preview {
    let events = [
        RouteEvent(id: UUID(), eventType: .flight, sortOrder: 0,
            title: "SVO → AYT · TK412", description: nil,
            startsAt: Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date()),
            endsAt: nil, durationMin: 210, locationName: "Шереметьево",
            address: nil, coordinate: nil, imageUrl: nil,
            costEst: 320, currency: "USD", isPrepaid: true, bookingRef: "XK7Y9P",
            aiTip: "Онлайн-регистрация открылась — выбирайте место у иллюминатора"),
        RouteEvent(id: UUID(), eventType: .restaurant, sortOrder: 1,
            title: "Vanilla Restaurant", description: "Средиземноморская кухня с видом на море",
            startsAt: Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()),
            endsAt: nil, durationMin: 90, locationName: "Калеичи",
            address: "Kaleiçi, Antalya", coordinate: nil, imageUrl: nil,
            costEst: 35, currency: "USD", isPrepaid: false, bookingRef: nil,
            aiTip: "Берите столик на террасе — вид на яхты потрясающий"),
    ]
    let day = RouteDay(id: UUID(), dayNumber: 1,
        date: Date(), city: "Анталья", country: "Турция", countryCode: "TR",
        summary: "Прилёт, заселение, вечер в Калеичи",
        weatherNote: "24°C, солнечно. Идеально для прогулки вдоль набережной.",
        events: events)
    let route = Route(
        id: UUID(), surveyId: UUID(), status: .draft,
        variantIndex: 1, variantLabel: "Balanced",
        title: "Антальский берег", summary: "7 дней на турецком побережье",
        coverImageUrl: nil, totalDays: 7, totalCostEst: 1850,
        currency: "USD", days: [day], confirmedAt: nil, createdAt: Date()
    )
    return RouteDetailScreen(route: route)
}
