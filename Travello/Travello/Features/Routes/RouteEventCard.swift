import SwiftUI

// ============================================================
// ROUTE EVENT CARD
// Одно событие в таймлайне дня.
// Editorial-стиль: время курсивом слева,
// карточка с тегом, заголовком, метой и AI-советом.
// ============================================================

struct RouteEventCard: View {
    let event: RouteEvent
    let isLast: Bool

    @State private var expanded = false

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {

            // ── Левая колонка: время + вертикальная линия ────
            VStack(spacing: 0) {
                Text(event.timeString ?? "")
                    .font(.Travello.italicSmall)
                    .foregroundColor(.Travello.terra)
                    .frame(width: 38, alignment: .trailing)
                    .frame(height: 22)

                if !isLast {
                    Rectangle()
                        .fill(Color.Travello.line)
                        .frame(width: Stroke.hairline)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }

            // ── Правая колонка: карточка события ─────────────
            VStack(alignment: .leading, spacing: 0) {
                eventCard
                    .padding(.bottom, isLast ? 0 : Spacing.md)
            }
        }
    }

    // ─── Event Card ──────────────────────────────────────────

    private var eventCard: some View {
        Button {
            withAnimation(Anim.spring) { expanded.toggle() }
            Haptics.tap()
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {

                // Тег типа + маркер на линии
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 7, height: 7)
                        .offset(x: -Spacing.md - 3.5)   // выровнять на линию

                    Text(event.eventType.label)
                        .eyebrowSmall(accentColor)

                    Spacer()

                    if event.isPrepaid {
                        Text("предоплачено")
                            .eyebrowSmall(.Travello.olive)
                    }
                }

                // Название
                Text(event.title ?? "")
                    .font(.Travello.h3)
                    .foregroundColor(.Travello.ink)
                    .lineLimit(expanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)

                // Мета-строка
                HStack(spacing: Spacing.xs) {
                    if let dur = event.durationString {
                        Label(dur, systemImage: "clock")
                            .metaLabel()
                    }
                    if let cost = event.costString {
                        Label(cost, systemImage: "dollarsign")
                            .metaLabel()
                        Spacer()
                    } else {
                        Spacer()
                    }
                }

                // AI-совет (раскрывается)
                if let tip = event.aiTip, expanded {
                    HStack(alignment: .top, spacing: Spacing.xs) {
                        Rectangle()
                            .fill(Color.Travello.apricot)
                            .frame(width: 2)
                            .cornerRadius(1)

                        Text(tip)
                            .font(.Travello.italic)
                            .foregroundColor(.Travello.inkSoft)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, Spacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Описание (раскрывается)
                if let desc = event.description, !desc.isEmpty, expanded {
                    Text(desc)
                        .font(.Travello.caption)
                        .foregroundColor(.Travello.mute)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }

                // Кнопка «показать маршрут» для event с координатами
                if expanded, event.coordinate != nil {
                    Button {
                        openInMaps()
                    } label: {
                        Label("Открыть в картах", systemImage: "map")
                            .font(.Travello.caption)
                            .foregroundColor(.Travello.terra)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Spacing.xs)
                    .transition(.opacity)
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.Travello.line, lineWidth: Stroke.hairline)
            )
        }
        .buttonStyle(.plain)
    }

    // ─── Helpers ─────────────────────────────────────────────

    private var accentColor: Color {
        switch event.eventType {
        case .flight:        return .Travello.terra
        case .accommodation: return .Travello.olive
        case .restaurant:    return .Travello.apricot
        case .activity:      return .Travello.terra
        default:             return .Travello.mute
        }
    }

    private var cardBackground: Color {
        switch event.eventType {
        case .flight:        return Color.Travello.terra.opacity(0.04)
        case .accommodation: return Color.Travello.olive.opacity(0.04)
        case .restaurant:    return Color.Travello.apricot.opacity(0.04)
        default:             return Color.Travello.paper
        }
    }

    private func openInMaps() {
        guard let coord = event.coordinate else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        mapItem.name = event.locationName ?? event.title
        mapItem.openInMaps()
    }
}

// ─── META LABEL MODIFIER ─────────────────────────────────────

extension View {
    func metaLabel() -> some View {
        self
            .font(.Travello.caption)
            .foregroundColor(.Travello.mute)
            .labelStyle(.titleAndIcon)
    }
}

import MapKit

// ─── PREVIEW ─────────────────────────────────────────────────

#Preview {
    let event = RouteEvent(
        id: UUID(), eventType: .restaurant, sortOrder: 0,
        title: "Vanilla Restaurant", description: "Лучший вид на залив",
        startsAt: Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()),
        endsAt: nil, durationMin: 90, locationName: "Kaleiçi",
        address: "Kaleiçi, Antalya", coordinate: nil,
        imageUrl: nil, costEst: 35, currency: "USD", isPrepaid: false,
        bookingRef: nil,
        aiTip: "Берите столик на террасе — вид на яхты просто потрясающий"
    )
    VStack {
        RouteEventCard(event: event, isLast: false)
        RouteEventCard(event: event, isLast: true)
    }
    .padding()
    .background(Color.Travello.cream)
}
