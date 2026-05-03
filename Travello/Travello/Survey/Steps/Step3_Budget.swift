import SwiftUI

// ============================================================
// STEP 3 — BUDGET
// — Слайдер суммы (0 = не задан)
// — Picker валюты
// — Мультиселект что входит в бюджет
// ============================================================

struct Step3_Budget: View {
    @ObservedObject var state: SurveyState

    // Диапазон слайдера
    private let minBudget: Double = 0
    private let maxBudget: Double = 10_000

    @State private var showCurrencyPicker = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.xl) {

                // ── Сумма ─────────────────────────────────────
                SurveyFieldSection(eyebrow: "общий бюджет") {
                    // Большое отображение суммы
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        if let amount = state.budget.amount {
                            Text(formatAmount(amount))
                                .font(.Travello.display)
                                .foregroundColor(.Travello.ink)

                            Button {
                                withAnimation(Anim.spring) { showCurrencyPicker.toggle() }
                                Haptics.tap()
                            } label: {
                                HStack(spacing: 3) {
                                    Text(state.budget.currency)
                                        .font(.Travello.h3)
                                        .foregroundColor(.Travello.terra)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.Travello.terra)
                                        .rotationEffect(.degrees(showCurrencyPicker ? 180 : 0))
                                        .animation(Anim.microSpring, value: showCurrencyPicker)
                                }
                            }
                            .buttonStyle(.plain)

                        } else {
                            Text("не задан")
                                .font(.Travello.h1Italic)
                                .foregroundColor(.Travello.tertiary)
                            Text("— ИИ подберёт лучшее соотношение")
                                .font(.Travello.caption)
                                .foregroundColor(.Travello.mute)
                                .padding(.leading, 2)
                        }
                    }
                    .frame(minHeight: 52)

                    // Слайдер
                    VStack(spacing: Spacing.xs) {
                        Slider(
                            value: Binding(
                                get: { state.budget.amount ?? minBudget },
                                set: { newVal in
                                    state.budget.amount = newVal < 100 ? nil : newVal
                                }
                            ),
                            in: minBudget...maxBudget,
                            step: 50
                        )
                        .tint(.Travello.terra)

                        HStack {
                            Text("не задан").eyebrowSmall()
                            Spacer()
                            Text("$10 000+").eyebrowSmall()
                        }
                    }

                    // Currency picker dropdown
                    if showCurrencyPicker {
                        CurrencyPicker(
                            selected: $state.budget.currency,
                            onSelect: {
                                withAnimation(Anim.spring) { showCurrencyPicker = false }
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                SoftRule()

                // ── Что входит в бюджет ────────────────────────
                SurveyFieldSection(eyebrow: "бюджет включает") {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: Spacing.sm
                    ) {
                        ForEach(SurveyBudget.BudgetItem.allCases) { item in
                            BudgetItemToggle(
                                item: item,
                                isSelected: state.budget.includes.contains(item)
                            ) {
                                if state.budget.includes.contains(item) {
                                    state.budget.includes.remove(item)
                                } else {
                                    state.budget.includes.insert(item)
                                }
                                Haptics.select()
                            }
                        }
                    }

                    Text("Остальное ИИ посчитает отдельно и учтёт в сравнении вариантов.")
                        .font(.Travello.caption)
                        .foregroundColor(.Travello.mute)
                        .padding(.top, Spacing.xs)
                        .lineSpacing(3)
                }
            }
            .padding(.top, Spacing.lg)
            .padding(.bottom, 120)
        }
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
    }
}

// ─── BUDGET ITEM TOGGLE ───────────────────────────────────────

private struct BudgetItemToggle: View {
    let item: SurveyBudget.BudgetItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: item.icon + (isSelected ? ".fill" : ""))
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .Travello.cream : .Travello.ink)
                    .frame(width: 20)

                Text(item.rawValue)
                    .font(isSelected ? .Travello.eyebrow : .Travello.bodySmall)
                    .tracking(isSelected ? 0.8 : 0)
                    .textCase(isSelected ? .uppercase : nil)
                    .foregroundColor(isSelected ? .Travello.cream : .Travello.ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(isSelected ? Color.Travello.ink : Color.Travello.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.Travello.line, lineWidth: Stroke.hairline)
            )
            .animation(Anim.microSpring, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// ─── CURRENCY PICKER ─────────────────────────────────────────

private struct CurrencyPicker: View {
    @Binding var selected: String
    let onSelect: () -> Void

    private let currencies = ["USD", "EUR", "RUB", "GBP", "AED", "TRY", "THB"]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(currencies, id: \.self) { cur in
                Button {
                    selected = cur; onSelect(); Haptics.select()
                } label: {
                    HStack {
                        Text(cur)
                            .font(.Travello.bodyBold)
                            .foregroundColor(cur == selected ? .Travello.terra : .Travello.ink)
                        Spacer()
                        if cur == selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.Travello.terra)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.plain)

                if cur != currencies.last {
                    SoftRule().padding(.horizontal, Spacing.md)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.Travello.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Color.Travello.line, lineWidth: Stroke.hairline)
        )
        .softShadow()
    }
}
