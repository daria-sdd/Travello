import SwiftUI
import Combine

// ============================================================
// ACTIVE TRIP SCREEN
// Экран текущего путешествия.
// — «День N из M» + город
// — Следующее событие (highlighted)
// — Таймлайн сегодняшнего дня с прогрессом
// — Навигация по дням
// ============================================================

struct ActiveTripScreen: View {
    @StateObject private var vm = ActiveTripViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if let route = vm.route, let today = vm.todayDay {

                    // ── Шапка ─────────────────────────────────
                    activeTripHeader(route: route, day: today)
                        .padding(.horizontal, Spacing.screenPadding)
                        .padding(.top, Spacing.xl)

                    // ── Следующее событие ─────────────────────
                    if let next = vm.nextEvent {
                        nextEventBlock(next)
                            .padding(.horizontal, Spacing.screenPadding)
                            .padding(.top, Spacing.lg)
                    }

                    // ── Таймлайн дня ──────────────────────────
                    Rule()
                        .padding(.horizontal, Spacing.screenPadding)
                        .padding(.top, Spacing.xl)
                        .padding(.bottom, Spacing.sm)

                    EyebrowLine(text: "сегодня")
                        .padding(.horizontal, Spacing.screenPadding)
                        .padding(.bottom, Spacing.md)

                    ForEach(Array(today.events.enumerated()), id: \.element.id) { idx, event in
                        ActiveEventRow(
                            event:     event,
                            isPast:    vm.isEventPast(event),
                            isCurrent: vm.isEventCurrent(event),
                            isLast:    idx == today.events.count - 1
                        )
                        .padding(.horizontal, Spacing.screenPadding)
                        .animation(Anim.spring.delay(Double(idx) * Anim.cardCascade), value: vm.route?.id)
                    }

                } else if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else {
                    emptyState
                }

                Spacer(minLength: Spacing.xxxl + 60)
            }
        }
        .background(Color.Travello.cream.ignoresSafeArea())
        .task { await vm.load() }
    }

    // ─── Шапка активной поездки ───────────────────────────────

    private func activeTripHeader(route: Route, day: RouteDay) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("сейчас: \((day.city ?? "").lowercased())")
                    .font(.Travello.italic).foregroundColor(.Travello.mute)
                (
                    Text("День ").font(.Travello.h1).foregroundColor(.Travello.ink)
                    + Text("\(day.dayNumber)").font(.Travello.h1Italic).foregroundColor(.Travello.terra)
                    + Text(" из \(route.totalDays)").font(.Travello.h1).foregroundColor(.Travello.ink)
                )
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let date = day.displayDate {
                    Text(day.shortDayOfWeek ?? "").eyebrowSmall()
                    Text(date).font(.Travello.h3).foregroundColor(.Travello.ink)
                }
            }
        }
    }

    // ─── Следующее событие ────────────────────────────────────

    private func nextEventBlock(_ event: RouteEvent) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("следующее \(vm.timeUntilNext)").eyebrow(.Travello.terra)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "").font(.Travello.h2).foregroundColor(.white).lineLimit(2)
                if let loc = event.locationName {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 11))
                        Text(loc).font(.Travello.caption)
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(Color.Travello.terra))
        .overlay(alignment: .bottomTrailing) {
            Text(event.timeString ?? "")
                .font(.custom("Fraunces72pt-LightItalic", size: 28))
                .foregroundColor(.white.opacity(0.35))
                .padding(Spacing.md)
        }
    }

    // ─── Пустое состояние ─────────────────────────────────────

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Text("🗺").font(.system(size: 48))
            Text("Нет активной поездки")
                .font(.Travello.italic).foregroundColor(.Travello.mute)
            Text("Создайте маршрут и утвердите его\n— он появится здесь")
                .font(.Travello.caption).foregroundColor(.Travello.tertiary)
                .multilineTextAlignment(.center).lineSpacing(3)
        }
        .frame(maxWidth: .infinity).padding(.top, 100)
    }
}

// ============================================================
// ACTIVE EVENT ROW
// Строка события в таймлайне с визуальным прогрессом.
// ============================================================

struct ActiveEventRow: View {
    let event:     RouteEvent
    let isPast:    Bool
    let isCurrent: Bool
    let isLast:    Bool

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {

            // Левая колонка: время + линия
            VStack(spacing: 0) {
                Text(event.timeString ?? "")
                    .font(.Travello.italicSmall)
                    .foregroundColor(isCurrent ? .Travello.terra : isPast ? .Travello.tertiary : .Travello.mute)
                    .frame(width: 38, alignment: .trailing)
                    .frame(height: 22)

                if !isLast {
                    Rectangle()
                        .fill(isPast ? Color.Travello.olive.opacity(0.5) : Color.Travello.line)
                        .frame(width: Stroke.hairline)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }

            // Маркер на линии
            ZStack {
                Circle()
                    .fill(markerColor)
                    .frame(width: 10, height: 10)
                if isPast {
                    Image(systemName: "checkmark")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .offset(y: 6)

            // Контент
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title ?? "")
                    .font(.Travello.bodyBold)
                    .foregroundColor(isPast ? .Travello.tertiary : .Travello.ink)
                    .strikethrough(isPast)
                    .lineLimit(2)

                if let dur = event.durationString {
                    Text(dur).font(.Travello.caption).foregroundColor(.Travello.mute)
                }

                if isCurrent, let tip = event.aiTip {
                    HStack(alignment: .top, spacing: 4) {
                        Rectangle().fill(Color.Travello.terra).frame(width: 2).cornerRadius(1)
                        Text(tip).font(.Travello.italic).foregroundColor(.Travello.inkSoft).lineSpacing(3)
                    }
                    .padding(.top, Spacing.xs)
                }
            }
            .padding(.bottom, isLast ? 0 : Spacing.lg)
        }
    }

    private var markerColor: Color {
        if isPast    { return .Travello.olive }
        if isCurrent { return .Travello.terra }
        return .Travello.line
    }
}

// ============================================================
// VIEW MODEL
// ============================================================

@MainActor final class ActiveTripViewModel: ObservableObject {
    @Published var route:     Route?
    @Published var todayDay:  RouteDay?
    @Published var nextEvent: RouteEvent?
    @Published var isLoading  = true

    var timeUntilNext: String {
        guard let ev = nextEvent, let start = ev.startsAt else { return "" }
        let diff = start.timeIntervalSinceNow
        if diff < 0 { return "началось" }
        let h = Int(diff) / 3600; let m = (Int(diff) % 3600) / 60
        if h > 0 { return "через \(h) ч \(m) мин" }
        return "через \(m) мин"
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let dto: RouteDTO = try? await APIClient.shared.request(.activeRoute) else { return }
        let loaded = RouteMapper.toRoute(dto)
        route = loaded
        // Находим день соответствующий сегодня
        let today = Calendar.current.startOfDay(for: Date())
        todayDay = loaded.days.first {
            guard let d = $0.date else { return false }
            return Calendar.current.isDate(d, inSameDayAs: today)
        } ?? loaded.days.first

        // Следующее событие после текущего времени
        nextEvent = todayDay?.events.first {
            guard let start = $0.startsAt else { return false }
            return start > Date()
        }
    }

    func isEventPast(_ event: RouteEvent) -> Bool {
        guard let end = event.endsAt ?? event.startsAt.flatMap({
            Calendar.current.date(byAdding: .minute, value: event.durationMin ?? 60, to: $0)
        }) else { return false }
        return end < Date()
    }

    func isEventCurrent(_ event: RouteEvent) -> Bool {
        guard let start = event.startsAt else { return false }
        let end = event.endsAt ?? Calendar.current.date(
            byAdding: .minute, value: event.durationMin ?? 60, to: start)!
        return start <= Date() && Date() <= end
    }
}
