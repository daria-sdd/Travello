import Foundation
import AuthenticationServices
import CryptoKit

// ============================================================
// AUTH SERVICE
// Apple Sign In flow:
// 1. Запрашиваем у Apple identity token
// 2. Передаём его в Firebase Auth (на бэкенде или через iOS SDK)
// 3. Получаем Firebase ID token
// 4. Обмениваем на наш JWT через POST /auth/exchange
// 5. Сохраняем JWT в Keychain
//
// Для упрощения MVP: Firebase iOS SDK требует много настройки,
// поэтому здесь логика готова под прямую отправку Apple identity token
// на бэкенд, который сам сделает обмен на Firebase token.
// ============================================================

@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var error: String?

    private var currentNonce: String?
    private var continuation: CheckedContinuation<Bool, Error>?

    /// Запустить Apple Sign In flow.
    /// Возвращает true если успешно вошли, false если отменено.
    func signInWithApple() async throws -> Bool {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    /// Выйти — очищаем Keychain и состояние.
    func signOut() {
        KeychainService.clearAll()
    }

    // ─── Private: backend exchange ───────────────────────────

    private func exchangeWithBackend(
        appleIdentityToken: String,
        nonce: String,
        displayName: String?
    ) async throws {
        // На бэкенде уже есть Firebase Auth — он сам валидирует Apple token
        // и выдаёт нам JWT. См. SecurityConfig.kt + AuthController в Kotlin.

        struct ExchangeRequest: Encodable {
            let appleIdentityToken: String
            let nonce: String
            let displayName: String?
        }

        struct ExchangeResponse: Decodable {
            let token: String
            let user: UserDTO
        }

        let request = ExchangeRequest(
            appleIdentityToken: appleIdentityToken,
            nonce: nonce,
            displayName: displayName,
        )

        let response: ExchangeResponse = try await APIClient.shared.request(
            .authExchange,
            body: request,
        )

        // Сохраняем токены и user ID в Keychain
        KeychainService.save(response.token,            for: .authToken)
        KeychainService.save(response.user.id.uuidString, for: .userId)
    }

    // ─── Crypto helpers (для Apple Sign In nonce) ────────────

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                guard errorCode == errSecSuccess else {
                    fatalError("Unable to generate nonce: \(errorCode)")
                }
                return random
            }

            for random in randoms where remainingLength > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// ============================================================
// ASAuthorizationControllerDelegate
// ============================================================

extension AuthService: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let tokenData = credential.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                continuation?.resume(throwing: AuthError.invalidCredential)
                continuation = nil
                return
            }

            let displayName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
                .nilIfEmpty

            do {
                try await exchangeWithBackend(
                    appleIdentityToken: identityToken,
                    nonce: nonce,
                    displayName: displayName,
                )
                continuation?.resume(returning: true)
            } catch {
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                continuation?.resume(returning: false)
            } else {
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }
}

// ============================================================
// ASAuthorizationControllerPresentationContextProviding
// ============================================================

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        // Возвращаем активное окно. На главном потоке.
        DispatchQueue.main.sync {
            (UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.windows.first(where: \.isKeyWindow) }
                .first) ?? ASPresentationAnchor()
        }
    }
}

// ============================================================
// ERRORS
// ============================================================

enum AuthError: LocalizedError {
    case invalidCredential
    case noToken
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Не удалось получить данные Apple ID"
        case .noToken:           return "Сервер не вернул токен"
        case .userCancelled:     return "Вход отменён"
        }
    }
}

// ============================================================
// SMALL HELPER
// ============================================================

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
