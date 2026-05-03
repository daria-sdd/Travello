import SwiftUI

// ============================================================
// TRAVELLO APP
// Точка входа iOS приложения.
// ============================================================

@main
struct TravelloApp: App {

    @StateObject private var appState = AppState()
    @AppStorage("preferredColorScheme") private var schemeRaw: String = "auto"

    init() {
        // Регистрируем кастомные шрифты при старте
        FontRegistrar.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(colorScheme)
                .tint(.Travello.terra)
        }
    }

    private var colorScheme: ColorScheme? {
        switch schemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil   // .auto = follow system
        }
    }
}

// ============================================================
// APP STATE
// Глобальное состояние приложения — auth, выбранный таб и т.д.
// ============================================================

final class AppState: ObservableObject {
    @Published var authStage: AuthStage = .checking
    @Published var selectedTab: AppTab = .home

    enum AuthStage {
        case checking          // проверяем сохранённый токен
        case unauthenticated   // показать Auth + Onboarding
        case onboarding        // показать Onboarding
        case authenticated     // показать главное приложение
    }

    init() {
        // Пробрасываем 401 на выход из аккаунта
        APIClient.shared.onUnauthorized = { [weak self] in
            Task { @MainActor in self?.signOut() }
        }
        Task { await checkAuth() }
    }

    @MainActor
    func checkAuth() async {
        guard KeychainService.hasToken else {
            authStage = .unauthenticated
            return
        }

        do {
            // Верифицируем токен через /auth/me
            let _: UserDTO = try await APIClient.shared.request(.authMe)
            let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
            authStage = hasSeenOnboarding ? .authenticated : .onboarding
        } catch APIError.unauthorized {
            KeychainService.clearAll()
            authStage = .unauthenticated
        } catch {
            // Оффлайн или временная ошибка — пускаем внутрь с кешированным токеном
            let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
            authStage = hasSeenOnboarding ? .authenticated : .onboarding
        }
    }

    @MainActor
    func didCompleteAuth(hasSeenOnboarding: Bool) {
        authStage = hasSeenOnboarding ? .authenticated : .onboarding
    }

    @MainActor
    func didCompleteOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        authStage = .authenticated
    }

    @MainActor
    func signOut() {
        KeychainService.clearAll()
        APIClient.shared.onUnauthorized = nil
        authStage = .unauthenticated
    }
}

// ============================================================
// ROOT VIEW
// Переключает корневой экран в зависимости от auth-стадии.
// ============================================================

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.Travello.cream.ignoresSafeArea()

            switch appState.authStage {
            case .checking:
                SplashView()
            case .unauthenticated:
                AuthView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingView()
                    .transition(.opacity)
            case .authenticated:
                MainView()
                    .transition(.opacity)
            }
        }
        .animation(Anim.smooth, value: appState.authStage)
    }
}

// ============================================================
// SPLASH
// Минимальный лого-экран на момент проверки auth.
// ============================================================

struct SplashView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("travello")
                .font(.Travello.display)
                .foregroundColor(.Travello.ink)
            Spacer()
        }
    }
}

// ============================================================
// PLACEHOLDERS — будут заменены реальными View в следующих файлах
// ============================================================

/// Реальная реализация — в Features/Auth/AuthScreen.swift
typealias AuthView = AuthScreen

/// Реальная реализация — в Features/Onboarding/OnboardingScreen.swift
typealias OnboardingView = OnboardingScreen

struct MainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            // Контент активного таба
            Group {
                switch appState.selectedTab {
                case .home:    HomeScreen()
                case .trip:    ActiveTripScreen()
                case .profile: ProfileScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Кастомный TabBar поверх контента
            TravelloTabBar(selection: $appState.selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}
