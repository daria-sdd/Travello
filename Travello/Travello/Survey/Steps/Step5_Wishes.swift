import SwiftUI

// ============================================================
// STEP 5 — WISHES
// Финальный шаг: свободный текст с пожеланиями.
// Можно пропустить — кнопка «Пропустить» под основной.
// ============================================================

struct Step5_Wishes: View {
    @ObservedObject var state: SurveyState
    @FocusState private var isFocused: Bool

    // Примеры для вдохновения
    private let hints = [
        "«Хочу что-то спокойное у моря, без туристических толп»",
        "«Люблю местную кухню и небольшие рестораны, не McDonald's»",
        "«Мы с партнёром — первое совместное путешествие»",
        "«Хочу посмотреть закат с высокой точки»",
    ]
    @State private var currentHint = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {

            // ── Подсказка ─────────────────────────────────────
            Text("Опишите особые пожелания. Чем конкретнее — тем точнее ИИ подберёт маршрут.")
                .font(.Travello.italic)
                .foregroundColor(.Travello.mute)
                .lineSpacing(4)
                .padding(.top, Spacing.lg)

            SoftRule()

            // ── Поле текста ───────────────────────────────────
            VStack(alignment: .leading, spacing: Spacing.sm) {
                EyebrowLine(text: "ваши пожелания")

                ZStack(alignment: .topLeading) {
                    // Placeholder — меняется каждые несколько секунд
                    if state.extraWishes.isEmpty {
                        Text(hints[currentHint])
                            .font(.Travello.italic)
                            .foregroundColor(.Travello.tertiary)
                            .lineSpacing(4)
                            .padding(Spacing.md)
                            .transition(.opacity)
                            .id(currentHint)
                    }

                    TextEditor(text: $state.extraWishes)
                        .font(.Travello.body)
                        .foregroundColor(.Travello.ink)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .focused($isFocused)
                        .frame(minHeight: 120)
                        .padding(Spacing.xs)
                        .opacity(state.extraWishes.isEmpty && !isFocused ? 0.011 : 1)
                }
                .padding(Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(Color.Travello.paper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(
                            isFocused ? Color.Travello.terra : Color.Travello.line,
                            lineWidth: isFocused ? Stroke.bold : Stroke.hairline
                        )
                )
                .animation(Anim.quick, value: isFocused)

                // Счётчик символов
                if !state.extraWishes.isEmpty {
                    Text("\(state.extraWishes.count) символов")
                        .eyebrowSmall()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .transition(.opacity)
                }
            }

            // ── Совет ─────────────────────────────────────────
            SoftCard {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Text("💡")
                        .font(.system(size: 16))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Совет")
                            .eyebrowSmall(.Travello.terra)
                        Text("Напишите что важно именно вам: темп путешествия, особые события, ограничения по питанию, годовщина — всё это учтёт ИИ.")
                            .font(.Travello.caption)
                            .foregroundColor(.Travello.inkSoft)
                            .lineSpacing(3)
                    }
                }
            }

            Spacer()
        }
        .padding(.bottom, 140)
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = false
        }
        .onAppear {
            // Ротация placeholder-подсказок каждые 3 секунды
            startHintRotation()
        }
    }

    private func startHintRotation() {
        Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            guard state.extraWishes.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                currentHint = (currentHint + 1) % hints.count
            }
        }
    }
}
