import SwiftUI

// ============================================================
// ONBOARDING DATA
// Контент трёх страниц онбординга.
// ============================================================

struct OnboardingPage: Identifiable {
    let id: Int
    let number: String              // "01", "02", "03"
    let pageLabel: String           // "первый разворот"
    let title: AttributedString     // с italic-акцентом
    let subtitle: String            // основной текст
    let illustration: Illustration

    enum Illustration {
        case search    // лупа + точки
        case map       // карта с пинами
        case bell      // колокольчик + уведомления
    }
}

extension OnboardingPage {
    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            number: "01",
            pageLabel: "первый разворот",
            title: makeTitle(prefix: "Не знаете\nкуда ", italicPart: "поехать?"),
            subtitle: "Скажите «хочу к морю в октябре, бюджет 2000» — и ИИ найдёт направление с лучшими ценами и тёплой водой.",
            illustration: .search,
        ),
        OnboardingPage(
            id: 1,
            number: "02",
            pageLabel: "второй разворот",
            title: makeTitle(prefix: "Реальные рейсы\nи ", italicPart: "тёплые отели"),
            subtitle: "Каждое место в плане настоящее. Цены, время, наличие проверены прямо сейчас. Открыли карточку — нажали — забронировали.",
            illustration: .map,
        ),
        OnboardingPage(
            id: 2,
            number: "03",
            pageLabel: "третий разворот",
            title: makeTitle(prefix: "Друг ", italicPart: "в кармане"),
            subtitle: "Подскажу когда регистрироваться, во сколько выезжать в аэропорт, и куда сходить если внезапно пошёл дождь.",
            illustration: .bell,
        ),
    ]

    /// Собирает заголовок: обычная часть + italic-акцент в цвете terra
    private static func makeTitle(prefix: String, italicPart: String) -> AttributedString {
        var result = AttributedString(prefix)
        result.font = .Travello.h1

        var accent = AttributedString(italicPart)
        accent.font = .Travello.h1Italic
        accent.foregroundColor = .Travello.terra

        result += accent
        return result
    }
}
