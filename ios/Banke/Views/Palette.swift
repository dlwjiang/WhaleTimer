import SwiftUI

// Shared ink and material colors come from the web app's style.css.
enum Palette {
    static let paper = Color(hex: 0xedf2f7)
    static let ink = Color(hex: 0x253451)
    static let fern = Color(hex: 0x426bd0)
    static let moss = Color(hex: 0xcad9fa)
    static let clay = Color(hex: 0xa9502e)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255)
    }
}

struct CompanionTheme {
    let accent: Color
    let soft: Color
    let top: Color
    let bottom: Color
    let edge: Color
    let hinge: Color
    let digit: Color
    let backdrop: String
    let clock: ClockMaterial

    init(_ companion: Companion) {
        clock = ClockMaterial(companion)
        // Preserve the web's blue and warm scholarly material recipes.
        if companion == .mochi || companion == .pebble {
            accent = Color(hex: 0x426bd0); soft = Color(hex: 0xeaf0ff)
            top = Color(hex: 0x233b5d); bottom = Color(hex: 0x395d83)
            edge = Color(hex: 0x13263f); hinge = Color(hex: 0x8bbcd4)
            digit = Color(hex: 0xeef9ff); backdrop = "scene-pearl"
        } else if companion == .pip {
            accent = Color(hex: 0xa9502e); soft = Color(hex: 0xfff0e5)
            top = Color(hex: 0x4b3028); bottom = Color(hex: 0x78523d)
            edge = Color(hex: 0x321d18); hinge = Color(hex: 0xd7a464)
            digit = Color(hex: 0xfff0d5); backdrop = "scene-study"
        } else {
            let pack = companion.pack ?? .midnightCafe
            backdrop = pack.backdrop
            switch pack {
            case .midnightCafe:
                accent = Color(hex: 0x9a583d); soft = Color(hex: 0xffeee0)
                top = Color(hex: 0x382e32); bottom = Color(hex: 0x68504b)
                edge = Color(hex: 0x262333); hinge = Color(hex: 0xe4b27d); digit = Color(hex: 0xffecd0)
            case .moonlightAcademy:
                accent = Color(hex: 0x7a58ae); soft = Color(hex: 0xf2ebfd)
                top = Color(hex: 0xddd2ee); bottom = Color(hex: 0xf8f3ff)
                edge = Color(hex: 0xaa98c2); hinge = Color(hex: 0xa894bd); digit = Color(hex: 0x514066)
            case .orbitalNightShift:
                accent = Color(hex: 0x286f76); soft = Color(hex: 0xe0f3f2)
                top = Color(hex: 0x173a49); bottom = Color(hex: 0x326c76)
                edge = Color(hex: 0x102d3b); hinge = Color(hex: 0x9cddd4); digit = Color(hex: 0xecfffa)
            }
        }
    }
}

/// Additional surface stops from character-theme.css; the face ends, ink and
/// pivots remain in CompanionTheme. Premium rooms use the same material model.
struct ClockMaterial {
    let topStart: Color
    let bottomStart: Color
    let base: Color
    let seam: Color
    let separator: Color
    let shadow: Color
    let textShadow: Color
    let textShadowRadius: CGFloat

    init(_ companion: Companion) {
        switch companion {
        case .mochi, .pebble:
            self.init(topStart: 0x34567d, bottomStart: 0x294363, base: 0x192e4b,
                      seam: 0x10213a, separator: 0x536e91, shadow: 0x182d4d, shadowAlpha: 0x25)
        case .pip:
            self.init(topStart: 0x714c38, bottomStart: 0x58382c, base: 0x3c251e,
                      seam: 0x342018, separator: 0x946747, shadow: 0x57301c, shadowAlpha: 0x30)
        case .jun, .bean, .maple:
            self.init(topStart: 0x604744, bottomStart: 0x493739, base: 0x30262c,
                      seam: 0x262333, separator: 0x946b52, shadow: 0x382733, shadowAlpha: 0x30)
        case .luna, .atlas, .wisp:
            self.init(topStart: 0xfaf7ff, bottomStart: 0xe8ddf4, base: 0xc7b7dc,
                      seam: 0xbcaaca, separator: 0x806c97, shadow: 0x66517d, shadowAlpha: 0x28,
                      lightTextShadow: true)
        case .nova, .orbit, .comet:
            self.init(topStart: 0x2b5966, bottomStart: 0x204b58, base: 0x142f3d,
                      seam: 0x102d3b, separator: 0x568c95, shadow: 0x142f3d, shadowAlpha: 0x30)
        }
    }

    private init(topStart: UInt32, bottomStart: UInt32, base: UInt32, seam: UInt32,
                 separator: UInt32, shadow: UInt32, shadowAlpha: UInt32, lightTextShadow: Bool = false) {
        self.topStart = Color(hex: topStart)
        self.bottomStart = Color(hex: bottomStart)
        self.base = Color(hex: base)
        self.seam = Color(hex: seam)
        self.separator = Color(hex: separator)
        self.shadow = Color(hex: shadow).opacity(Double(shadowAlpha) / 255)
        textShadow = lightTextShadow ? .white.opacity(160.0 / 255) : .black.opacity(1.0 / 3)
        textShadowRadius = lightTextShadow ? 0 : 1
    }
}

struct GlassSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var tint: Color = Palette.paper
    var radius: CGFloat = 26
    var native = false
    @ViewBuilder
    func body(content: Content) -> some View {
        if native, !reduceTransparency, #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(tint.opacity(0.08)), in: .rect(cornerRadius: radius))
        } else { content
            .background {
                RoundedRectangle(cornerRadius: radius)
                    .fill(reduceTransparency ? tint : tint.opacity(0.18))
                    .background {
                        if !reduceTransparency {
                            RoundedRectangle(cornerRadius: radius).fill(.ultraThinMaterial.opacity(0.55))
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius)
                            .fill(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.06), tint.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius)
                            .strokeBorder(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    }
                    .shadow(color: Palette.ink.opacity(0.07), radius: 18, y: 8)
            }
        }
    }
}

struct GlassKey: ButtonStyle {
    let theme: CompanionTheme
    var engaged = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(theme.accent)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(theme.accent.opacity(engaged ? 0.15 : 0.04), in: RoundedRectangle(cornerRadius: 18))
            .modifier(GlassSurface(tint: theme.soft, radius: 18))
            .background {
                RoundedRectangle(cornerRadius: 18).fill(theme.soft)
                    .shadow(color: theme.accent.opacity(engaged ? 0 : 0.22), radius: 0, y: 3)
            }
            // Running changes the surface, not the label's resting baseline.
            .offset(y: configuration.isPressed && !reduceMotion ? 3 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

extension View {
    func paperCard() -> some View { padding(24).modifier(GlassSurface()) }
}
