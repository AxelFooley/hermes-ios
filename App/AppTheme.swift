import SwiftUI
import HermesKit

extension Color {
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6, let rgb = UInt64(value, radix: 16) else {
            self = .gray
            return
        }
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0,
            opacity: 1
        )
    }
}

struct HermesPalette {
    let theme: Theme

    var primary: Color { Color(hex: theme.color.primary) }
    var accent: Color { Color(hex: theme.color.accent) }
    var border: Color { Color(hex: theme.color.border) }
    var text: Color { Color(hex: theme.color.text) }
    var muted: Color { Color(hex: theme.color.muted) }
    var label: Color { Color(hex: theme.color.label) }
    var ok: Color { Color(hex: theme.color.ok) }
    var error: Color { Color(hex: theme.color.error) }
    var warn: Color { Color(hex: theme.color.warn) }
    var surface: Color { Color(hex: theme.color.statusBg) }
    var statusFg: Color { Color(hex: theme.color.statusFg) }
    var shellDollar: Color { Color(hex: theme.color.shellDollar) }

    static let standard = HermesPalette(theme: .dark)
}

struct Kaomoji {
    static let faces = ["( ◕‿◕ )", "( ^‿^ )", "( ✿‿✿ )", "( ˘‿˘ )", "( •‿• )", "( ‿ )"]

    static func face(after index: Int) -> String {
        faces[max(0, index) % faces.count]
    }
}
