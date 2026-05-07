import SwiftUI

// ============================================================
// ONBOARDING PAGE VIEW
// Один разворот в стилистике Editorial.
// — большая курсивная нумерация наверху
// — eyebrow "первый разворот"
// — иллюстрация
// — заголовок с italic-акцентом
// — текст с drop cap (буквица)
// ============================================================

struct OnboardingPageView: View {
    let page: OnboardingPage

    /// Когда страница становится видимой — запускаем внутренние анимации.
    let isActive: Bool

    @State private var contentReady: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Editorial header: number + label ──
            VStack(alignment: .leading, spacing: 4) {
                Text(page.number)
                    .font(.custom("Fraunces72pt-LightItalic", size: 80))
                    .foregroundColor(.Travello.terra.opacity(0.18))
                    .lineLimit(1)
                    .padding(.top, Spacing.lg)

                Text(page.pageLabel)
                    .eyebrow()
            }
            .opacity(contentReady ? 1 : 0)
            .offset(y: contentReady ? 0 : 10)
            .animation(Anim.smooth.delay(0.1), value: contentReady)

            // ── Иллюстрация ──
            OnboardingIllustration(kind: page.illustration)
                .padding(.top, Spacing.lg)
                .padding(.horizontal, -Spacing.screenPadding) // выводим за пределы основного padding
                .opacity(contentReady ? 1 : 0)
                .offset(y: contentReady ? 0 : 16)
                .animation(Anim.spring.delay(0.2), value: contentReady)

            // ── Заголовок (с italic-акцентом) ──
            Text(page.title)
                .lineSpacing(2)
                .padding(.top, Spacing.xl)
                .opacity(contentReady ? 1 : 0)
                .offset(y: contentReady ? 0 : 12)
                .animation(Anim.smooth.delay(0.3), value: contentReady)

            // ── Подзаголовок с drop cap ──
            DropCapText(text: page.subtitle)
                .padding(.top, Spacing.md)
                .opacity(contentReady ? 1 : 0)
                .offset(y: contentReady ? 0 : 12)
                .animation(Anim.smooth.delay(0.4), value: contentReady)

            Spacer()
        }
        .padding(.horizontal, Spacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.Travello.cream)
        .onChange(of: isActive) { _, newValue in
            if newValue {
                contentReady = false
                withAnimation { contentReady = true }
            }
        }
        .onAppear {
            if isActive {
                contentReady = true
            }
        }
    }
}

// ============================================================
// DROP CAP TEXT
// Первая буква параграфа — большая italic в цвете terra.
// Editorial-приём для journalism feel.
// ============================================================

struct DropCapText: View {
    let text: String

    var body: some View {
        guard let first = text.first else {
            return AnyView(EmptyView())
        }

        let rest = String(text.dropFirst())

        // SwiftUI не умеет настоящий float drop cap (как в HTML),
        // поэтому имитируем через HStack + alignment
        return AnyView(
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(first))
                    .font(.custom("Fraunces72pt-LightItalic", size: 32))
                    .foregroundColor(.Travello.terra)
                    .baselineOffset(-4)

                Text(rest)
                    .font(.Travello.bodySmall)
                    .foregroundColor(.Travello.inkSoft)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        )
    }
}

// ─── PREVIEW ─────────────────────────────────────────────────

#Preview {
    OnboardingPageView(page: OnboardingPage.all[1], isActive: true)
}
