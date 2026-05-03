import Foundation
import CoreLocation

// ============================================================
// ROUTE MODELS
// Доменные объекты маршрута — чистые Swift-структуры.
// Конвертируются из DTO через RouteMapper.
// ============================================================

// ─── Route ───────────────────────────────────────────────────

struct Route: Identifiable, Equatable {
    let id:            UUID
    let surveyId:      UUID
    let status:        RouteStatus
    let variantIndex:  Int
    let variantLabel:  String?
    let title:         String
    let summary:       String?
    let coverImageUrl: String?
    let totalDays:     Int
    let totalCostEst:  Double?
    let currency:      String
    let days:          [RouteDay]
    let confirmedAt:   Date?
    let createdAt:     Date

    var isActive:  Bool { status == .active }
    var isDraft:   Bool { status == .draft  }

    /// Самое ближайшее событие с датой — для countdown.
    var nextEvent: RouteEvent? {
        let now = Date()
        return days
            .flatMap(\.events)
            .filter { $0.startsAt != nil && ($0.startsAt! > now) }
            .sorted { $0.startsAt! < $1.startsAt! }
            .first
    }
}

enum RouteStatus: String {
    case draft, active, completed, archived
}

// ─── Route Day ───────────────────────────────────────────────

struct RouteDay: Identifiable, Equatable {
    let id:          UUID
    let dayNumber:   Int
    let date:        Date?
    let city:        String?
    let country:     String?
    let countryCode: String?
    let summary:     String?
    let weatherNote: String?
    let events:      [RouteEvent]

    var displayDate: String? {
        guard let date else { return nil }
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: date)
    }

    var shortDayOfWeek: String? {
        guard let date else { return nil }
        let f = DateFormatter()
        f.dateFormat = "EE"
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: date).lowercased()
    }
}

// ─── Route Event ─────────────────────────────────────────────

struct RouteEvent: Identifiable, Equatable {
    let id:           UUID
    let eventType:    EventType
    let sortOrder:    Int
    let title:        String?
    let description:  String?
    let startsAt:     Date?
    let endsAt:       Date?
    let durationMin:  Int?
    let locationName: String?
    let address:      String?
    let coordinate:   CLLocationCoordinate2D?
    let imageUrl:     String?
    let costEst:      Double?
    let currency:     String
    let isPrepaid:    Bool
    let bookingRef:   String?
    let aiTip:        String?

    static func == (lhs: RouteEvent, rhs: RouteEvent) -> Bool { lhs.id == rhs.id }

    var timeString: String? {
        guard let date = startsAt else { return nil }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    var durationString: String? {
        guard let min = durationMin else { return nil }
        if min < 60 { return "\(min) мин" }
        let h = min / 60; let m = min % 60
        return m == 0 ? "\(h) ч" : "\(h) ч \(m) мин"
    }

    var costString: String? {
        guard let cost = costEst else { return nil }
        if cost == 0 { return "бесплатно" }
        return "$\(Int(cost))"
    }
}

enum EventType: String {
    case flight, accommodation, transport, activity, restaurant, freeTime, note

    var label: String {
        switch self {
        case .flight:         return "перелёт"
        case .accommodation:  return "проживание"
        case .transport:      return "транспорт"
        case .activity:       return "активность"
        case .restaurant:     return "ресторан"
        case .freeTime:       return "свободное время"
        case .note:           return "заметка"
        }
    }

    var icon: String {
        switch self {
        case .flight:         return "airplane"
        case .accommodation:  return "bed.double"
        case .transport:      return "car"
        case .activity:       return "ticket"
        case .restaurant:     return "fork.knife"
        case .freeTime:       return "sun.max"
        case .note:           return "text.bubble"
        }
    }

    var accentColor: String {
        switch self {
        case .flight:         return "terra"
        case .accommodation:  return "olive"
        case .restaurant:     return "apricot"
        case .activity:       return "terra"
        default:              return "mute"
        }
    }
}

// ─── MAPPER ──────────────────────────────────────────────────

enum RouteMapper {

    static func toRoute(_ dto: RouteDTO) -> Route {
        Route(
            id:            dto.id,
            surveyId:      dto.surveyId,
            status:        RouteStatus(rawValue: dto.status) ?? .draft,
            variantIndex:  dto.variantIndex,
            variantLabel:  dto.variantLabel,
            title:         dto.title ?? "Маршрут",
            summary:       dto.summary,
            coverImageUrl: dto.coverImageUrl,
            totalDays:     dto.totalDays ?? 0,
            totalCostEst:  dto.totalCostEst,
            currency:      dto.currency,
            days:          dto.days.map { toDay($0) },
            confirmedAt:   dto.confirmedAt.flatMap { parseISO($0) },
            createdAt:     parseISO(dto.createdAt) ?? Date()
        )
    }

    static func toDay(_ dto: RouteDayDTO) -> RouteDay {
        RouteDay(
            id:          dto.id,
            dayNumber:   dto.dayNumber,
            date:        dto.date.flatMap { parseDate($0) },
            city:        dto.city,
            country:     dto.country,
            countryCode: dto.countryCode,
            summary:     dto.summary,
            weatherNote: dto.weatherNote,
            events:      dto.events
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { toEvent($0) }
        )
    }

    static func toEvent(_ dto: RouteEventDTO) -> RouteEvent {
        let coord: CLLocationCoordinate2D? = {
            guard let lat = dto.latitude, let lng = dto.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }()

        return RouteEvent(
            id:           dto.id,
            eventType:    EventType(rawValue: dto.eventType) ?? .note,
            sortOrder:    dto.sortOrder,
            title:        dto.title,
            description:  dto.description,
            startsAt:     dto.startsAt.flatMap { parseISO($0) },
            endsAt:       dto.endsAt.flatMap   { parseISO($0) },
            durationMin:  dto.durationMin,
            locationName: dto.locationName,
            address:      dto.address,
            coordinate:   coord,
            imageUrl:     dto.imageUrl,
            costEst:      dto.costEst,
            currency:     dto.currency,
            isPrepaid:    dto.isPrepaid,
            bookingRef:   dto.bookingRef,
            aiTip:        dto.aiTip
        )
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    static func parseISO(_ s: String) -> Date? {
        isoFormatter.date(from: s) ??
        ISO8601DateFormatter().date(from: s)
    }

    static func parseDate(_ s: String) -> Date? {
        dateFormatter.date(from: s)
    }
}
