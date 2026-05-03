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
        Task { await checkAuth() }
    }

    @MainActor
    func checkAuth() async {
        // TODO: проверить Keychain на наличие JWT
        // и валидность токена через API call /auth/me
        try? await Task.sleep(for: .milliseconds(300))
        authStage = .unauthenticated
    }

    @MainActor
    func didCompleteAuth(hasSeenOnboarding: Bool) {
        authStage = hasSeenOnboarding ? .authenticated : .onboarding
    }

    @MainActor
    func didCompleteOnboarding() {
        authStage = .authenticated
    }

    @MainActor
    func signOut() {
        // TODO: очистить Keychain
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
