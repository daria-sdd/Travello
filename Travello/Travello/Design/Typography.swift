import SwiftUI

// ============================================================
// TYPOGRAPHY
// Заголовки — Fraunces (serif) с italic вариациями.
// Тело — Inter (sans-serif).
// Eyebrow — Inter с tracking и uppercase.
//
// Шрифты должны быть добавлены в Resources/Fonts/ и
// зарегистрированы в Info.plist через UIAppFonts.
// ============================================================

extension Font {

    enum Travello {

        // ── Display & Headlines (Fraunces) ───────────────────

        /// Огромный заголовок: «travello», hero-надписи. 38pt.
        static let display = Font.custom("Fraunces72pt-Light", size: 38)
            .leading(.tight)

        /// H1 — главные заголовки экранов. 24pt.
        static let h1 = Font.custom("Fraunces72pt-SemiBold", size: 24)
            .leading(.tight)

        /// H1 italic — акцентные части заголовков.
        static let h1Italic = Font.custom("Fraunces72pt-LightItalic", size: 24)
            .leading(.tight)

        /// H2 — заголовки разделов. 18pt.
        static let h2 = Font.custom("Fraunces72pt-SemiBold", size: 18)

        /// H3 — подзаголовки внутри карточек. 14pt.
        static let h3 = Font.custom("Fraunces72pt-SemiBold", size: 14)

        /// Italic-подсказки и слоганы.
        static let italic = Font.custom("Fraunces72pt-LightItalic", size: 13)

        /// Italic мелкий — для тегов времени и метаданных.
        static let italicSmall = Font.custom("Fraunces72pt-LightItalic", size: 11)

        /// Декоративный курсив для нумерации — 01, 02, 03.
        static let numeral = Font.custom("Fraunces72pt-LightItalic", size: 32)
            .weight(.light)

        /// Большая декоративная нумерация — на hero-обложках.
        static let numeralLarge = Font.custom("Fraunces72pt-LightItalic", size: 60)
            .weight(.light)

        // ── Body (Inter) ─────────────────────────────────────

        /// Основной текст. 14pt.
        static let body = Font.custom("Inter28pt-Regular", size: 14)

        /// Текст в карточках. 13pt.
        static let bodySmall = Font.custom("Inter28pt-Regular", size: 13)

        /// Подписи и captions. 11pt.
        static let caption = Font.custom("Inter28pt-Regular", size: 11)

        /// Жирный body — для emphasized текста.
        static let bodyBold = Font.custom("Inter28pt-Medium", size: 14)

        // ── Eyebrow (всё капсом, с tracking) ─────────────────

        /// Eyebrow — мелкие caps-надписи для секций.
        /// Tracking задаётся через `.kerning(...)` на View.
        /// Используй `.eyebrow()` modifier ниже.
        static let eyebrow = Font.custom("Inter28pt-Medium", size: 9)

        static let eyebrowSmall = Font.custom("Inter28pt-Medium", size: 8)

        // ── Buttons ──────────────────────────────────────────

        static let button = Font.custom("Inter28pt-Medium", size: 12)
            .uppercaseSmallCaps()

        // ── Numbers (для статистики и countdown) ─────────────

        /// Большие числа на hero — countdown, цифры в статистике.
        static let bigNumber = Font.custom("Fraunces72pt-LightItalic", size: 48)
            .leading(.tight)
    }
}

// ============================================================
// VIEW MODIFIERS
// Удобные модификаторы для типографики.
// ============================================================

extension View {

    /// Eyebrow-стиль: мелкие капсом, увеличенный tracking, mute цвет.
    func eyebrow(_ color: Color = Color.Travello.mute) -> some View {
        self
            .font(.Travello.eyebrow)
            .tracking(1.6)               // ≈ 0.18em для 9pt
            .textCase(.uppercase)
            .foregroundColor(color)
    }

    /// Маленький eyebrow.
    func eyebrowSmall(_ color: Color = Color.Travello.mute) -> some View {
        self
            .font(.Travello.eyebrowSmall)
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundColor(color)
    }

    /// Italic-курсив с цветом terra (для акцентов в заголовках).
    func italicAccent() -> some View {
        self
            .font(.Travello.h1Italic)
            .foregroundColor(.Travello.terra)
    }

    /// Кнопочный текст.
    func buttonText() -> some View {
        self
            .font(.Travello.button)
            .tracking(0.6)
    }
}

// ============================================================
// FONT REGISTRATION
// Должно вызваться один раз при старте приложения (в App init).
// ============================================================

enum FontRegistrar {

    static func registerAll() {
        let fonts = [
            "Fraunces_72pt-Light",
            "Fraunces_72pt-Regular",
            "Fraunces_72pt-SemiBold",
            "Fraunces_72pt-LightItalic",
            "Fraunces_72pt-Italic",
            "Inter_28pt-Regular",
            "Inter_28pt-Medium",
            "Inter_28pt-SemiBold",
        ]
        for name in fonts {
            registerFont(name: name, ext: "ttf")
        }
    }

    private static func registerFont(name: String, ext: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("⚠️ Font \(name).\(ext) not found in bundle")
            return
        }
        var error: Unmanaged<CFError>?
        guard CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) else {
            print("⚠️ Failed to register \(name): \(String(describing: error))")
            return
        }
    }
}
