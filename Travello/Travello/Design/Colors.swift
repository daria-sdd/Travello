import SwiftUI

// ============================================================
// COLORS
// Палитра travello — кремово-терракотовая, тёплая.
// Адаптивные цвета хранятся в Assets.xcassets (Any / Dark).
// Статичные акценты задаются через hex прямо здесь.
//
// Как добавить цвет в Assets.xcassets:
//   1. Открыть Assets.xcassets
//   2. + → New Color Set
//   3. Назвать как указано ниже (например "TravelloCream")
//   4. В инспекторе: Appearances → Any, Dark
//   5. Вставить hex для каждого варианта
// ============================================================

extension Color {

    enum Travello {

        // ── Backgrounds ──────────────────────────────────────
        //  Name in Assets          Any (light)   Dark
        //  TravelloCream           #FAF6F1       #1A1410
        //  TravelloSand            #F5EBDC       #231C13
        //  TravelloPaper           #FFFFFF       #2D2419
        //  TravelloElevated        #FFFFFF       #3A2F22

        static let cream    = Color("TravelloCream")
        static let sand     = Color("TravelloSand")
        static let paper    = Color("TravelloPaper")
        static let elevated = Color("TravelloElevated")

        // ── Text ─────────────────────────────────────────────
        //  TravelloInk             #2A1F12       #F4EBDD
        //  TravelloInkSoft         #4A3B28       #C9B89A
        //  TravelloMute            #7A6B58       #B5A48E
        //  TravelloTertiary        #A89989       #7A6B58

        static let ink      = Color("TravelloInk")
        static let inkSoft  = Color("TravelloInkSoft")
        static let mute     = Color("TravelloMute")
        static let tertiary = Color("TravelloTertiary")

        // ── Accents ──────────────────────────────────────────
        //  TravelloTerra           #D8743A       #E89968
        //  TravelloOlive           #5A8C66       #9FC4A8
        //
        //  apricot, honey, burnt — одинаковы в обеих темах,
        //  поэтому заданы hex прямо здесь (без Asset).

        static let terra    = Color("TravelloTerra")
        static let apricot  = Color(hex: 0xE89968)
        static let honey    = Color(hex: 0xE0BC8E)
        static let olive    = Color("TravelloOlive")
        static let burnt    = Color(hex: 0x8B5424)

        // ── Lines & dividers ─────────────────────────────────
        //  TravelloLine            #E8DDD0       #3A2F22
        //  TravelloHairline        #F0E5D5       #2D2419

        static let line     = Color("TravelloLine")
        static let hairline = Color("TravelloHairline")

        // ── Status ───────────────────────────────────────────

        static let success  = olive
        static let warning  = Color(hex: 0xBA7517)
        static let danger   = Color(hex: 0xA02525)
    }
}

// ============================================================
// Color hex helper — без UIKit
// ============================================================

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:     Double((hex >> 16) & 0xFF) / 255,
            green:   Double((hex >>  8) & 0xFF) / 255,
            blue:    Double( hex        & 0xFF) / 255,
            opacity: alpha
        )
    }
}
