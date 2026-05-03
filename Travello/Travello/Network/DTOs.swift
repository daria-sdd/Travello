import Foundation

// ============================================================
// API DTOs
// Зеркалят структуры из Kotlin backend (api/dto/Dtos.kt).
// Все опциональные поля помечены как Optional — backend
// может вернуть null если AI ещё не заполнил.
// ============================================================

// ─── User ────────────────────────────────────────────────────

struct UserDTO: Codable, Identifiable {
    let id: UUID
    let email: String?
    let displayName: String?
    let avatarUrl: String?
    let locale: String
    let currency: String
}

// ─── Auth ────────────────────────────────────────────────────

struct AuthExchangeRequest: Encodable {
    let firebaseIdToken: String
}

struct AuthExchangeResponse: Decodable {
    let token: String
    let user: UserDTO
}

// ─── Survey ──────────────────────────────────────────────────

struct CreateSurveyRequest: Encodable {
    let departFrom: String?
    let dateFrom: String?         // YYYY-MM-DD
    let dateTo: String?
    let flexibleDates: Bool
    let destinations: [DestinationRequestDTO]
    let budgetAmount: Double?
    let budgetCurrency: String
    let budgetIncludes: [String]
    let tags: [String]
    let extraWishes: String?
    let travellerCount: Int
    let travellerNotes: String?
}

struct DestinationRequestDTO: Encodable {
    let name: String
    let type: String              // country | city | region | any
}

struct SurveyResponseDTO: Decodable {
    let id: UUID
    let status: String            // pending | processing | completed | failed
    let createdAt: String
}

// ─── Route ───────────────────────────────────────────────────

struct RouteDTO: Codable, Identifiable {
    let id: UUID
    let surveyId: UUID
    let status: String            // draft | active | completed | archived
    let variantIndex: Int
    let variantLabel: String?
    let title: String?
    let summary: String?
    let coverImageUrl: String?
    let totalDays: Int?
    let totalCostEst: Double?
    let currency: String
    let days: [RouteDayDTO]
    let confirmedAt: String?
    let createdAt: String
}

struct RouteDayDTO: Codable, Identifiable {
    let id: UUID
    let dayNumber: Int
    let date: String?
    let city: String?
    let country: String?
    let countryCode: String?
    let summary: String?
    let weatherNote: String?
    let events: [RouteEventDTO]
}

struct RouteEventDTO: Codable, Identifiable {
    let id: UUID
    let eventType: String         // flight | accommodation | transport | activity | restaurant | free_time | note
    let sortOrder: Int
    let title: String?
    let description: String?
    let startsAt: String?
    let endsAt: String?
    let durationMin: Int?
    let locationName: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let imageUrl: String?
    let costEst: Double?
    let currency: String
    let isPrepaid: Bool
    let bookingRef: String?
    let externalSource: String?
    let aiTip: String?
}

// ─── Route edit ──────────────────────────────────────────────

struct RouteEditRequestDTO: Encodable {
    let message: String
}

struct RouteEditResponseDTO: Decodable {
    let route: RouteDTO
    let changeSummary: String
}

// ─── Booking ─────────────────────────────────────────────────

struct BookingDTO: Codable, Identifiable {
    let id: UUID
    let routeEventId: UUID?
    let status: String            // pending | confirmed | cancelled | completed
    let bookingRef: String?
    let providerName: String?
    let providerLogo: String?
    let bookingUrl: String?
    let bookedAt: String?
    let validFrom: String?
    let validTo: String?
    let amountPaid: Double?
    let currency: String
    let qrCodeUrl: String?
    let ticketPdfUrl: String?
}

struct CreateBookingRequestDTO: Encodable {
    let routeEventId: UUID?
    let providerName: String?
    let bookingRef: String?
    let bookingUrl: String?
    let validFrom: String?
    let validTo: String?
    let amountPaid: String?
    let currency: String?
}

// ─── Notifications ───────────────────────────────────────────

struct NotificationDTO: Codable, Identifiable {
    let id: UUID
    let type: String              // checkin_reminder | depart_reminder | daily_tip | ...
    let title: String
    let body: String
    let deepLink: String?
    let isRead: Bool
    let scheduledAt: String
    let routeId: UUID?
}

// ─── Devices ─────────────────────────────────────────────────

struct DeviceTokenRequestDTO: Encodable {
    let token: String
    let platform: String          // "ios"
}
