import SwiftUI

// ============================================================
// ONBOARDING ILLUSTRATIONS
// Декоративные SVG-иллюстрации для трёх страниц.
// Используем чистые формы вместо растровых картинок.
// ============================================================

struct OnboardingIllustration: View {
    let kind: OnboardingPage.Illustration

    @State private var animateIn = false

    var body: some View {
        ZStack {
            background
            content
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .onAppear {
            // Анимация появления внутренних элементов
            withAnimation(.easeOut(duration: 0.7).delay(0.2)) {
                animateIn = true
            }
        }
    }

    // ─── Background gradient ─────────────────────────────────

    @ViewBuilder
    private var background: some View {
        switch kind {
        case .search:
            LinearGradient(
                colors: [Color(hex: 0xFCE4CC), Color.Travello.apricot],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .map:
            LinearGradient(
                colors: [Color(hex: 0xB8DCC2), Color.Travello.olive],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .bell:
            LinearGradient(
                colors: [Color(hex: 0xF4D1A6), Color.Travello.honey],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // ─── Content per kind ────────────────────────────────────

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .search: SearchIllust(animateIn: animateIn)
        case .map:    MapIllust(animateIn: animateIn)
        case .bell:   BellIllust(animateIn: animateIn)
        }
    }
}

// ─── ILLUSTRATION 1 — SEARCH (magnifying glass + dots) ───────

private struct SearchIllust: View {
    let animateIn: Bool

    var body: some View {
        ZStack {
            // Парящие точки разных цветов
            Circle()
                .fill(Color.Travello.olive)
                .frame(width: 14, height: 14)
                .offset(x: -55, y: -45)
                .opacity(animateIn ? 1 : 0)
                .scaleEffect(animateIn ? 1 : 0)
                .animation(Anim.spring.delay(0.3), value: animateIn)

            Circle()
                .fill(Color.Travello.apricot)
                .frame(width: 14, height: 14)
                .offset(x: 60, y: -50)
                .opacity(animateIn ? 1 : 0)
                .scaleEffect(animateIn ? 1 : 0)
                .animation(Anim.spring.delay(0.4), value: animateIn)

            Circle()
                .fill(Color.Travello.terra)
                .frame(width: 14, height: 14)
                .offset(x: 55, y: 35)
                .opacity(animateIn ? 1 : 0)
                .scaleEffect(animateIn ? 1 : 0)
                .animation(Anim.spring.delay(0.5), value: animateIn)

            // Лупа
            ZStack {
                Circle()
                    .stroke(Color.Travello.ink, lineWidth: 3)
                    .frame(width: 90, height: 90)

                // Ручка лупы
                Capsule()
                    .fill(Color.Travello.ink)
                    .frame(width: 4, height: 28)
                    .rotationEffect(.degrees(45))
                    .offset(x: 45, y: 45)
            }
            .scaleEffect(animateIn ? 1 : 0.6)
            .opacity(animateIn ? 1 : 0)
            .animation(Anim.spring.delay(0.1), value: animateIn)
        }
    }
}

// ─── ILLUSTRATION 2 — MAP (route + pins) ─────────────────────

private struct MapIllust: View {
    let animateIn: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Пунктирные пути между пинами
                Path { path in
                    path.move(to: CGPoint(x: 30, y: 60))
                    path.addQuadCurve(
                        to: CGPoint(x: 140, y: 90),
                        control: CGPoint(x: 80, y: 30)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 220, y: 120),
                        control: CGPoint(x: 180, y: 70)
                    )
                }
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 5])
                )
                .opacity(animateIn ? 0.9 : 0)
                .animation(Anim.smooth.delay(0.4), value: animateIn)

                Path { path in
                    path.move(to: CGPoint(x: 50, y: 130))
                    path.addQuadCurve(
                        to: CGPoint(x: 160, y: 150),
                        control: CGPoint(x: 100, y: 110)
                    )
                }
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 5])
                )
                .opacity(animateIn ? 0.9 : 0)
                .animation(Anim.smooth.delay(0.5), value: animateIn)

                // 4 пина
                MapPin()
                    .position(x: 30, y: 60)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : -10)
                    .animation(Anim.spring.delay(0.1), value: animateIn)

                MapPin()
                    .position(x: 140, y: 90)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : -10)
                    .animation(Anim.spring.delay(0.2), value: animateIn)

                MapPin()
                    .position(x: 220, y: 120)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : -10)
                    .animation(Anim.spring.delay(0.3), value: animateIn)

                MapPin()
                    .position(x: 70, y: 150)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : -10)
                    .animation(Anim.spring.delay(0.4), value: animateIn)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private struct MapPin: View {
    var body: some View {
        ZStack {
            Path { path in
                // Капля
                let w: CGFloat = 22
                let h: CGFloat = 28
                path.move(to: CGPoint(x: w/2, y: h))
                path.addCurve(
                    to: CGPoint(x: 0, y: w/2),
                    control1: CGPoint(x: w/2, y: h * 0.7),
                    control2: CGPoint(x: 0, y: h * 0.7)
                )
                path.addArc(
                    center: CGPoint(x: w/2, y: w/2),
                    radius: w/2,
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: false
                )
                path.addCurve(
                    to: CGPoint(x: w/2, y: h),
                    control1: CGPoint(x: w, y: h * 0.7),
                    control2: CGPoint(x: w/2, y: h * 0.7)
                )
            }
            .fill(Color.Travello.terra)
            .frame(width: 22, height: 28)
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)

            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .offset(y: -3)
        }
    }
}

// ─── ILLUSTRATION 3 — BELL (notification + bubbles) ──────────

private struct BellIllust: View {
    let animateIn: Bool
    @State private var bubbleFloat: Bool = false

    var body: some View {
        ZStack {
            // Колокольчик в центре
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white)
                    .frame(width: 70, height: 70)
                    .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)

                Image(systemName: "bell.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.Travello.terra)
            }
            .scaleEffect(animateIn ? 1 : 0.5)
            .opacity(animateIn ? 1 : 0)
            .animation(Anim.spring.delay(0.1), value: animateIn)

            // Пузырь 1 — справа сверху
            NotificationBubble(
                eyebrow: "СОВЕТ ДНЯ",
                text: "Дождь после 15:00 — успейте на пляж утром"
            )
            .frame(width: 130)
            .offset(x: 60, y: -50)
            .opacity(animateIn ? 1 : 0)
            .offset(y: bubbleFloat && animateIn ? -3 : 0)
            .animation(Anim.spring.delay(0.4), value: animateIn)

            // Пузырь 2 — слева снизу
            NotificationBubble(
                eyebrow: "ЧЕРЕЗ 24Ч",
                text: "Открылась регистрация на TK412"
            )
            .frame(width: 130)
            .offset(x: -55, y: 50)
            .opacity(animateIn ? 1 : 0)
            .offset(y: bubbleFloat && animateIn ? 3 : 0)
            .animation(Anim.spring.delay(0.5), value: animateIn)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                bubbleFloat = true
            }
        }
    }
}

private struct NotificationBubble: View {
    let eyebrow: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow)
                .eyebrowSmall(.Travello.terra)

            Text(text)
                .font(.Travello.caption)
                .foregroundColor(.Travello.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
    }
}

// ─── PREVIEW ─────────────────────────────────────────────────

#Preview {
    VStack(spacing: 12) {
        OnboardingIllustration(kind: .search)
        OnboardingIllustration(kind: .map)
        OnboardingIllustration(kind: .bell)
    }
    .padding()
    .background(Color.Travello.cream)
}
