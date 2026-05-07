import SwiftUI
import Combine

// ============================================================
// PROFILE SCREEN
// ============================================================

struct ProfileScreen: View {
    @StateObject private var vm = ProfileViewModel()
    @State private var showSettings = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Обложка профиля ────────────────────────────
                ProfileCover(
                    name:      vm.userName,
                    subtitle:  vm.userSubtitle,
                    onSettings: { showSettings = true }
                )

                // ── Статистика ────────────────────────────────
                statsRow
                    .padding(.horizontal, Spacing.screenPadding)
                    .padding(.top, Spacing.xl)

                // ── Поездки ────────────────────────────────────
                Rule()
                    .padding(.horizontal, Spacing.screenPadding)
                    .padding(.top, Spacing.lg)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Мои путешествия").font(.Travello.h3).foregroundColor(.Travello.ink)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.screenPadding)
                    .padding(.top, Spacing.lg)

                    ForEach(Array(vm.routes.enumerated()), id: \.element.id) { idx, route in
                        TripRow(route: route, index: idx)
                            .padding(.horizontal, Spacing.screenPadding)
                            .opacity(vm.appeared ? 1 : 0)
                            .offset(y: vm.appeared ? 0 : 14)
                            .animation(Anim.spring.delay(Double(idx) * Anim.cardCascade), value: vm.appeared)
                        if idx < vm.routes.count - 1 {
                            SoftRule().padding(.horizontal, Spacing.screenPadding)
                        }
                    }
                }

                Spacer(minLength: Spacing.xxxl + 60)
            }
        }
        .background(Color.Travello.cream.ignoresSafeArea())
        .sheet(isPresented: $showSettings) { SettingsScreen() }
        .task { await vm.load() }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            StatCell(value: "\(vm.routes.count)", label: "поездок")
            Divider().frame(height: 36)
            StatCell(value: "\(vm.uniqueCities)", label: "городов")
            Divider().frame(height: 36)
            StatCell(value: vm.totalSpent, label: "потрачено")
        }
        .padding(.vertical, Spacing.md)
        .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.Travello.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.Travello.line, lineWidth: Stroke.hairline))
    }
}

private struct StatCell: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("Fraunces72pt-SemiBold", size: 22))
                .foregroundColor(.Travello.terra)
            Text(label).eyebrowSmall()
        }
        .frame(maxWidth: .infinity)
    }
}

// ─── Profile Cover ────────────────────────────────────────────

private struct ProfileCover: View {
    let name: String; let subtitle: String
    let onSettings: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(hex: 0xF4D1A6), .Travello.apricot],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 150)

            // Кнопка настроек
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.25)))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(Spacing.md)
            .padding(.top, 50)

            // Аватар
            Circle()
                .fill(LinearGradient(
                    colors: [Color.Travello.olive, Color(hex: 0x9FC4A8)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(Color.Travello.cream, lineWidth: 3))
                .offset(y: 32)
                .padding(.horizontal, Spacing.screenPadding)
        }
        .padding(.top, 50) // safe area

        VStack(alignment: .leading, spacing: 3) {
            Text(name).font(.Travello.h1).foregroundColor(.Travello.ink)
            Text(subtitle).font(.Travello.italic).foregroundColor(.Travello.mute)
        }
        .padding(.horizontal, Spacing.screenPadding)
        .padding(.top, Spacing.xl)
    }
}

// ─── ViewModel ────────────────────────────────────────────────

@MainActor final class ProfileViewModel: ObservableObject {
    @Published var routes   = [Route]()
    @Published var userName = "Путешественник"
    @Published var appeared = false

    var userSubtitle: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; f.locale = Locale(identifier: "ru_RU")
        return "с \(f.string(from: Date()))"
    }
    var uniqueCities: Int {
        Set(routes.flatMap { $0.days.compactMap(\.city) }).count
    }
    var totalSpent: String {
        let sum = routes.compactMap(\.totalCostEst).reduce(0, +)
        return sum >= 1000 ? "$\(String(format: "%.1f", sum/1000))k" : "$\(Int(sum))"
    }

    func load() async {
        async let r: [RouteDTO] = (try? await APIClient.shared.request(.listRoutes)) ?? []
        async let u: UserDTO?   =  try? await APIClient.shared.request(.authMe)
        let (rr, ur) = await (r, u)
        routes   = rr.map { RouteMapper.toRoute($0) }
        userName = ur?.displayName ?? "Путешественник"
        withAnimation(Anim.spring.delay(0.15)) { appeared = true }
    }
}

// ============================================================
// SETTINGS SCREEN
// ============================================================

struct SettingsScreen: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @AppStorage("preferredColorScheme") private var schemeRaw = "auto"
    @AppStorage("preferredLanguage")    private var language  = "ru"
    @State private var notifCheckin  = true
    @State private var notifDailyTip = true
    @State private var notifWeather  = false
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.xl) {

                    settingsGroup(title: "аккаунт") {
                        SettingsRow(label: "Email", value: "скрыт")
                        SoftRule()
                        SettingsRow(label: "Валюта", value: "USD", chevron: true)
                    }

                    settingsGroup(title: "интерфейс") {
                        // Тема
                        HStack {
                            Text("Тема").font(.Travello.bodyBold).foregroundColor(.Travello.ink)
                            Spacer()
                            Picker("", selection: $schemeRaw) {
                                Text("Авто").tag("auto")
                                Text("Светлая").tag("light")
                                Text("Тёмная").tag("dark")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                            .tint(.Travello.terra)
                        }
                        SoftRule()
                        // Язык
                        HStack {
                            Text("Язык").font(.Travello.bodyBold).foregroundColor(.Travello.ink)
                            Spacer()
                            Picker("", selection: $language) {
                                Text("Русский").tag("ru")
                                Text("English").tag("en")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                        }
                    }

                    settingsGroup(title: "уведомления") {
                        ToggleRow(label: "Регистрация на рейс", isOn: $notifCheckin)
                        SoftRule()
                        ToggleRow(label: "Советы дня", isOn: $notifDailyTip)
                        SoftRule()
                        ToggleRow(label: "Прогноз погоды", isOn: $notifWeather)
                    }

                    settingsGroup(title: "данные") {
                        SettingsRow(label: "Подключить Gmail", value: "→", chevron: false)
                        SoftRule()
                        SettingsRow(label: "Подключить iCloud Mail", value: "→", chevron: false)
                    }

                    // Выйти
                    Button {
                        showSignOutAlert = true
                    } label: {
                        Text("Выйти")
                            .font(.Travello.bodyBold)
                            .foregroundColor(Color.Travello.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Spacing.sm)
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .background(Color.Travello.cream.ignoresSafeArea())
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Настройки").font(.Travello.h3).foregroundColor(.Travello.ink)
                }
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .medium))
                            .foregroundColor(.Travello.ink)
                    }
                }
                #endif
            }
        }
        .alert("Выйти из аккаунта?", isPresented: $showSignOutAlert) {
            Button("Выйти", role: .destructive) {
                Haptics.tap(); appState.signOut()
            }
            Button("Отмена", role: .cancel) { }
        }
    }

    @ViewBuilder
    private func settingsGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            EyebrowLine(text: title)
            VStack(spacing: 0) { content() }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.Travello.paper))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.Travello.line, lineWidth: Stroke.hairline))
        }
    }
}

// ─── Settings subcomponents ──────────────────────────────────

private struct SettingsRow: View {
    let label: String; let value: String; var chevron: Bool = true
    var body: some View {
        HStack {
            Text(label).font(.Travello.bodyBold).foregroundColor(.Travello.ink)
            Spacer()
            Text(value).font(.Travello.italic).foregroundColor(.Travello.mute)
            if chevron {
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.Travello.tertiary)
            }
        }
        .padding(.vertical, Spacing.md)
    }
}

private struct ToggleRow: View {
    let label: String; @Binding var isOn: Bool
    var body: some View {
        HStack {
            Text(label).font(.Travello.bodyBold).foregroundColor(.Travello.ink)
            Spacer()
            TerraToggle(isOn: $isOn)
        }
        .padding(.vertical, Spacing.md)
    }
}
