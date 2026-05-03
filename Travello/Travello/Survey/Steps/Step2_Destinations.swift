import SwiftUI

// ============================================================
// STEP 2 — DESTINATIONS
// Пользователь добавляет направления в список.
// Порядок меняется через drag-and-drop (List с .onMove).
// Можно пропустить — ИИ выберет сам.
// ============================================================

struct Step2_Destinations: View {
    @ObservedObject var state: SurveyState
    @State private var newName   = ""
    @State private var newType   = SurveyDestination.DestinationType.any
    @State private var showInput = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Подсказка ─────────────────────────────────────
            Text("Добавьте одно или несколько направлений.\nМожно оставить пустым — ИИ подберёт лучший вариант.")
                .font(.Travello.italic)
                .foregroundColor(.Travello.mute)
                .lineSpacing(4)
                .padding(.top, Spacing.lg)

            SoftRule().padding(.top, Spacing.xl)

            // ── Список направлений ────────────────────────────
            if state.destinations.isEmpty {
                EmptyDestinations()
                    .padding(.top, Spacing.xxl)
            } else {
                // EditableList с drag-to-reorder
                List {
                    ForEach(state.destinations) { dest in
                        DestinationRow(destination: dest) {
                            state.destinations.removeAll { $0.id == dest.id }
                            Haptics.tap()
                        }
                        .listRowBackground(Color.Travello.cream)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }
                    .onMove { from, to in
                        state.destinations.move(fromOffsets: from, toOffset: to)
                        Haptics.select()
                    }
                }
                .listStyle(.plain)
                .frame(height: min(CGFloat(state.destinations.count) * 70 + 8, 280))
                .environment(\.editMode, .constant(.active))   // всегда в режиме редактирования для drag
            }

            SoftRule().padding(.top, Spacing.lg)

            // ── Форма добавления ──────────────────────────────
            if showInput {
                addInputView
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Button {
                    withAnimation(Anim.spring) { showInput = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        inputFocused = true
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                        Text("Добавить направление")
                            .font(.Travello.italic)
                    }
                    .foregroundColor(.Travello.terra)
                    .padding(.top, Spacing.md)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 120)
    }

    // ─── Input form ──────────────────────────────────────────

    private var addInputView: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            EyebrowLine(text: "новое направление")
                .padding(.top, Spacing.lg)

            // Поле ввода
            HStack(spacing: Spacing.sm) {
                TextField("", text: $newName)
                    .font(.Travello.h3)
                    .foregroundColor(.Travello.ink)
                    .placeholder(when: newName.isEmpty) {
                        Text("Турция, Стамбул, Балтика…")
                            .font(.Travello.italic)
                            .foregroundColor(.Travello.tertiary)
                    }
                    .focused($inputFocused)
                    .submitLabel(.done)
                    .onSubmit { commitNew() }

                if !newName.isEmpty {
                    Button { commitNew() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.Travello.terra))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, Spacing.md)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.Travello.ink).frame(height: Stroke.hairline)
            }

            // Тип направления
            HStack(spacing: Spacing.sm) {
                ForEach(SurveyDestination.DestinationType.allCases, id: \.self) { type in
                    Button {
                        newType = type; Haptics.select()
                    } label: {
                        Text(type.rawValue)
                            .font(newType == type ? .Travello.eyebrow : .Travello.italicSmall)
                            .tracking(newType == type ? 0.8 : 0)
                            .textCase(newType == type ? .uppercase : nil)
                            .foregroundColor(newType == type ? .Travello.cream : .Travello.ink)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(newType == type ? Color.Travello.ink : Color.clear)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.Travello.ink, lineWidth: Stroke.hairline)
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(Anim.microSpring, value: newType)
                }
            }

            // Кнопка отмены
            Button {
                withAnimation(Anim.spring) {
                    showInput = false; newName = ""; inputFocused = false
                }
            } label: {
                Text("отмена")
                    .font(.Travello.italic)
                    .foregroundColor(.Travello.mute)
            }
            .buttonStyle(.plain)
        }
    }

    private func commitNew() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation(Anim.spring) {
            state.destinations.append(.init(name: trimmed, type: newType))
            newName = ""; newType = .any; showInput = false; inputFocused = false
        }
        Haptics.success()
    }
}

// ─── DESTINATION ROW ──────────────────────────────────────────

private struct DestinationRow: View {
    let destination: SurveyDestination
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Drag handle — показывается автоматически в .active editMode
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(.Travello.tertiary)

            VStack(alignment: .leading, spacing: 3) {
                Text(destination.name)
                    .font(.Travello.h3)
                    .foregroundColor(.Travello.ink)

                Text(destination.type.rawValue.uppercased())
                    .font(.Travello.eyebrowSmall)
                    .tracking(1.2)
                    .foregroundColor(.Travello.mute)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.Travello.mute)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.Travello.sand))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
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

// ─── EMPTY STATE ─────────────────────────────────────────────

private struct EmptyDestinations: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            Text("✈")
                .font(.system(size: 40))
                .foregroundColor(.Travello.tertiary)

            Text("Куда полетим?")
                .font(.Travello.italic)
                .foregroundColor(.Travello.mute)

            Text("Добавьте страну или город. Или пропустите — ИИ выберет лучший вариант под ваш бюджет.")
                .font(.Travello.caption)
                .foregroundColor(.Travello.tertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
    }
}
