import SwiftUI

// ============================================================
// SPACING & METRICS
// Все значения отступов, радиусов и линий — централизованно.
// ============================================================

enum Spacing {
    static let xxxs: CGFloat = 2
    static let xxs:  CGFloat = 4
    static let xs:   CGFloat = 6
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let xxl:  CGFloat = 28
    static let xxxl: CGFloat = 36

    /// Стандартный горизонтальный padding контейнеров.
    static let screenPadding: CGFloat = 18
}

enum Radius {
    /// Очень маленький — теги, чипы.
    static let xs:   CGFloat = 6

    /// Маленький — поля ввода, маленькие карточки.
    static let sm:   CGFloat = 10

    /// Средний — обычные карточки.
    static let md:   CGFloat = 14

    /// Большой — hero-блоки, обложки.
    static let lg:   CGFloat = 18

    /// Очень большой — TabBar, главные кнопки.
    static let xl:   CGFloat = 24

    /// Шторки и bottom sheets.
    static let sheet: CGFloat = 28

    /// Полностью круглые элементы (capsule).
    static let pill: CGFloat = 999
}

enum Stroke {
    /// Тончайший волосок — Editorial-разделители.
    static let hairline: CGFloat = 0.5

    /// Обычная граница — для рамок карточек.
    static let line:     CGFloat = 1

    /// Усиленная граница — фокус, выбранное состояние.
    static let bold:     CGFloat = 1.5
}

// ============================================================
// ANIMATIONS
// Стандартные анимационные пресеты.
// ============================================================

enum Anim {
    /// Springy-анимация для появления карточек.
    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.75)

    /// Лёгкая spring для микроинтеракций.
    static let microSpring = Animation.spring(response: 0.35, dampingFraction: 0.7)

    /// Плавный fade — для переходов между состояниями.
    static let smooth = Animation.easeInOut(duration: 0.35)

    /// Быстрый fade — для tap feedback.
    static let quick = Animation.easeInOut(duration: 0.18)

    /// Медленная анимация для hero-параллакса.
    static let parallax = Animation.easeOut(duration: 0.45)

    /// Длительность fade-in карточек на экране со списком.
    static let cardCascade: Double = 0.06
}

// ============================================================
// SHADOWS
// Тени для иерархии глубины.
// ============================================================

extension View {
    /// Лёгкая тень — для приподнятых карточек.
    func softShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    /// Средняя тень — для floating-элементов и TabBar.
    func mediumShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 4)
    }

    /// Сильная тень — для модалок и шторок.
    func strongShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.15), radius: 24, x: 0, y: 8)
    }

    /// Цветная тень в стиле terra — для акцентных элементов.
    func terraShadow() -> some View {
        self.shadow(color: Color.Travello.terra.opacity(0.25), radius: 12, x: 0, y: 4)
    }
}

// ============================================================
// HAPTICS
// Тактильный feedback — лёгкий, средний, важный.
// ============================================================

enum Haptics {
    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func select() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func warning() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    static func error() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    /// Средний удар — для подтверждения важного действия.
    static func medium() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}
