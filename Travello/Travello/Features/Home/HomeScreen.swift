import SwiftUI
import Combine

// ============================================================
// HOME SCREEN
// ============================================================

struct HomeScreen: View {
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, Spacing.screenPadding)
                    .padding(.top, Spacing.xl)

                countdownOrCreate
                    .padding(.horizontal, Spacing.screenPadding)
                    .padding(.top, Spacing.lg)

                if let tip = vm.dailyTip {
                    dailyTipBlock(tip)
                        .padding(.horizontal, Spacing.screenPadding)
                        .padding(.top, Spacing.lg)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                tripsSection.padding(.top, Spacing.xl)

                Spacer(minLength: Spacing.xxxl + 60)
            }
        }
        .background(Color.Travello.cream.ignoresSafeArea())
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.greeting)
                    .font(.Travello.italic).foregroundColor(.Travello.mute)
                Text(vm.userName)
                    .font(.Travello.h1).foregroundColor(.Travello.ink)
            }
            Spacer()
            Button { Haptics.tap() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.Travello.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.Travello.sand))
                    .overlay(Circle().stroke(Color.Travello.line, lineWidth: Stroke.hairline))
            }.buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var countdownOrCreate: some View {
        if let active = vm.activeRoute { CountdownBlock(route: active) }
        else { CreateRoutePromo() }
    }

    private func dailyTipBlock(_ tip: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            EyebrowLine(text: "совет дня", color: .Travello.terra)
            Text(tip)
                .font(.Travello.italic).foregroundColor(.Travello.inkSoft)
                .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.Travello.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.Travello.line, lineWidth: Stroke.hairline))
    }

    private var tripsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Мои поездки").font(.Travello.h3).foregroundColor(.Travello.ink)
                Spacer()
                Button { } label: { Text("все").font(.Travello.italic).foregroundColor(.Travello.terra) }.buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.screenPadding)
            Rule().padding(.horizontal, Spacing.screenPadding).padding(.top, Spacing.sm)

            if vm.allRoutes.isEmpty && !vm.isLoading {
                VStack(spacing: Spacing.md) {
                    Text("✈").font(.system(size: 36)).foregroundColor(.Travello.tertiary)
                    Text("Пока нет поездок").font(.Travello.italic).foregroundColor(.Travello.mute)
                }
                .frame(maxWidth: .infinity).padding(.vertical, Spacing.xxl)
                .padding(.horizontal, Spacing.screenPadding)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vm.allRoutes.enumerated()), id: \.element.id) { idx, route in
                        TripRow(route: route, index: idx)
                            .padding(.horizontal, Spacing.screenPadding)
                            .opacity(vm.rowsAppeared ? 1 : 0)
                            .offset(y: vm.rowsAppeared ? 0 : 16)
                            .animation(Anim.spring.delay(Double(idx) * Anim.cardCascade), value: vm.rowsAppeared)
                        if idx < vm.allRoutes.count - 1 {
                            SoftRule().padding(.horizontal, Spacing.screenPadding)
                        }
                    }
                }
            }
        }
    }
}

// ── Countdown ────────────────────────────────────────────────

struct CountdownBlock: View {
    let route: Route
    @State private var daysLeft = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("до \((route.days.first?.city ?? "поездки").lowercased())").eyebrow(.Travello.honey)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text("\(daysLeft)")
                    .font(.custom("Fraunces72pt-LightItalic", size: 56)).foregroundColor(.white)
                Text(pluralDays(daysLeft)).font(.Travello.h2).foregroundColor(.Travello.honey)
            }
            if let ev = route.nextEvent, let t = ev.timeString {
                Text("\(ev.title ?? "") · \(t)")
                    .font(.Travello.caption).foregroundColor(.Travello.honey.opacity(0.8)).lineLimit(1)
            }
        }
        .padding(Spacing.lg).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(Color.Travello.ink))
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(RadialGradient(colors: [Color.Travello.terra.opacity(0.4), .clear],
                                     center: .center, startRadius: 0, endRadius: 60))
                .frame(width: 120, height: 120).offset(x: 20, y: -20).clipped()
        }
        .onAppear {
            if let d = route.days.compactMap(\.date).sorted().first {
                daysLeft = max(0, Calendar.current.dateComponents([.day], from: Date(), to: d).day ?? 0)
            }
        }
    }

    private func pluralDays(_ n: Int) -> String {
        let m = n % 10; let m100 = n % 100
        if (11...14).contains(m100) { return "дней" }
        switch m { case 1: return "день"; case 2...4: return "дня"; default: return "дней" }
    }
}

// ── Create promo ─────────────────────────────────────────────

struct CreateRoutePromo: View {
    var body: some View {
        HStack(spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Куда следующая?").font(.Travello.h2).foregroundColor(.Travello.ink)
                Text("ИИ спланирует маршрут с реальными рейсами за минуту")
                    .font(.Travello.italic).foregroundColor(.Travello.mute).lineSpacing(3)
            }
            Spacer()
            Text("+")
                .font(.custom("Fraunces72pt-Light", size: 40)).foregroundColor(.Travello.terra)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.Travello.sand))
                .overlay(Circle().stroke(Color.Travello.terra, lineWidth: Stroke.hairline))
        }
        .padding(Spacing.lg)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(Color.Travello.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.Travello.line, lineWidth: Stroke.hairline))
    }
}

// ── Trip row ─────────────────────────────────────────────────

struct TripRow: View {
    let route: Route; let index: Int
    private let gradients: [(Color, Color)] = [
        (.Travello.apricot, .Travello.terra),
        (Color(hex: 0x9FC4A8), .Travello.olive),
        (Color(hex: 0xF4D1A6), .Travello.honey),
    ]
    var body: some View {
        HStack(spacing: Spacing.md) {
            EditorialNumeral(value: index + 1, size: 24, color: route.isActive ? .Travello.terra : .Travello.tertiary)
                .frame(width: 28, alignment: .leading)
            let g = gradients[index % gradients.count]
            RoundedRectangle(cornerRadius: Radius.xs)
                .fill(LinearGradient(colors: [g.0, g.1], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(route.title).font(.Travello.h3).foregroundColor(.Travello.ink).lineLimit(1)
                Text("\(route.days.first?.city ?? "") · \(route.totalDays) дней")
                    .font(.Travello.caption).foregroundColor(.Travello.mute)
            }
            Spacer()
            if route.isActive { Circle().fill(Color.Travello.olive).frame(width: 8, height: 8) }
            else { Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.Travello.tertiary) }
        }
        .padding(.vertical, Spacing.md)
    }
}

// ── ViewModel ─────────────────────────────────────────────────

@MainActor final class HomeViewModel: ObservableObject {
    @Published var allRoutes   = [Route]()
    @Published var activeRoute: Route?
    @Published var dailyTip:    String?
    @Published var isLoading   = true
    @Published var rowsAppeared = false
    @Published var userName    = "..."

    var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Доброе утро,"
        case 12..<17: return "Добрый день,"
        case 17..<22: return "Добрый вечер,"
        default: return "Доброй ночи,"
        }
    }

    func load() async {
        isLoading = true; rowsAppeared = false
        async let r: [RouteDTO] = (try? await APIClient.shared.request(.listRoutes)) ?? []
        async let a: RouteDTO?  =  try? await APIClient.shared.request(.activeRoute)
        async let u: UserDTO?   =  try? await APIClient.shared.request(.authMe)
        let (rr, ar, ur) = await (r, a, u)
        allRoutes   = rr.map { RouteMapper.toRoute($0) }
        activeRoute = ar.map  { RouteMapper.toRoute($0) }
        userName    = ur?.displayName?.components(separatedBy: " ").first ?? "путешественник"
        isLoading   = false
        withAnimation(Anim.spring.delay(0.1)) { rowsAppeared = true }
    }
}
