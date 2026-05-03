import SwiftUI
import AuthenticationServices

// ============================================================
// AUTH VIEW
// Экран авторизации:
// — анимированный фон с самолётом
// — логотип travello (Fraunces light)
// — слоган "путешествия, которые помнят"
// — кнопка Apple Sign In
// — мелкий disclaimer
// ============================================================

struct AuthScreen: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var auth = AuthService()

    @State private var isAuthenticating = false
    @State private var errorMessage: String?
    @State private var showError = false

    // Анимация появления контента
    @State private var contentReady = false

    var body: some View {
        ZStack {
            // Анимированный фон
            AuthBackground()

            // Контент
            VStack {
                Spacer(minLength: 80)

                // ─── Лого + слоган ───
                VStack(spacing: 14) {
                    Text("travello")
                        .font(.Travello.display)
                        .foregroundColor(.Travello.ink)
                        .opacity(contentReady ? 1 : 0)
                        .offset(y: contentReady ? 0 : 12)

                    Rectangle()
                        .fill(Color.Travello.ink)
                        .frame(width: 40, height: 0.5)
                        .opacity(contentReady ? 1 : 0)
                        .scaleEffect(x: contentReady ? 1 : 0.3, anchor: .center)

                    Text("путешествия,\nкоторые помнят")
                        .font(.Travello.italic)
                        .foregroundColor(.Travello.inkSoft)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .opacity(contentReady ? 1 : 0)
                        .offset(y: contentReady ? 0 : 8)
                }

                Spacer()

                // ─── Кнопка + disclaimer ───
                VStack(spacing: 14) {
                    DarkButton(
                        title: "Войти через Apple",
                        action: { Task { await signIn() } },
                        systemIcon: "applelogo",
                    )
                    .opacity(isAuthenticating ? 0.5 : 1.0)
                    .disabled(isAuthenticating)

                    Text("продолжая, вы соглашаетесь с\nусловиями и политикой")
                        .font(.Travello.italicSmall)
                        .foregroundColor(.Travello.mute)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .opacity(contentReady ? 1 : 0)
                .offset(y: contentReady ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                contentReady = true
            }
        }
        .alert("Не удалось войти", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Попробуйте ещё раз через минуту")
        }
    }

    // ─── Sign In Logic ───────────────────────────────────────

    private func signIn() async {
        guard !isAuthenticating else { return }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let success = try await auth.signInWithApple()
            if success {
                Haptics.success()
                // Первый вход → онбординг, повторный → сразу в приложение
                let hasSeenOnboarding = UserDefaults.standard
                    .bool(forKey: "travello.onboarding.completed")
                appState.didCompleteAuth(hasSeenOnboarding: hasSeenOnboarding)
            }
        } catch {
            Haptics.error()
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            showError = true
        }
    }
}

// ─── PREVIEW ─────────────────────────────────────────────────

#Preview {
    AuthScreen()
        .environmentObject(AppState())
}

#Preview("Dark") {
    AuthScreen()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
