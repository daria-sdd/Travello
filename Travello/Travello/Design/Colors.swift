import SwiftUI

// ============================================================
// COLORS
// Палитра travello — кремово-терракотовая, тёплая.
// Все цвета адаптивны к светлой / тёмной теме через UIColor.
// ============================================================

extension Color {

    enum Travello {

        // ── Backgrounds ──────────────────────────────────────

        /// Основной фон приложения. Кремовый днём, тёплый чёрный ночью.
        static let cream = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: 0x1A1410)
                : UIColor(hex: 0xFAF6F1)
        })

        /// Вторичный фон — для карточек и поверхностей.
        static let sand = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: 0x231C13)
                : UIColor(hex: 0xF5EBDC)
        })

        /// Бумага — приподнятые карточки, hero-блоки.
        static let paper = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: 0x2D2419)
                : UIColor(hex: 0xFFFFFF)
        })

        /// Высокая поверхность — модалки, шторки.
        static let elevated = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: 0x3A2F22)
                : UIColor(hex: 0xFFFFFF)
        })

        // ── Text ─────────────────────────────────────────────

        /// Основной текст — почти-чёрный с тёплым подтоном.
        static let ink = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: 0xF4EBDD)
                : UIColor(hex: 0x2A1F12)
        })

        /// Вторичный текст — для подписей и метаданных.
        static let inkSoft = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: 0xC9B89A)
                : UIColor(hex: 0x4A3B28)
        })

        /// Приглушённый текст — eyebrow-надписи, captions.
        static let mute = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: 0xB5A48E)
                : UIColor(hex: 0x7A6B58)
        })

        /// Третичный текст — disabled и фоновые подсказки.
        static let tertiary = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: 0x7A6B58)
                : UIColor(hex: 0xA89989)
        })

        // ── Accents ──────────────────────────────────────────

        /// Главный акцент — терракота / закат.
        static let terra = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: 0xE89968)
                : UIColor(hex: 0xD8743A)
        })

        /// Светлый оранжевый — для градиентов и подсветки.
        static let apricot = Color(uiColor: UIColor(hex: 0xE89968))

        /// Тёплый кремово-золотой — для подложек и теней.
        static let honey = Color(uiColor: UIColor(hex: 0xE0BC8E))

        /// Оливковый — успешные состояния, статус online.
        static let olive = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: 0x9FC4A8)
                : UIColor(hex: 0x5A8C66)
        })

        /// Жжёный — глубокие акценты, hover.
        static let burnt = Color(uiColor: UIColor(hex: 0x8B5424))

        // ── Lines & dividers ─────────────────────────────────

        /// Линии-разделители (тонкие, заметные).
        static let line = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: 0x3A2F22)
                : UIColor(hex: 0xE8DDD0)
        })

        /// Линии-волоски (минимальная видимость).
        static let hairline = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: 0x2D2419)
                : UIColor(hex: 0xF0E5D5)
        })

        // ── Status ───────────────────────────────────────────

        static let success = olive
        static let warning = Color(uiColor: UIColor(hex: 0xBA7517))
        static let danger  = Color(uiColor: UIColor(hex: 0xA02525))
    }
}

// ============================================================
// UIColor hex helper
// ============================================================

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >>  8) & 0xFF) / 255.0
        let b = CGFloat( hex        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
