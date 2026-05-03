import SwiftUI

// ============================================================
// COMPONENTS
// Переиспользуемые компоненты в стилистике Editorial.
// ============================================================

// ─── BUTTONS ─────────────────────────────────────────────────

/// Главная кнопка действия — terracotta, скруглённая.
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false

    @State private var isPressed = false

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .buttonText()
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.Travello.terra)
            )
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1.0)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(Anim.microSpring, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

/// Тёмная кнопка — для Apple Sign In и серьёзных действий.
struct DarkButton: View {
    let title: String
    let action: () -> Void
    var systemIcon: String? = nil

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: Spacing.sm) {
                if let icon = systemIcon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                }
                Text(title)
                    .buttonText()
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color(uiColor: .label))    // адаптируется к теме
            )
        }
    }
}

/// Текстовая ссылка-кнопка в Italic-стиле.
struct LinkButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.Travello.italic)
                .foregroundColor(.Travello.terra)
                .underline(true, color: .Travello.terra.opacity(0.4))
        }
    }
}

// ─── CARDS ───────────────────────────────────────────────────

/// Базовая карточка — белая поверхность с тонкой границей и скруглением.
struct Card<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(Color.Travello.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.Travello.line, lineWidth: Stroke.hairline)
            )
    }
}

/// Подложка-карточка на фоне sand — без границы.
struct SoftCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(Color.Travello.sand)
            )
    }
}

// ─── DIVIDERS ────────────────────────────────────────────────

/// Жирная линия — Editorial-разделитель.
struct Rule: View {
    var color: Color = .Travello.ink

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: Stroke.hairline)
    }
}

/// Тонкая линия — мягкий разделитель.
struct SoftRule: View {
    var body: some View {
        Rectangle()
            .fill(Color.Travello.line)
            .frame(height: Stroke.hairline)
    }
}

// ─── EYEBROW LINE WITH DASH ──────────────────────────────────

/// Eyebrow с короткой линией перед текстом — фирменный приём.
/// Пример: "—— завтрак · 09:00"
struct EyebrowLine: View {
    let text: String
    var color: Color = .Travello.mute

    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(color)
                .frame(width: 14, height: Stroke.hairline)
            Text(text)
                .eyebrow(color)
        }
    }
}

// ─── TAGS / CHIPS ────────────────────────────────────────────

/// Тег с тонкой границей — для хэштегов и категорий.
struct EditorialTag: View {
    let text: String
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        Text(text)
            .font(isSelected ? .Travello.eyebrow : .Travello.italicSmall)
            .tracking(isSelected ? 0.8 : 0)
            .textCase(isSelected ? .uppercase : nil)
            .foregroundColor(isSelected ? Color.Travello.cream : .Travello.ink)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.Travello.ink : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(Color.Travello.ink, lineWidth: Stroke.hairline)
            )
            .onTapGesture {
                Haptics.select()
                onTap?()
            }
            .animation(Anim.microSpring, value: isSelected)
    }
}

// ─── PROGRESS ────────────────────────────────────────────────

/// Тонкий progress bar для опросника — линия 0.5px.
struct EditorialProgress: View {
    /// 0.0 — 1.0
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.Travello.line)
                    .frame(height: Stroke.hairline)
                Rectangle()
                    .fill(Color.Travello.terra)
                    .frame(width: geo.size.width * value, height: 1.5)
                    .animation(Anim.smooth, value: value)
            }
        }
        .frame(height: 1.5)
    }
}

// ─── PAGE INDICATOR (DOTS) ───────────────────────────────────

/// Индикатор страниц — активная превращается в pill.
struct PageDots: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.Travello.terra : Color.Travello.line)
                    .frame(width: index == current ? 18 : 5, height: 5)
                    .animation(Anim.spring, value: current)
            }
        }
    }
}

// ─── DECORATIVE NUMERAL ──────────────────────────────────────

/// Большая декоративная нумерация в italic — «01», «02».
/// Используется в карточках вариантов и hero-блоках.
struct EditorialNumeral: View {
    let value: Int
    var size: CGFloat = 32
    var color: Color = .Travello.terra

    var body: some View {
        Text(String(format: "%02d", value))
            .font(.custom("Fraunces-LightItalic", size: size))
            .foregroundColor(color)
            .lineLimit(1)
    }
}

// ─── PREVIEWS ────────────────────────────────────────────────

#Preview("Buttons") {
    VStack(spacing: 16) {
        PrimaryButton(title: "Создать маршрут") { }
        DarkButton(title: "Войти через Apple", action: { }, systemIcon: "applelogo")
        LinkButton(title: "пропустить — займусь позже") { }
    }
    .padding()
    .background(Color.Travello.cream)
}

#Preview("Tags") {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            EditorialTag(text: "пляж", isSelected: true)
            EditorialTag(text: "история", isSelected: true)
            EditorialTag(text: "кухня")
            EditorialTag(text: "природа")
        }
    }
    .padding()
    .background(Color.Travello.cream)
}

#Preview("Misc") {
    VStack(alignment: .leading, spacing: 16) {
        EyebrowLine(text: "завтрак · 09:00")
        Rule()
        SoftRule()
        EditorialProgress(value: 0.6)
        PageDots(total: 3, current: 1)
        EditorialNumeral(value: 2, size: 64)
    }
    .padding()
    .background(Color.Travello.cream)
}
