import Foundation

// ============================================================
// API ENDPOINTS
// Централизованное описание всех endpoint'ов backend'а.
// Один источник правды — изменился URL → меняем здесь.
// ============================================================

enum Endpoint {

    // ── Auth ─────────────────────────────────────────────────
    /// Обмен Firebase token → внутренний JWT
    case authExchange

    /// Текущий пользователь
    case authMe

    // ── Surveys ──────────────────────────────────────────────
    /// Создать survey, запустить генерацию
    case createSurvey

    /// Статус survey
    case surveyStatus(id: UUID)

    /// SSE поток прогресса
    case surveyStream(id: UUID)

    // ── Routes ───────────────────────────────────────────────
    /// Все маршруты пользователя
    case listRoutes

    /// Активный маршрут
    case activeRoute

    /// Конкретный маршрут
    case route(id: UUID)

    /// 3 варианта для конкретного survey
    case routeVariants(surveyId: UUID)

    /// Подтвердить маршрут (draft → active)
    case confirmRoute(id: UUID)

    /// NLP правка маршрута через чат
    case editRoute(id: UUID)

    // ── Bookings ─────────────────────────────────────────────
    case listBookings
    case booking(id: UUID)
    case createBooking
    case updateBooking(id: UUID)

    // ── Notifications ────────────────────────────────────────
    case listNotifications(unreadOnly: Bool)
    case markRead(id: UUID)

    // ── Devices ──────────────────────────────────────────────
    case registerDevice
    case removeDevice(token: String)

    // ─────────────────────────────────────────────────────────

    var path: String {
        switch self {
        case .authExchange:                 return "/api/v1/auth/exchange"
        case .authMe:                       return "/api/v1/auth/me"

        case .createSurvey:                 return "/api/v1/surveys"
        case .surveyStatus(let id):         return "/api/v1/surveys/\(id)"
        case .surveyStream(let id):         return "/api/v1/surveys/\(id)/stream"

        case .listRoutes:                   return "/api/v1/routes"
        case .activeRoute:                  return "/api/v1/routes/active"
        case .route(let id):                return "/api/v1/routes/\(id)"
        case .routeVariants(let sid):       return "/api/v1/surveys/\(sid)/routes"
        case .confirmRoute(let id):         return "/api/v1/routes/\(id)/confirm"
        case .editRoute(let id):            return "/api/v1/routes/\(id)/edit"

        case .listBookings:                 return "/api/v1/bookings"
        case .booking(let id):              return "/api/v1/bookings/\(id)"
        case .createBooking:                return "/api/v1/bookings"
        case .updateBooking(let id):        return "/api/v1/bookings/\(id)"

        case .listNotifications(let unread):
            return "/api/v1/notifications" + (unread ? "?unreadOnly=true" : "")
        case .markRead(let id):             return "/api/v1/notifications/\(id)/read"

        case .registerDevice:               return "/api/v1/devices"
        case .removeDevice(let token):      return "/api/v1/devices/\(token)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .authExchange,
             .createSurvey,
             .confirmRoute,
             .editRoute,
             .createBooking,
             .markRead,
             .registerDevice:
            return .post

        case .updateBooking:
            return .put

        case .removeDevice:
            return .delete

        default:
            return .get
        }
    }
}

enum HTTPMethod: String {
    case get    = "GET"
    case post   = "POST"
    case put    = "PUT"
    case delete = "DELETE"
}
