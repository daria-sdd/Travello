import SwiftUI

// ============================================================
// BOOKING CARDS — 5 ТИПОВ
// Каждая карточка — самодостаточный блок.
// Тап по карточке в маршруте → раскрытый экран с деталями.
// BookingCardView — роутер который выбирает нужный тип.
// ============================================================

struct BookingCardView: View {
    let booking: BookingDTO

    var body: some View {
        // Роутер по eventType из связанного события
        // В реальном проекте bookingDTO содержит type,
        // здесь определяем по providerName для демо
        Group {
            if booking.providerName?.lowercased().contains("hotel") == true ||
               booking.providerName?.lowercased().contains("отель") == true {
                HotelBookingCard(booking: booking)
            } else if booking.providerName?.lowercased().contains("transfer") == true ||
                      booking.providerName?.lowercased().contains("трансфер") == true {
                TransportBookingCard(booking: booking)
            } else {
                FlightBookingCard(booking: booking)
            }
        }
    }
}

// ============================================================
// 1. FLIGHT CARD
// ============================================================

struct FlightBookingCard: View {
    let booking: BookingDTO
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Шапка: авиакомпания + статус ─────────────────
            HStack {
                HStack(spacing: Spacing.sm) {
                    AirlineLogoPlaceholder(code: "TK")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Turkish Airlines")
                            .font(.Travello.bodyBold).foregroundColor(.Travello.ink)
                        Text("TK412  ·  Boeing 737")
                            .font(.Travello.caption).foregroundColor(.Travello.mute)
                    }
                }
                Spacer()
                StatusBadge(status: booking.status)
            }
            .padding(Spacing.md)

            SoftRule().padding(.horizontal, Spacing.md)

            // ── Маршрут рейса ─────────────────────────────────
            HStack(spacing: 0) {
                FlightPort(code: "SVO", city: "Москва", time: "08:30", date: "17 окт")
                VStack(spacing: 3) {
                    Text("✈").font(.system(size: 16)).foregroundColor(.Travello.terra)
                    Text("3ч 30м · прямой")
                        .font(.Travello.caption).foregroundColor(.Travello.mute)
                }
                .frame(maxWidth: .infinity)
                FlightPort(code: "AYT", city: "Анталья", time: "12:00", date: "17 окт", trailing: true)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)

            // ── Детали (раскрываются) ─────────────────────────
            if expanded {
                SoftRule().padding(.horizontal, Spacing.md)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                    DetailCell(label: "бронь", value: booking.bookingRef ?? "—")
                    DetailCell(label: "место", value: "14F · окно")
                    DetailCell(label: "багаж", value: "23 кг + 8 кг")
                    DetailCell(label: "терминал", value: "D · выход 24")
                }
                .padding(Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            SoftRule().padding(.horizontal, Spacing.md)

            // ── Подвал: цена + действие ───────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    if let amount = booking.amountPaid {
                        Text("$\(Int(amount))")
                            .font(.Travello.h3).foregroundColor(.Travello.terra)
                    }
                    Text("за человека").eyebrowSmall()
                }
                Spacer()
                if let url = booking.bookingUrl {
                    BookingActionButton(title: "Открыть бронь", url: url)
                }
                Button {
                    withAnimation(Anim.spring) { expanded.toggle() }
                    Haptics.tap()
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.Travello.mute)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.Travello.sand))
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.md)
        }
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(Color.Travello.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.Travello.line, lineWidth: Stroke.hairline))
        .softShadow()
    }
}

private struct FlightPort: View {
    let code: String; let city: String; let time: String; let date: String
    var trailing: Bool = false
    var body: some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(code).font(.custom("Fraunces-Medium", size: 22)).foregroundColor(.Travello.ink)
            Text(city).font(.Travello.caption).foregroundColor(.Travello.mute)
            Text(time).font(.Travello.bodyBold).foregroundColor(.Travello.ink).padding(.top, 4)
            Text(date).eyebrowSmall()
        }
        .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
    }
}

// ============================================================
// 2. HOTEL CARD
// ============================================================

struct HotelBookingCard: View {
    let booking: BookingDTO

    var body: some View {
        VStack(spacing: 0) {
            // Обложка-градиент с рейтингом
            ZStack(alignment: .bottomTrailing) {
                LinearGradient(
                    colors: [.Travello.apricot, .Travello.terra],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(height: 90)

                HStack(spacing: 2) {
                    Image(systemName: "star.fill").font(.system(size: 9)).foregroundColor(.Travello.terra)
                    Text("4.8").font(.Travello.caption).foregroundColor(.Travello.ink).fontWeight(.semibold)
                    Text("· 1.2k").font(.Travello.caption).foregroundColor(.Travello.mute)
                }
                .padding(.horizontal, Spacing.sm).padding(.vertical, 4)
                .background(Capsule().fill(Color.Travello.paper))
                .padding(Spacing.sm)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(booking.providerName ?? "Отель")
                            .font(.Travello.h3).foregroundColor(.Travello.ink)
                        HStack(spacing: 3) {
                            Image(systemName: "mappin").font(.system(size: 10))
                            Text("Калеичи · 200м от моря")
                        }
                        .font(.Travello.caption).foregroundColor(.Travello.mute)
                    }
                    Spacer()
                    StatusBadge(status: booking.status)
                }

                SoftRule()

                HStack {
                    DateCell(label: "заезд",  value: booking.validFrom ?? "—")
                    Spacer()
                    Image(systemName: "arrow.right").foregroundColor(.Travello.tertiary).font(.system(size: 11))
                    Spacer()
                    DateCell(label: "выезд", value: booking.validTo ?? "—", trailing: true)
                }

                SoftRule()

                HStack {
                    if let amount = booking.amountPaid {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("$\(Int(amount))")
                                .font(.Travello.h3).foregroundColor(.Travello.terra)
                            Text("за всё проживание").eyebrowSmall()
                        }
                    }
                    Spacer()
                    if let url = booking.bookingUrl {
                        BookingActionButton(title: "Booking.com", url: url)
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(Color.Travello.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.Travello.line, lineWidth: Stroke.hairline))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .softShadow()
    }
}

// ============================================================
// 3. PLACE CARD
// ============================================================

struct PlaceBookingCard: View {
    let title: String
    let category: String
    let rating: Double
    let duration: String
    let cost: String
    let aiTip: String?
    let address: String?
    let isOpen: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Обложка с тегом
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [Color(uiColor: .init(hex: 0xC7A584)), Color(uiColor: .init(hex: 0x8B6A4F))],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(height: 100)

                HStack {
                    CategoryBadge(text: category)
                    Spacer()
                    Text("⏱ \(duration)")
                        .font(.Travello.caption).foregroundColor(.white)
                        .padding(.horizontal, Spacing.sm).padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.35)))
                }
                .padding(Spacing.sm)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.Travello.h3).foregroundColor(.Travello.ink).lineLimit(2)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").font(.system(size: 9)).foregroundColor(.Travello.apricot)
                            Text(String(format: "%.1f", rating)).font(.Travello.caption).foregroundColor(.Travello.ink)
                        }
                    }
                }

                if let addr = address {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin").font(.system(size: 10))
                        Text(addr)
                    }
                    .font(.Travello.caption).foregroundColor(.Travello.mute)
                }

                HStack {
                    Text(isOpen ? "Открыто" : "Закрыто")
                        .eyebrowSmall(isOpen ? .Travello.olive : .Travello.danger)
                    Text(cost).font(.Travello.bodyBold).foregroundColor(.Travello.ink)
                    Spacer()
                }

                if let tip = aiTip {
                    HStack(alignment: .top, spacing: 5) {
                        Rectangle().fill(Color.Travello.apricot).frame(width: 2).cornerRadius(1)
                        Text(tip).font(.Travello.italic).foregroundColor(.Travello.inkSoft)
                            .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: Spacing.sm) {
                    Button { } label: {
                        Label("Маршрут", systemImage: "arrow.triangle.turn.up.right.circle")
                            .font(.Travello.caption).foregroundColor(.white)
                            .padding(.horizontal, Spacing.md).padding(.vertical, 8)
                            .background(Capsule().fill(Color.Travello.terra))
                    }.buttonStyle(.plain)

                    Button { } label: {
                        Text("Сохранить")
                            .font(.Travello.caption).foregroundColor(.Travello.ink)
                            .padding(.horizontal, Spacing.md).padding(.vertical, 8)
                            .background(Capsule().fill(Color.Travello.sand))
                            .overlay(Capsule().stroke(Color.Travello.line, lineWidth: Stroke.hairline))
                    }.buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
        }
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(Color.Travello.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.Travello.line, lineWidth: Stroke.hairline))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .softShadow()
    }
}

// ============================================================
// 4. TRANSPORT CARD
// ============================================================

struct TransportBookingCard: View {
    let booking: BookingDTO

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(Color.Travello.sand).frame(width: 44, height: 44)
                    Text("🚗").font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Трансфер").font(.Travello.bodyBold).foregroundColor(.Travello.ink)
                    Text(booking.providerName ?? "GetTransfer").font(.Travello.caption).foregroundColor(.Travello.mute)
                }
                Spacer()
                StatusBadge(status: booking.status)
            }
            .padding(Spacing.md)

            SoftRule().padding(.horizontal, Spacing.md)

            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Аэропорт AYT").font(.Travello.bodyBold).foregroundColor(.Travello.ink)
                    Text(booking.validFrom ?? "").font(.Travello.caption).foregroundColor(.Travello.mute)
                }
                Image(systemName: "arrow.right")
                    .foregroundColor(.Travello.terra).font(.system(size: 18))
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Отель").font(.Travello.bodyBold).foregroundColor(.Travello.ink)
                    Text("~25 мин").font(.Travello.caption).foregroundColor(.Travello.mute)
                }
            }
            .padding(Spacing.md)

            SoftRule().padding(.horizontal, Spacing.md)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                DetailCell(label: "водитель", value: "Мехмет К.")
                DetailCell(label: "пассажиров", value: "2")
            }
            .padding(Spacing.md)

            SoftRule().padding(.horizontal, Spacing.md)

            HStack {
                if let amount = booking.amountPaid {
                    Text("$\(Int(amount))").font(.Travello.h3).foregroundColor(.Travello.terra)
                    Text("за поездку").eyebrowSmall()
                }
                Spacer()
                Button { } label: {
                    Text("Связаться ↗")
                        .font(.Travello.caption).foregroundColor(.Travello.terra)
                        .padding(.horizontal, Spacing.md).padding(.vertical, 8)
                        .background(Capsule().fill(Color.Travello.sand))
                        .overlay(Capsule().stroke(Color.Travello.terra.opacity(0.4), lineWidth: Stroke.hairline))
                }.buttonStyle(.plain)
            }
            .padding(Spacing.md)
        }
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(Color.Travello.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.Travello.line, lineWidth: Stroke.hairline))
        .softShadow()
    }
}

// ============================================================
// 5. RESTAURANT CARD
// ============================================================

struct RestaurantBookingCard: View {
    let name: String
    let cuisine: String
    let rating: Double
    let reservationTime: String
    let tableInfo: String
    let confirmCode: String
    let cancelDeadline: String
    let dressCode: String?
    let bookingUrl: String?

    var body: some View {
        VStack(spacing: 0) {
            // Обложка
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [Color(uiColor: .init(hex: 0xF4C36F)), Color(uiColor: .init(hex: 0xE8A53A))],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(height: 90)
                CategoryBadge(text: cuisine)
                    .padding(Spacing.sm)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text(name).font(.Travello.h3).foregroundColor(.Travello.ink)
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 9)).foregroundColor(.Travello.apricot)
                        Text(String(format: "%.1f", rating)).font(.Travello.caption).foregroundColor(.Travello.ink)
                    }
                }

                // Блок резерва
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    EyebrowLine(text: "резерв на ваше имя")
                    HStack {
                        DetailCell(label: "время", value: reservationTime)
                        Spacer()
                        DetailCell(label: "столик", value: tableInfo, trailing: true)
                    }
                    HStack {
                        Text("Подтверждение:").font(.Travello.caption).foregroundColor(.Travello.mute)
                        Text(confirmCode).font(.Travello.bodyBold).foregroundColor(.Travello.olive)
                    }
                }
                .padding(Spacing.sm)
                .background(RoundedRectangle(cornerRadius: Radius.sm).fill(Color.Travello.sand))

                // Предупреждения
                VStack(alignment: .leading, spacing: 4) {
                    Label("Отмена до \(cancelDeadline)", systemImage: "clock")
                        .font(.Travello.caption).foregroundColor(.Travello.mute)
                    if let dress = dressCode {
                        Label(dress, systemImage: "tshirt")
                            .font(.Travello.caption).foregroundColor(.Travello.mute)
                    }
                }

                HStack {
                    Spacer()
                    if let url = bookingUrl {
                        BookingActionButton(title: "Открыть в картах", url: url)
                    }
                    Button { } label: {
                        Text("Изменить")
                            .font(.Travello.caption).foregroundColor(.Travello.mute)
                            .padding(.horizontal, Spacing.md).padding(.vertical, 8)
                            .background(Capsule().fill(Color.Travello.sand))
                    }.buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
        }
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(Color.Travello.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.Travello.line, lineWidth: Stroke.hairline))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .softShadow()
    }
}

// ============================================================
// SHARED SUBCOMPONENTS
// ============================================================

private struct AirlineLogoPlaceholder: View {
    let code: String
    var body: some View {
        Text(code)
            .font(.Travello.eyebrow).tracking(1).foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(RoundedRectangle(cornerRadius: Radius.xs).fill(Color.Travello.terra))
    }
}

struct StatusBadge: View {
    let status: String
    var color: Color {
        switch status.lowercased() {
        case "confirmed": return .Travello.olive
        case "pending":   return .Travello.warning
        case "cancelled": return .Travello.danger
        default:          return .Travello.mute
        }
    }
    var label: String {
        switch status.lowercased() {
        case "confirmed": return "подтверждено"
        case "pending":   return "ожидает"
        case "cancelled": return "отменено"
        default:          return status
        }
    }
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label).eyebrowSmall(color)
        }
    }
}

private struct DetailCell: View {
    let label: String; let value: String; var trailing: Bool = false
    var body: some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(label).eyebrowSmall()
            Text(value).font(.Travello.bodyBold).foregroundColor(.Travello.ink)
        }
    }
}

private struct DateCell: View {
    let label: String; let value: String; var trailing: Bool = false
    var body: some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(label).eyebrowSmall()
            Text(value).font(.Travello.h3).foregroundColor(.Travello.ink)
        }
    }
}

private struct CategoryBadge: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.Travello.eyebrowSmall).tracking(1.2).foregroundColor(.Travello.ink)
            .padding(.horizontal, Spacing.sm).padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.8)))
    }
}

struct BookingActionButton: View {
    let title: String; let url: String
    var body: some View {
        Link(destination: URL(string: url) ?? URL(string: "https://")!) {
            Text(title)
                .font(.Travello.caption).foregroundColor(.Travello.terra)
                .padding(.horizontal, Spacing.md).padding(.vertical, 8)
                .background(Capsule().fill(Color.Travello.sand))
                .overlay(Capsule().stroke(Color.Travello.terra.opacity(0.5), lineWidth: Stroke.hairline))
        }
    }
}
