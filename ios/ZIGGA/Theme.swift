import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

/// Палитра ZIGGA поверх нового тёмно-синего фона.
enum Zig {
    static let background = Color(hex: 0x05070D)
    static let text = Color(hex: 0xF3F7EC)
    static let neon = Color(hex: 0xB4E832)
    static let gold = Color(hex: 0xE3B23C)
    static let muted = Color(hex: 0x98A4B8)
    static let card = Color.white.opacity(0.10)
    static let stroke = Color.white.opacity(0.16)
    static let danger = Color(hex: 0xFF6B6B)
    static let disc = Color(hex: 0x0B101C)
    static let offAccent = Color(hex: 0x8FA6C6)
    static let dimRing = Color(hex: 0x1B2434)
}

struct ZigCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Zig.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Zig.stroke, lineWidth: 1)
            )
    }
}
