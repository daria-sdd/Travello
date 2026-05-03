import SwiftUI
import MapKit

// ============================================================
// ROUTE MAP VIEW
// MapKit с пинами всех городов маршрута.
// Используется как фон под шторкой вариантов
// и как отдельный экран при детальном просмотре.
// ============================================================

struct RouteMapView: View {
    let routes: [Route]

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
        span:   MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
    )

    // Все уникальные координаты из событий маршрутов
    private var allAnnotations: [RouteAnnotation] {
        var seen = Set<String>()
        return routes.flatMap { route in
            route.days.flatMap { day in
                day.events.compactMap { event -> RouteAnnotation? in
                    guard let coord = event.coordinate else { return nil }
                    let key = "\(coord.latitude),\(coord.longitude)"
                    guard seen.insert(key).inserted else { return nil }
                    return RouteAnnotation(
                        id:    event.id,
                        coord: coord,
                        title: event.locationName ?? event.title ?? "",
                        type:  event.eventType
                    )
                }
            }
        }
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: allAnnotations) { annotation in
            MapAnnotation(coordinate: annotation.coord) {
                RoutePin(type: annotation.type)
            }
        }
        .onAppear { fitRegion() }
        .onChange(of: routes) { _, _ in fitRegion() }
    }

    // Подбираем регион так чтобы влезли все точки
    private func fitRegion() {
        let coords = allAnnotations.map(\.coord)
        guard !coords.isEmpty else { return }

        let lats  = coords.map(\.latitude)
        let lngs  = coords.map(\.longitude)
        let minLat = lats.min()!; let maxLat = lats.max()!
        let minLng = lngs.min()!; let maxLng = lngs.max()!

        let center = CLLocationCoordinate2D(
            latitude:  (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta:  max((maxLat - minLat) * 1.4, 1.5),
            longitudeDelta: max((maxLng - minLng) * 1.4, 1.5)
        )
        withAnimation(Anim.smooth) {
            region = MKCoordinateRegion(center: center, span: span)
        }
    }
}

// ─── ANNOTATION ──────────────────────────────────────────────

struct RouteAnnotation: Identifiable {
    let id:    UUID
    let coord: CLLocationCoordinate2D
    let title: String
    let type:  EventType
}

// ─── PIN ─────────────────────────────────────────────────────

struct RoutePin: View {
    let type: EventType
    @State private var appear = false

    var pinColor: Color {
        switch type {
        case .flight:        return .Travello.terra
        case .accommodation: return .Travello.olive
        case .restaurant:    return .Travello.apricot
        default:             return .Travello.terra
        }
    }

    var body: some View {
        ZStack {
            // Тень
            Ellipse()
                .fill(pinColor.opacity(0.25))
                .frame(width: 20, height: 8)
                .offset(y: 18)
                .blur(radius: 3)

            // Тело пина (капля)
            PinShape()
                .fill(pinColor)
                .frame(width: 22, height: 30)

            // Белая точка внутри
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .offset(y: -4)
        }
        .scaleEffect(appear ? 1 : 0, anchor: .bottom)
        .animation(Anim.spring.delay(Double.random(in: 0...0.3)), value: appear)
        .onAppear { appear = true }
    }
}

private struct PinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width; let h = rect.height
        let r = w / 2

        // Полукруг сверху
        p.addArc(
            center:     CGPoint(x: w/2, y: r),
            radius:     r,
            startAngle: .degrees(180),
            endAngle:   .degrees(0),
            clockwise:  false
        )
        // Острие снизу
        p.addLine(to: CGPoint(x: w, y: r))
        p.addCurve(
            to:       CGPoint(x: w/2, y: h),
            control1: CGPoint(x: w, y: h * 0.65),
            control2: CGPoint(x: w/2 + 6, y: h * 0.85)
        )
        p.addCurve(
            to:       CGPoint(x: 0, y: r),
            control1: CGPoint(x: w/2 - 6, y: h * 0.85),
            control2: CGPoint(x: 0, y: h * 0.65)
        )
        return p
    }
}
