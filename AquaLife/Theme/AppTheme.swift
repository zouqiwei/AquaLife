import SwiftUI

// MARK: - Theme Mode
enum AppThemeMode: String, CodingKey {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - AppTheme
enum AppTheme {
    // Primary — 水蓝渐变主色
    static let primary = Color(hex: "#2EC4F0")
    static let primaryDark = Color(hex: "#0A8FBF")
    static let secondary = Color(hex: "#34E4C8")

    // Backgrounds
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "#0A1628"), Color(hex: "#0D2137"), Color(hex: "#0A1628")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBackground = Color(hex: "#132236").opacity(0.9)
    static let cardBorder = Color(hex: "#2EC4F0").opacity(0.15)

    // Health card colors
    static let stepsColor = Color(hex: "#FF9F43")
    static let sleepColor = Color(hex: "#A29BFE")
    static let heartColor = Color(hex: "#FF6B6B")
    static let waterColor = Color(hex: "#2EC4F0")

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)

    // Gradients
    static let waterGradient = LinearGradient(
        colors: [Color(hex: "#2EC4F0"), Color(hex: "#0A8FBF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ringTrackColor = Color.white.opacity(0.1)
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - GlassCard ViewModifier
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCard())
    }
}
