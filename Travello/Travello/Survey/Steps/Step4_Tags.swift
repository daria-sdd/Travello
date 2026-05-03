import SwiftUI

// ============================================================
// STEP 4 — TAGS
// Облако тегов: выбираем что нравится.
// + поле для собственного тега.
// ============================================================

struct Step4_Tags: View {
    @ObservedObject var state: SurveyState
    @State private var showCustomInput = false
    @FocusState private var customFocused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.xl) {

                // ── Инструкция ────────────────────────────────
                Text("Выберите хотя бы три, или пропустите — ИИ подберёт баланс сам.")
                    .font(.Travello.italic)
                    .foregroundColor(.Travello.mute)
                    .lineSpacing(4)
                    .padding(.top, Spacing.lg)

                SoftRule()

                // ── Облако тегов ──────────────────────────────
                FlowLayout(spacing: Spacing.sm) {
                    ForEach(SurveyTag.all) { tag in
                        TagChip(
                            tag: tag,
                            isSelected: state.selectedTagIds.contains(tag.id)
                        ) {
                            toggleTag(tag.id)
                        }
                    }

                    // Собственный тег если добавлен
                    if let custom = state.customTag.nilIfEmpty {
                        TagChip(
                            label: custom,
                            emoji: "✏️",
                            isSelected: true,
                            isCustom: true
                        ) {
                            withAnimation(Anim.spring) {
                                state.customTag = ""
                            }
                        }
                    }
                }

                // ── Добавить свой тег ─────────────────────────
                if showCustomInput {
                    HStack(spacing: Spacing.sm) {
                        TextField("", text: $state.customTag)
                            .font(.Travello.bodySmall)
                            .foregroundColor(.Travello.ink)
                            .placeholder(when: state.customTag.isEmpty) {
                                Text("Ваш интерес…")
                                    .font(.Travello.italic)
                                    .foregroundColor(.Travello.tertiary)
                            }
                            .focused($customFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                withAnimation(Anim.spring) { showCustomInput = false }
                                customFocused = false
                            }

                        Button {
                            withAnimation(Anim.spring) { showCustomInput = false }
                            customFocused = false
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.Travello.terra))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(Spacing.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(Color.Travello.terra, lineWidth: Stroke.bold)
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                } else {
                    Button {
                        withAnimation(Anim.spring) { showCustomInput = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            customFocused = true
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .medium))
                            Text("Добавить свой интерес")
                                .font(.Travello.italic)
                        }
                        .foregroundColor(.Travello.terra)
                    }
                    .buttonStyle(.plain)
                }

                // ── Счётчик выбранных ─────────────────────────
                if !state.selectedTagIds.isEmpty {
                    HStack {
                        Text("Выбрано: \(state.selectedTagIds.count)")
                            .eyebrow(.Travello.terra)
                        Spacer()
                        Button {
                            withAnimation(Anim.spring) { state.selectedTagIds.removeAll() }
                            Haptics.tap()
                        } label: {
                            Text("сбросить")
                                .font(.Travello.italic)
                                .foregroundColor(.Travello.mute)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 120)
        }
    }

    private func toggleTag(_ id: String) {
        withAnimation(Anim.microSpring) {
            if state.selectedTagIds.contains(id) {
                state.selectedTagIds.remove(id)
            } else {
                state.selectedTagIds.insert(id)
            }
        }
        Haptics.select()
    }
}

// ─── TAG CHIP ────────────────────────────────────────────────

private struct TagChip: View {
    var label: String
    var emoji: String
    let isSelected: Bool
    var isCustom: Bool = false
    let action: () -> Void

    // Инициализатор для стандартных тегов
    init(tag: SurveyTag, isSelected: Bool, action: @escaping () -> Void) {
        self.label = tag.label; self.emoji = tag.emoji
        self.isSelected = isSelected; self.action = action
    }

    // Инициализатор для кастомного тега
    init(label: String, emoji: String, isSelected: Bool, isCustom: Bool, action: @escaping () -> Void) {
        self.label = label; self.emoji = emoji
        self.isSelected = isSelected; self.isCustom = isCustom; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(emoji).font(.system(size: 14))

                Text(label)
                    .font(isSelected ? .Travello.eyebrow : .Travello.bodySmall)
                    .tracking(isSelected ? 0.6 : 0)
                    .textCase(isSelected ? .uppercase : nil)
                    .foregroundColor(isSelected ? .Travello.cream : .Travello.ink)

                if isCustom {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.Travello.cream.opacity(0.7))
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.Travello.ink : Color.Travello.paper)
            )
            .overlay(
                Capsule()
                    .stroke(Color.Travello.line, lineWidth: Stroke.hairline)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(Anim.microSpring, value: isSelected)
    }
}

// ─── FLOW LAYOUT ─────────────────────────────────────────────
// Переносит элементы как слова в тексте — wrap-контейнер.

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > width && rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0; rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX; rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
