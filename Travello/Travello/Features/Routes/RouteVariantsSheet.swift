import SwiftUI
import MapKit

// ============================================================
// ROUTE VARIANTS SHEET
// Шторка с тремя вариантами маршрута над картой.
// — MapKit карта с пинами всех городов (фон)
// — presentationDetents: .medium / .large
// — Вертикальный список 3 карточек-вариантов
// — Тап по карточке → RouteDetailScreen
// ============================================================

struct RouteVariantsView: View {
    let surveyId: UUID
    let routeIds: [UUID]

    @StateObject private var vm = RouteVariantsViewModel()
    @State private var selectedRoute: Route?
    @State private var sheetDetent: PresentationDetent = .medium

    var body: some View {
        ZStack {
            // ── Карта на весь фон ─────────────────────────────
            RouteMapView(routes: vm.routes)
                .ignoresSafeArea()

            // ── Кнопка-заглушка для ручного открытия шторки ──
            // Шторка открывается автоматически при появлении
        }
        .sheet(isPresented: .constant(true)) {
            variantsSheet
                .presentationDetents([.medium, .large], selection: $sheetDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .interactiveDismissDisabled()   // нельзя закрыть — только выбрать вариант
        }
        .sheet(item: $selectedRoute) { route in
            RouteDetailScreen(route: route)
        }
        .task {
            await vm.load(routeIds: routeIds)
        }
    }

    // ─── Варианты в шторке ────────────────────────────────────

    private var variantsSheet: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // Header
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("для вас")
                        .eyebrow()
                    Text("Три маршрута")
                        .font(.Travello.h1)
                        .foregroundColor(.Travello.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.top, Spacing.lg)

                Rule()
                    .padding(.horizontal, Spacing.screenPadding)
                    .padding(.top, Spacing.md)

                // Список вариантов
                if vm.isLoading {
                    VStack(spacing: Spacing.xl) {
                        ForEach(0..<3, id: \.self) { _ in VariantCardSkeleton() }
                    }
                    .padding(.top, Spacing.lg)
                    .padding(.horizontal, Spacing.screenPadding)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(vm.routes.enumerated()), id: \.element.id) { idx, route in
                            VariantCard(
                                route:       route,
                                index:       idx,
                                isRecommended: idx == 1,   // средний вариант = «выбор редактора»
                            ) {
                                Haptics.medium()
                                selectedRoute = route
                                withAnimation(Anim.spring) { sheetDetent = .large }
                            }
                            .padding(.horizontal, Spacing.screenPadding)
                            .padding(.top, Spacing.md)

                            if idx < vm.routes.count - 1 {
                                SoftRule()
                                    .padding(.horizontal, Spacing.screenPadding)
                                    .padding(.top, Spacing.md)
                            }
                        }
                    }
                    .padding(.bottom, Spacing.xxxl)
                }
            }
        }
        .background(Color.Travello.cream)
    }
}

// ============================================================
// VARIANT CARD
// Одна карточка варианта в шторке.
// ============================================================

private struct VariantCard: View {
    let route: Route
    let index: Int
    let isRecommended: Bool
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Spacing.md) {

                // Курсивная нумерация
                EditorialNumeral(
                    value: index + 1,
                    size:  36,
                    color: isRecommended ? .Travello.terra : .Travello.tertiary
                )
                .frame(width: 32, alignment: .leading)

                // Информация
                VStack(alignment: .leading, spacing: 4) {
                    // Тег (Бюджетный / ★ Выбор редактора / Премиум)
                    Text(variantTag)
                        .eyebrowSmall(isRecommended ? .Travello.terra : .Travello.mute)

                    // Название
                    Text(route.title)
                        .font(.Travello.h3)
                        .foregroundColor(.Travello.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Описание
                    if let summary = route.summary {
                        Text(summary)
                            .font(.Travello.italic)
                            .foregroundColor(.Travello.mute)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 1)
                    }
                }

                Spacer()

                // Цена
                VStack(alignment: .trailing, spacing: 2) {
                    if let cost = route.totalCostEst {
                        Text("$\(Int(cost))")
                            .font(.Travello.h3)
                            .foregroundColor(isRecommended ? .Travello.terra : .Travello.ink)
                        Text("/ чел")
                            .eyebrowSmall()
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.Travello.tertiary)
                        .padding(.top, Spacing.xs)
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(isRecommended
                          ? Color.Travello.terra.opacity(0.05)
                          : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(
                        isRecommended ? Color.Travello.terra : Color.clear,
                        lineWidth: Stroke.hairline
                    )
            )
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(Anim.microSpring, value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
    }

    private var variantTag: String {
        switch index {
        case 0: return "бюджетный"
        case 1: return "★ выбор редактора"
        case 2: return "премиум"
        default: return route.variantLabel ?? "вариант \(index + 1)"
        }
    }
}

// ─── SKELETON ────────────────────────────────────────────────

private struct VariantCardSkeleton: View {
    @State private var shimmer = false

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.Travello.line)
                .frame(width: 32, height: 36)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.Travello.line)
                    .frame(height: 10)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.Travello.line)
                    .frame(height: 14)
                    .frame(maxWidth: 180)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.Travello.hairline)
                    .frame(height: 10)
                    .frame(maxWidth: 220)
            }
            Spacer()
        }
        .opacity(shimmer ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.9).repeatForever(), value: shimmer)
        .onAppear { shimmer = true }
    }
}

// ============================================================
// VIEW MODEL
// ============================================================

@MainActor
final class RouteVariantsViewModel: ObservableObject {
    @Published var routes:    [Route] = []
    @Published var isLoading = true
    @Published var error:     String?

    func load(routeIds: [UUID]) async {
        isLoading = true
        defer { isLoading = false }

        var loaded: [Route] = []
        for id in routeIds {
            if let dto = try? await APIClient.shared.request(
                .route(id: id),
                as: RouteDTO.self
            ) {
                loaded.append(RouteMapper.toRoute(dto))
            }
        }
        // Сортируем по variantIndex
        routes = loaded.sorted { $0.variantIndex < $1.variantIndex }
    }
}
