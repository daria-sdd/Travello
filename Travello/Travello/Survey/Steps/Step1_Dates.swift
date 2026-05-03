import SwiftUI

// ============================================================
// STEP 1 — DATES
// ============================================================

struct Step1_Dates: View {
    @ObservedObject var state: SurveyState
    @State private var showFromPicker = false
    @State private var showToPicker   = false
    @FocusState private var cityFocused: Bool

    private var dateRange: ClosedRange<Date> {
        let today     = Calendar.current.startOfDay(for: Date())
        let twoYears  = Calendar.current.date(byAdding: .year, value: 2, to: today)!
        return today...twoYears
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.xl) {

                // ── Откуда ────────────────────────────────────
                SurveyFieldSection(eyebrow: "откуда вылетаем") {
                    TextField("", text: $state.departFrom)
                        .font(.Travello.h3)
                        .foregroundColor(.Travello.ink)
                        .placeholder(when: state.departFrom.isEmpty) {
                            Text("Москва, Санкт-Петербург…")
                                .font(.Travello.italic)
                                .foregroundColor(.Travello.tertiary)
                        }
                        .focused($cityFocused)
                        .submitLabel(.done)
                        .onSubmit { cityFocused = false }
                        .padding(.vertical, Spacing.md)
                }

                SoftRule()

                // ── Даты ──────────────────────────────────────
                SurveyFieldSection(eyebrow: "когда летим") {
                    HStack(spacing: Spacing.md) {
                        DateTile(
                            label: "туда",
                            date: state.dateFrom,
                            isActive: showFromPicker
                        ) {
                            withAnimation(Anim.spring) {
                                showFromPicker.toggle()
                                if showFromPicker { showToPicker = false }
                            }
                            Haptics.tap()
                        }

                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(.Travello.tertiary)

                        DateTile(
                            label: "обратно",
                            date: state.dateTo,
                            isActive: showToPicker
                        ) {
                            withAnimation(Anim.spring) {
                                showToPicker.toggle()
                                if showToPicker { showFromPicker = false }
                            }
                            Haptics.tap()
                        }
                    }

                    if showFromPicker {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { state.dateFrom ?? Date() },
                                set: { state.dateFrom = $0; withAnimation { showFromPicker = false } }
                            ),
                            in: dateRange,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .tint(.Travello.terra)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if showToPicker {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { state.dateTo ?? (state.dateFrom.flatMap {
                                    Calendar.current.date(byAdding: .day, value: 7, to: $0)
                                } ?? Date()) },
                                set: { state.dateTo = $0; withAnimation { showToPicker = false } }
                            ),
                            in: (state.dateFrom ?? Date())...dateRange.upperBound,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .tint(.Travello.terra)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                SoftRule()

                // ── Гибкие даты ───────────────────────────────
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Даты гибкие")
                            .font(.Travello.bodyBold)
                            .foregroundColor(.Travello.ink)
                        Text("ИИ сдвинет ±3 дня для лучшей цены")
                            .font(.Travello.caption)
                            .foregroundColor(.Travello.mute)
                    }
                    Spacer()
                    TerraToggle(isOn: $state.flexibleDates)
                }

                SoftRule()

                // ── Кол-во путешественников ───────────────────
                SurveyFieldSection(eyebrow: "путешественников") {
                    HStack {
                        Text("\(state.travellerCount) \(pluralPerson(state.travellerCount))")
                            .font(.Travello.h3)
                            .foregroundColor(.Travello.ink)
                        Spacer()
                        HStack(spacing: Spacing.md) {
                            CircleStepButton(icon: "minus") {
                                guard state.travellerCount > 1 else { return }
                                state.travellerCount -= 1; Haptics.tap()
                            }
                            .disabled(state.travellerCount <= 1)
                            CircleStepButton(icon: "plus") {
                                guard state.travellerCount < 20 else { return }
                                state.travellerCount += 1; Haptics.tap()
                            }
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }
            }
            .padding(.top, Spacing.lg)
            .padding(.bottom, 120)
        }
    }

    private func pluralPerson(_ n: Int) -> String {
        let mod100 = n % 100; let mod10 = n % 10
        if (11...14).contains(mod100)  { return "человек" }
        if mod10 == 1                   { return "человек" }
        if (2...4).contains(mod10)      { return "человека" }
        return "человек"
    }
}

// ─── DATE TILE ───────────────────────────────────────────────

private struct DateTile: View {
    let label: String
    let date: Date?
    let isActive: Bool
    let action: () -> Void

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale(identifier: "ru_RU")
        return f
    }()

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label).eyebrowSmall()
                Text(date.map { Self.fmt.string(from: $0) } ?? "выбрать")
                    .font(date != nil ? .Travello.h3 : .Travello.italic)
                    .foregroundColor(date != nil ? .Travello.ink : .Travello.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(isActive ? Color.Travello.sand : Color.Travello.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(
                        isActive ? Color.Travello.terra : Color.Travello.line,
                        lineWidth: isActive ? Stroke.bold : Stroke.hairline
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// ─── SHARED SUBCOMPONENTS (используются в нескольких шагах) ──

struct TerraToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button {
            isOn.toggle(); Haptics.select()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Color.Travello.terra : Color.Travello.line)
                    .frame(width: 44, height: 26)
                Circle().fill(.white).frame(width: 20, height: 20).padding(3)
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 1)
            }
            .animation(Anim.microSpring, value: isOn)
        }
        .buttonStyle(.plain)
    }
}

struct CircleStepButton: View {
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.Travello.ink)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.Travello.sand))
                .overlay(Circle().stroke(Color.Travello.line, lineWidth: Stroke.hairline))
        }
        .buttonStyle(.plain)
    }
}

struct SurveyFieldSection<Content: View>: View {
    let eyebrow: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            EyebrowLine(text: eyebrow)
            content()
        }
    }
}

extension View {
    func placeholder<P: View>(
        when shouldShow: Bool,
        @ViewBuilder placeholder: () -> P
    ) -> some View {
        ZStack(alignment: .leading) {
            if shouldShow { placeholder() }
            self
        }
    }
}
