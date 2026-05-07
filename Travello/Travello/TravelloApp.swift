import SwiftUI
import Combine

// ============================================================
// TRAVELLO APP
// Точка входа iOS приложения.
// ============================================================

@main
struct TravelloApp: App {

    @StateObject private var appState = AppState()
    @AppStorage("preferredColorScheme") private var schemeRaw: String = "auto"

    init() {
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
        default:      return nil
        }
    }
}

// ============================================================
// APP STATE
// ============================================================

final class AppState: ObservableObject {
    @Published var authStage: AuthStage = .checking
    @Published var selectedTab: AppTab = .home

    enum AuthStage {
        case checking
        case unauthenticated
        case onboarding
        case authenticated
    }

    init() {
        Task { await checkAuth() }
    }

    @MainActor
    func checkAuth() async {
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
        authStage = .unauthenticated
    }
}

// ============================================================
// ROOT VIEW
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
// PLACEHOLDERS
// ============================================================

typealias AuthView = AuthScreen
typealias OnboardingView = OnboardingScreen

struct MainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch appState.selectedTab {
                case .home:    HomeScreen()
                case .trip:    ActiveTripScreen()
                case .profile: ProfileScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TravelloTabBar(selection: $appState.selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}
