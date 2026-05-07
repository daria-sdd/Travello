import SwiftUI

// ============================================================
// ONBOARDING SCREEN
// Три страницы с эффектом перелистывания книги.
//
// Реализация: каждая страница — это ZStack-слой. Активная
// страница вращается по оси Y вокруг левого края (как у книги),
// под ней появляется следующая.
//
// Управление:
// — Drag слева направо ИЛИ справа налево → переход
// — Кнопка «Дальше» внизу
// — На последней странице кнопка «Начать путешествие»
// ============================================================

struct OnboardingScreen: View {
    @EnvironmentObject var appState: AppState

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0

    private let pages = OnboardingPage.all

    var body: some View {
        ZStack {
            Color.Travello.cream.ignoresSafeArea()

            // ── Страницы (стек снизу-вверх) ──
            ZStack {
                ForEach(pages.indices, id: \.self) { index in
                    if index >= currentIndex {
                        OnboardingPageView(
                            page: pages[index],
                            isActive: index == currentIndex
                        )
                        .zIndex(Double(pages.count - index))
                        .modifier(
                            BookFlipModifier(
                                isFlipping: index == currentIndex,
                                progress: index == currentIndex ? flipProgress : 0
                            )
                        )
                    }
                }
            }
            // Свайп для перелистывания
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Перелистываем только справа налево
                        if value.translation.width < 0 {
                            dragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        let threshold: CGFloat = -80
                        if value.translation.width < threshold {
                            advance()
                        } else {
                            // Возврат к началу
                            withAnimation(Anim.spring) {
                                dragOffset = 0
                            }
                        }
                    }
            )

            // ── Низ: индикатор + кнопка ──
            VStack {
                Spacer()

                VStack(spacing: Spacing.md) {
                    PageDots(total: pages.count, current: currentIndex)

                    PrimaryButton(
                        title: isLastPage ? "Начать путешествие" : "Дальше",
                        action: handleNextTap
                    )
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.bottom, Spacing.xl)
            }
            .zIndex(100)
        }
        .ignoresSafeArea(.keyboard)
    }

    // ─── Logic ───────────────────────────────────────────────

    private var isLastPage: Bool {
        currentIndex == pages.count - 1
    }

    /// 0.0 — страница лежит ровно. 1.0 — полностью перевёрнута.
    private var flipProgress: CGFloat {
        // Преобразуем dragOffset в прогресс
        let maxDrag: CGFloat = 200
        return min(abs(dragOffset) / maxDrag, 1.0)
    }

    private func handleNextTap() {
        if isLastPage {
            finish()
        } else {
            advance()
        }
    }

    private func advance() {
        guard currentIndex < pages.count - 1 else {
            finish()
            return
        }
        Haptics.tap()
        withAnimation(.easeInOut(duration: 0.7)) {
            // Плавный flip через увеличение dragOffset до полной величины
            dragOffset = -200
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            currentIndex += 1
            dragOffset = 0
        }
    }

    private func finish() {
        Haptics.success()
        UserDefaults.standard.set(true, forKey: "travello.onboarding.completed")
        appState.didCompleteOnboarding()
    }
}

// ============================================================
// BOOK FLIP MODIFIER
// Эффект переворачивания страницы.
//
// Привязка: левая граница страницы (anchor = .leading).
// Ось вращения: Y.
// При progress 0 → 1: страница поворачивается на -160°
// и одновременно увеличивает свой angle с perspective-эффектом.
// ============================================================

struct BookFlipModifier: ViewModifier {
    let isFlipping: Bool
    let progress: CGFloat

    func body(content: Content) -> some View {
        if isFlipping {
            content
                // Лёгкий градиент-shadow на правом краю при flip — иллюзия глубины
                .overlay(alignment: .trailing) {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.15 * progress)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 60)
                    .allowsHitTesting(false)
                }
                // 3D rotation вокруг левого края
                .rotation3DEffect(
                    .degrees(-160 * Double(progress)),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.7
                )
                .shadow(
                    color: Color.black.opacity(0.15 * progress),
                    radius: 20 * progress,
                    x: -5 * progress,
                    y: 0
                )
        } else {
            content
        }
    }
}

// ─── PREVIEW ─────────────────────────────────────────────────

#Preview {
    OnboardingScreen()
        .environmentObject(AppState())
}

#Preview("Dark") {
    OnboardingScreen()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
