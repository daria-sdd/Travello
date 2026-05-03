import SwiftUI
import Foundation

// ============================================================
// SURVEY MODELS
// ============================================================

enum SurveyStep: Int, CaseIterable {
    case dates = 0, destinations, budget, tags, wishes

    var plainPrefix: String {
        switch self {
        case .dates:        return "Когда "
        case .destinations: return "Куда "
        case .budget:       return "Какой "
        case .tags:         return "Что "
        case .wishes:       return "Что-то "
        }
    }

    var italicAccent: String {
        switch self {
        case .dates:        return "летим?"
        case .destinations: return "летим?"
        case .budget:       return "бюджет?"
        case .tags:         return "любим?"
        case .wishes:       return "ещё?"
        }
    }

    var eyebrow: String {
        "шаг \(String(format: "%02d", rawValue + 1)) · \(String(format: "%02d", SurveyStep.allCases.count))"
    }

    var isSkippable: Bool {
        switch self {
        case .destinations, .budget, .wishes: return true
        default: return false
        }
    }

    var next: SurveyStep? { SurveyStep(rawValue: rawValue + 1) }
}

struct SurveyDestination: Identifiable, Equatable {
    let id: UUID
    var name: String
    var type: DestinationType

    init(id: UUID = UUID(), name: String, type: DestinationType = .any) {
        self.id = id; self.name = name; self.type = type
    }

    enum DestinationType: String, CaseIterable {
        case country = "Страна"
        case city    = "Город"
        case region  = "Регион"
        case any     = "Любое"
    }
}

struct SurveyBudget: Equatable {
    var amount: Double?
    var currency: String = "USD"
    var includes: Set<BudgetItem> = [.flights, .accommodation]

    enum BudgetItem: String, CaseIterable, Identifiable {
        case flights = "Перелёты", accommodation = "Проживание",
             food = "Питание", activities = "Активности"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .flights: return "airplane"
            case .accommodation: return "bed.double"
            case .food: return "fork.knife"
            case .activities: return "ticket"
            }
        }
    }
}

struct SurveyTag: Identifiable, Equatable {
    let id: String; let label: String; let emoji: String

    static let all: [SurveyTag] = [
        .init(id: "beach",        label: "пляж",          emoji: "🏖"),
        .init(id: "history",      label: "история",        emoji: "🏛"),
        .init(id: "food",         label: "местная кухня",  emoji: "🍜"),
        .init(id: "nature",       label: "природа",        emoji: "🌿"),
        .init(id: "architecture", label: "архитектура",     emoji: "🏰"),
        .init(id: "shopping",     label: "шопинг",         emoji: "🛍"),
        .init(id: "nightlife",    label: "ночная жизнь",   emoji: "🎶"),
        .init(id: "spa",          label: "спа и релакс",   emoji: "🧖"),
        .init(id: "museums",      label: "музеи",          emoji: "🖼"),
        .init(id: "adventure",    label: "приключения",    emoji: "🧗"),
        .init(id: "wine",         label: "вино и гастро",  emoji: "🍷"),
        .init(id: "family",       label: "с детьми",       emoji: "👨‍👩‍👧"),
    ]
}

final class SurveyState: ObservableObject {
    // Step 1
    @Published var dateFrom: Date?
    @Published var dateTo: Date?
    @Published var flexibleDates: Bool = false
    @Published var departFrom: String = ""
    // Step 2
    @Published var destinations: [SurveyDestination] = []
    // Step 3
    @Published var budget = SurveyBudget()
    // Step 4
    @Published var selectedTagIds: Set<String> = []
    @Published var customTag: String = ""
    // Step 5
    @Published var extraWishes: String = ""
    @Published var travellerCount: Int = 1

    func canProceed(from step: SurveyStep) -> Bool {
        switch step {
        case .dates: return dateFrom != nil || !departFrom.trimmingCharacters(in: .whitespaces).isEmpty
        case .tags:  return true
        default:     return true
        }
    }

    func toRequest() -> CreateSurveyRequest {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return CreateSurveyRequest(
            departFrom:     departFrom.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            dateFrom:       dateFrom.map { fmt.string(from: $0) },
            dateTo:         dateTo.map   { fmt.string(from: $0) },
            flexibleDates:  flexibleDates,
            destinations:   destinations.map { DestinationRequestDTO(name: $0.name, type: $0.type.rawValue.lowercased()) },
            budgetAmount:   budget.amount,
            budgetCurrency: budget.currency,
            budgetIncludes: budget.includes.map { $0.rawValue.lowercased() },
            tags:           Array(selectedTagIds) + (customTag.nilIfEmpty.map { [$0] } ?? []),
            extraWishes:    extraWishes.nilIfEmpty,
            travellerCount: travellerCount,
            travellerNotes: nil
        )
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
