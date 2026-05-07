import SwiftUI

// ============================================================
// AUTH BACKGROUND
// Анимированный фон для экрана входа:
// — градиент рассвета (cream → peach)
// — солнце с пульсирующим свечением
// — три облака, плывущие справа налево
// — самолёт по орбитальной траектории вокруг центра
// ============================================================

struct AuthBackground: View {

    @State private var orbitAngle: Double = 0
    @State private var planePhase: Double = 0
    @State private var sunPulse: Bool = false
    @State private var cloudPhases: [Double] = [0.0, 0.35, 0.7]

    @State private var orbitCenter: CGPoint = .zero
    @State private var orbitRadius: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Градиент неба
                LinearGradient(
                    colors: [
                        Color(hex: 0xFAF6F1),
                        Color(hex: 0xF4D9B8),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // 2. Солнце с свечением
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: 0xF4D1A6).opacity(0.7),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 140, height: 140)
                    .position(x: geo.size.width - 60, y: 110)
                    .scaleEffect(sunPulse ? 1.15 : 1.0)
                    .opacity(sunPulse ? 1.0 : 0.7)
                    .animation(
                        .easeInOut(duration: 5).repeatForever(autoreverses: true),
                        value: sunPulse
                    )

                // 3. Облака
                ForEach(cloudPhases.indices, id: \.self) { idx in
                    CloudShape()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: cloudWidths[idx], height: cloudHeights[idx])
                        .position(
                            x: cloudX(geo: geo, phase: cloudPhases[idx]),
                            y: cloudYs[idx]
                        )
                }

                // 4. Орбитальная траектория (пунктир)
                Circle()
                    .stroke(
                        Color.Travello.terra.opacity(0.4),
                        style: StrokeStyle(
                            lineWidth: 0.5,
                            lineCap: .round,
                            dash: [4, 6]
                        )
                    )
                    .frame(width: orbitRadius * 2, height: orbitRadius * 2)
                    .position(orbitCenter)
                    .rotationEffect(.degrees(orbitAngle))

                // 5. Самолёт по орбите
                Text("✈")
                    .font(.custom("Fraunces72pt-Light", size: 24))
                    .foregroundColor(.Travello.terra)
                    .position(planePosition)
                    .rotationEffect(.degrees(planeRotation), anchor: .center)
            }
            .ignoresSafeArea()
            .onAppear {
                orbitCenter = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                orbitRadius = min(geo.size.width, geo.size.height) * 0.32
                startAnimations()
            }
        }
    }

    // ─── Animations ──────────────────────────────────────────

    private func startAnimations() {
        sunPulse = true

        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            orbitAngle = 360
        }

        withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
            planePhase = 1.0
        }

        let durations = [18.0, 24.0, 20.0]
        for i in cloudPhases.indices {
            withAnimation(.linear(duration: durations[i]).repeatForever(autoreverses: false)) {
                cloudPhases[i] = cloudPhases[i] + 1.0
            }
        }
    }

    // ─── Computed positions ──────────────────────────────────

    private var planePosition: CGPoint {
        let angleRad = orbitAngle * .pi / 180
        let dx = cos(angleRad) * orbitRadius
        let dy = sin(angleRad) * orbitRadius
        return CGPoint(
            x: orbitCenter.x + dx,
            y: orbitCenter.y + dy
        )
    }

    private var planeRotation: Double {
        let baseRotation = orbitAngle + 90
        let wobble = sin(planePhase * .pi * 2) * 8
        return baseRotation + wobble
    }

    private func cloudX(geo: GeometryProxy, phase: Double) -> CGFloat {
        let total = geo.size.width + 200
        let position = (phase.truncatingRemainder(dividingBy: 1.0)) * total
        return position - 100
    }

    private let cloudWidths:  [CGFloat] = [80, 60, 70]
    private let cloudHeights: [CGFloat] = [18, 14, 16]
    private let cloudYs:      [CGFloat] = [110, 180, 250]
}

// ============================================================
// CLOUD SHAPE
// ============================================================

struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let h = rect.height
        let w = rect.width

        path.addEllipse(in: CGRect(x: 0,          y: h * 0.2, width: h,        height: h * 0.8))
        path.addEllipse(in: CGRect(x: w * 0.25,   y: 0,       width: h * 1.1,  height: h))
        path.addEllipse(in: CGRect(x: w - h,       y: h * 0.2, width: h,        height: h * 0.8))
        path.addRect(   CGRect(x: h * 0.5,        y: h * 0.4, width: w - h,    height: h * 0.6))

        return path
    }
}

// ─── PREVIEW ─────────────────────────────────────────────────

#Preview {
    AuthBackground()
}
