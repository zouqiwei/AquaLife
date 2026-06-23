import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
        colors: [
            dynamicColor(light: "#F4FBFF", dark: "#0A1628"),
            dynamicColor(light: "#EAF7FF", dark: "#0D2137"),
            dynamicColor(light: "#F7FFFC", dark: "#0A1628")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBackground = dynamicColor(
        light: "#FFFFFF",
        dark: "#132236",
        lightAlpha: 0.92,
        darkAlpha: 0.9
    )
    static let cardBorder = dynamicColor(
        light: "#2EC4F0",
        dark: "#2EC4F0",
        lightAlpha: 0.24,
        darkAlpha: 0.15
    )

    // Health card colors
    static let stepsColor = Color(hex: "#FF9F43")
    static let sleepColor = Color(hex: "#A29BFE")
    static let heartColor = Color(hex: "#FF6B6B")
    static let waterColor = Color(hex: "#2EC4F0")

    // Text
    static let textPrimary = dynamicColor(light: "#102033", dark: "#FFFFFF")
    static let textSecondary = dynamicColor(
        light: "#60758C",
        dark: "#FFFFFF",
        lightAlpha: 1,
        darkAlpha: 0.6
    )

    // Gradients
    static let waterGradient = LinearGradient(
        colors: [Color(hex: "#2EC4F0"), Color(hex: "#0A8FBF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ringTrackColor = dynamicColor(
        light: "#DDECF5",
        dark: "#FFFFFF",
        lightAlpha: 0.95,
        darkAlpha: 0.1
    )

    private static func dynamicColor(
        light: String,
        dark: String,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> Color {
        #if canImport(UIKit)
        Color(UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: dark, alpha: darkAlpha)
            }
            return UIColor(hex: light, alpha: lightAlpha)
        })
        #else
        Color(hex: light).opacity(Double(lightAlpha))
        #endif
    }
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

#if canImport(UIKit)
private extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >> 8) & 0xFF) / 255
        let b = CGFloat(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
#endif

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
