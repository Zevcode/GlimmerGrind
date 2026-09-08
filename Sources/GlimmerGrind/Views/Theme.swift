import SwiftUI

// MARK: - Palette (ember on graphite)

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Pal {
    // graphite ground — warm-biased neutrals, no blue cast
    static let void     = Color(hex: 0x0C0B0C)
    static let hull     = Color(hex: 0x161315)
    static let plate    = Color(hex: 0x221E20)
    static let plateHi  = Color(hex: 0x2E2A2C)
    static let rail     = Color(hex: 0x3C3639)
    static let edge     = Color.white.opacity(0.06)

    static let bone     = Color(hex: 0xF1ECE4)
    static let ash      = Color(hex: 0xA09792)
    static let dim      = Color(hex: 0x6C6460)

    // the Light — an ember range, not one swatch
    static let ember    = Color(hex: 0xD8441A)
    static let solar    = Color(hex: 0xFF8A3D)
    static let gold     = Color(hex: 0xFFC46B)

    // currencies read apart from one another
    static let glimmer  = Color(hex: 0x5CD0C4)
    static let shard    = Color(hex: 0xB366E8)

    static let arc      = Color(hex: 0x7FD8FF)
    static let ok       = Color(hex: 0x6FCF8E)
    static let warn     = Color(hex: 0xEFD84E)
    static let bad      = Color(hex: 0xE0574F)
}

// MARK: - Type roles

extension Font {
    /// Squared HUD display face — condensed system with heavy tracking.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
    /// Data / ticker face.
    static func data(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Chamfered plate

struct Chamfer: Shape {
    var cut: CGFloat = 9

    func path(in rect: CGRect) -> Path {
        let c = min(cut, min(rect.width, rect.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        p.closeSubpath()
        return p
    }
}

// MARK: - Reusable chrome

struct PanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Pal.hull)
            .overlay(alignment: .top) { Pal.edge.frame(height: 1) }
            .overlay(Rectangle().stroke(Pal.rail, lineWidth: 1))
    }
}

extension View {
    func panel() -> some View { modifier(PanelBackground()) }

    /// Uppercase micro-label used for every field caption in the HUD.
    func hudLabel() -> some View {
        self.font(.data(9))
            .tracking(1.8)
            .textCase(.uppercase)
            .foregroundStyle(Pal.dim)
    }
}

struct HudButtonStyle: ButtonStyle {
    var hot: Bool = false
    var ghost: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(11, .semibold))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(hot ? Color(hex: 0x12060A) : Pal.bone)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background {
                let shape = Chamfer()
                if hot {
                    shape.fill(configuration.isPressed ? Pal.gold : Pal.solar)
                } else if ghost {
                    shape.stroke(Pal.rail, lineWidth: 1)
                        .background(shape.fill(configuration.isPressed ? Pal.plate : .clear))
                } else {
                    shape.fill(configuration.isPressed ? Pal.plateHi : Pal.plate)
                }
            }
            .contentShape(Chamfer())
    }
}
