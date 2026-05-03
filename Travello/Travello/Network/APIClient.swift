import Foundation

// ============================================================
// API CLIENT
// Тонкая обёртка над URLSession с async/await.
// Автоматически:
// — добавляет Authorization: Bearer <jwt>
// — кодирует body в JSON
// — декодирует ответ
// — обрабатывает 401 → выкидывает в auth flow
// ============================================================

@MainActor
final class APIClient {
    static let shared = APIClient()

    /// Базовый URL — для разработки локально, для prod заменить.
    /// В будущем вынести в xcconfig.
    private let baseURL: URL

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Колбэк при 401 — родительский слой должен очистить auth и перебросить на экран входа.
    var onUnauthorized: (() -> Void)?

    private init() {
        // Берём URL из Info.plist (ключ TRAVELLO_API_URL), fallback — localhost
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "TRAVELLO_API_URL") as? String,
           let url = URL(string: urlString) {
            self.baseURL = url
        } else {
            self.baseURL = URL(string: "http://localhost:8080")!
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        dec.keyDecodingStrategy  = .useDefaultKeys
        self.decoder = dec

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.keyEncodingStrategy  = .useDefaultKeys
        self.encoder = enc
    }

    // ─── Public API ──────────────────────────────────────────

    /// GET / DELETE / прочее без тела
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        as type: T.Type = T.self
    ) async throws -> T {
        let request = try buildRequest(endpoint, body: Optional<EmptyBody>.none)
        return try await execute(request)
    }

    /// POST / PUT с телом
    func request<Body: Encodable, T: Decodable>(
        _ endpoint: Endpoint,
        body: Body,
        as type: T.Type = T.self
    ) async throws -> T {
        let request = try buildRequest(endpoint, body: body)
        return try await execute(request)
    }

    /// Запрос без декодирования ответа (например, для HTTP 204)
    func requestVoid(_ endpoint: Endpoint) async throws {
        let request = try buildRequest(endpoint, body: Optional<EmptyBody>.none)
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    func requestVoid<Body: Encodable>(
        _ endpoint: Endpoint,
        body: Body
    ) async throws {
        let request = try buildRequest(endpoint, body: body)
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // ─── Private ─────────────────────────────────────────────

    private func buildRequest<Body: Encodable>(
        _ endpoint: Endpoint,
        body: Body?
    ) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(endpoint.path)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Bearer token из Keychain
        if let token = KeychainService.read(.authToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // Печатаем ответ в дев-режиме чтобы быстро находить ошибки декодирования
            #if DEBUG
            if let str = String(data: data, encoding: .utf8) {
                print("⚠️ Decode failed for \(T.self):\n\(str)")
            }
            #endif
            throw APIError.decodingFailed(error)
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return
        case 401:
            onUnauthorized?()
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 400...499:
            throw APIError.clientError(http.statusCode)
        case 500...599:
            throw APIError.serverError(http.statusCode)
        default:
            throw APIError.unknown(http.statusCode)
        }
    }
}

// ============================================================
// ERRORS
// ============================================================

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case clientError(Int)
    case serverError(Int)
    case decodingFailed(Error)
    case unknown(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:        return "Некорректный ответ сервера"
        case .unauthorized:           return "Требуется авторизация"
        case .forbidden:              return "Доступ запрещён"
        case .notFound:               return "Не найдено"
        case .clientError(let code):  return "Ошибка запроса (\(code))"
        case .serverError(let code):  return "Ошибка сервера (\(code))"
        case .decodingFailed:         return "Не удалось обработать ответ"
        case .unknown(let code):      return "Неизвестная ошибка (\(code))"
        }
    }

    /// Сообщение для показа пользователю — без технических деталей.
    var userFacingMessage: String {
        switch self {
        case .unauthorized:
            return "Сессия истекла, войдите снова"
        case .serverError, .unknown:
            return "Что-то пошло не так. Попробуйте ещё раз через минуту"
        case .decodingFailed:
            return "Не удалось обработать данные"
        default:
            return errorDescription ?? "Ошибка"
        }
    }
}

// ============================================================
// HELPERS
// ============================================================

struct EmptyBody: Encodable {}
struct EmptyResponse: Decodable {}
