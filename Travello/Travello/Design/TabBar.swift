import SwiftUI

// ============================================================
// TAB BAR
// Кастомный TabBar в стилистике Editorial:
// — закруглённая capsule-форма
// — буквенные иконки в Fraunces-italic (неактивная)
// — активная иконка превращается в regular (морфинг)
// — haptic feedback на смену таба
// ============================================================

enum AppTab: Int, CaseIterable, Identifiable {
    case home, trip, profile

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home:    return "главная"
        case .trip:    return "поездка"
        case .profile: return "профиль"
        }
    }

    /// Буквенная иконка для каждого таба (в стиле Fraunces).
    var glyph: String {
        switch self {
        case .home:    return "H"
        case .trip:    return "T"
        case .profile: return "P"
        }
    }
}

struct TravelloTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                TabButton(tab: tab, isSelected: selection == tab) {
                    if selection != tab {
                        Haptics.select()
                        withAnimation(Anim.spring) {
                            selection = tab
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.Travello.paper)
        )
        .overlay(
            Capsule()
                .stroke(Color.Travello.ink, lineWidth: Stroke.hairline)
        )
        .mediumShadow()
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }
}

// ─── INDIVIDUAL TAB BUTTON ───────────────────────────────────

private struct TabButton: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                // Морфинг: italic → regular при активации
                Text(tab.glyph)
                    .font(.custom(
                        isSelected ? "Fraunces-Medium" : "Fraunces-LightItalic",
                        size: 18
                    ))
                    .foregroundColor(isSelected ? .Travello.terra : .Travello.tertiary)
                    .frame(height: 22)

                Text(tab.title)
                    .font(.Travello.eyebrowSmall)
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundColor(isSelected ? .Travello.terra : .Travello.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.Travello.sand : Color.clear)
            )
            .animation(Anim.microSpring, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// ─── PREVIEW ─────────────────────────────────────────────────

#Preview {
    @Previewable @State var selection: AppTab = .home

    ZStack(alignment: .bottom) {
        Color.Travello.cream.ignoresSafeArea()
        TravelloTabBar(selection: $selection)
    }
}
