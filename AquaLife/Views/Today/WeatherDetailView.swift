//
//  WeatherDetailView.swift
//  AquaLife
//
//  Created by zouqiwei on 2026/06/29.
//

import SwiftUI
import UIKit
struct WeatherDetailView: View {
    let snapshot: WeatherHydrationSnapshot?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerCard
                    if let snap = snapshot {
                        metricsGrid(snap: snap)
                        hourlyForecastCard(snap: snap)
                        dailyForecastCard(snap: snap)
                        hydrationImpactCard(snap: snap)
                        uvAdviceCard(snap: snap)
                    } else {
                        unavailableCard
                    }
                    attributionNote
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("当前天气")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.black)
                        .font(.system(size: 17, weight: .medium))
                }
            }
        }
        .background(WeatherDetailNavigationBarShadowHider())
    }

    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: 0) {
            if let snap = snapshot {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("当前天气")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                        Text(snap.conditionText)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        Text(snap.bandLabel + " · 对饮水有影响")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: snap.conditionSymbol)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 52))
                        Text("\(snap.roundedTemperatureCelsius)°C")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
                .padding(20)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "cloud.slash")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.textSecondary)
                    Text("天气数据暂不可用")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
    }

    // MARK: - Metrics Grid
    private func metricsGrid(snap: WeatherHydrationSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            WeatherDetailMetricCard(
                symbol: "thermometer.medium",
                label: "体感温度",
                value: snap.roundedFeelsLike.map { "\($0)°C" } ?? "--",
                description: "人体实际感受到的温度",
                color: AppTheme.stepsColor
            )
            WeatherDetailMetricCard(
                symbol: "humidity.fill",
                label: "相对湿度",
                value: snap.humidityPercent.map { "\($0)%" } ?? "--",
                description: humidityDescription(snap.humidityPercent),
                color: Color(hex: "#74B9FF")
            )
            WeatherDetailMetricCard(
                symbol: "sun.max.fill",
                label: "UV 紫外线",
                value: snap.uvLabel,
                description: uvDescription(snap.uvIndex),
                color: Color(hex: "#FDCB6E")
            )
            WeatherDetailMetricCard(
                symbol: "drop.circle.fill",
                label: "补水建议",
                value: snap.bandLabel,
                description: bandDescription(snap.band),
                color: AppTheme.primary
            )
        }
    }

    // MARK: - Hydration Impact Card
    private func hydrationImpactCard(snap: WeatherHydrationSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "drop.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.primary)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.primary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text("天气对今日饮水的影响")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
            }

            VStack(spacing: 10) {
                ForEach(hydrationTips(snap: snap), id: \.0) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(AppTheme.primary)
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)
                        Text(tip.1)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - UV Advice
    @ViewBuilder
    private func uvAdviceCard(snap: WeatherHydrationSnapshot) -> some View {
        if let uv = snap.uvIndex, uv >= 3 {
            let (color, advice): (Color, String) = {
                switch uv {
                case 3...5: return (Color(hex: "#FDCB6E"), "中等紫外线，建议外出时涂抹 SPF 30 防晒，适当补充水分。")
                case 6...7: return (AppTheme.stepsColor, "较强紫外线，建议避开正午出行，外出务必防晒，多补水。")
                default:    return (AppTheme.heartColor, "极强紫外线，建议减少户外活动，充足补水，做好全身防护。")
                }
            }()

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sun.max.trianglebadge.exclamationmark")
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text("紫外线提示")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(advice)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }

    // MARK: - Unavailable
    private var unavailableCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "location.slash")
                .font(.system(size: 32))
                .foregroundColor(AppTheme.textSecondary)
            Text("无法获取天气数据")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
            Text("请确保已授予位置权限，并连接网络。")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .glassCard()
    }

    // MARK: - Attribution
    private var attributionNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "apple.logo")
                .font(.system(size: 11))
            Text("天气数据由 Apple WeatherKit 提供")
                .font(.system(size: 11))
        }
        .foregroundColor(AppTheme.textSecondary.opacity(0.55))
    }

    // MARK: - Helpers
    private func humidityDescription(_ percent: Int?) -> String {
        guard let p = percent else { return "" }
        switch p {
        case 0...30: return "较干燥，注意保湿补水"
        case 31...60: return "湿度适宜，较为舒适"
        case 61...75: return "偏湿，感觉较闷热"
        default:     return "高湿，出汗散热困难"
        }
    }

    private func uvDescription(_ uv: Int?) -> String {
        guard let u = uv else { return "" }
        switch u {
        case 0...2: return "弱，无需特别防护"
        case 3...5: return "中，外出建议防晒"
        case 6...7: return "强，减少正午外出"
        case 8...10: return "很强，做好全面防护"
        default:    return "极强，避免户外活动"
        }
    }

    private func bandDescription(_ band: WeatherHydrationBand) -> String {
        switch band {
        case .cool: return "天气偏凉，正常补水即可"
        case .mild: return "气温舒适，维持日常饮水"
        case .warm: return "天气偏热，适当多补 200ml"
        case .hot:  return "天气炎热，建议多补 400ml"
        }
    }

    private func hydrationTips(snap: WeatherHydrationSnapshot) -> [(String, String)] {
        var tips: [(String, String)] = []
        switch snap.band {
        case .cool:
            tips.append(("temp", "当前气温偏低（\(snap.roundedTemperatureCelsius)°C），排汗较少，正常补水即可。"))
        case .mild:
            tips.append(("temp", "气温舒适（\(snap.roundedTemperatureCelsius)°C），维持每日 2000ml 基础目标。"))
        case .warm:
            tips.append(("temp", "气温偏高（\(snap.roundedTemperatureCelsius)°C），排汗量增加，建议额外补充 200ml。"))
        case .hot:
            tips.append(("temp", "高温天气（\(snap.roundedTemperatureCelsius)°C），大量排汗，建议在日常基础上多喝 400ml。"))
        }
        if let fl = snap.roundedFeelsLike, fl > snap.roundedTemperatureCelsius + 3 {
            tips.append(("feels", "体感温度（\(fl)°C）高于实际气温，体感更热，需适当提前补水。"))
        }
        if let h = snap.humidityPercent {
            if h > 70 {
                tips.append(("humidity", "湿度较高（\(h)%），汗液蒸发变慢，体感更闷热，建议少量多次饮水。"))
            } else if h < 30 {
                tips.append(("humidity", "湿度偏低（\(h)%），空气干燥，呼吸道和皮肤失水更多，需额外补水。"))
            }
        }
        if let uv = snap.uvIndex, uv >= 6 {
            tips.append(("uv", "紫外线较强（UV \(uv)），长时间户外活动后，注意补充因出汗失去的水分。"))
        }
        return tips
    }

    // MARK: - Hourly Forecast Card
    @ViewBuilder
    private func hourlyForecastCard(snap: WeatherHydrationSnapshot) -> some View {
        if let hourly = snap.hourlyForecast, !hourly.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.primary)
                    Text("未来 24 小时")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(hourly.indices, id: \.self) { i in
                            HourlyWeatherCell(info: hourly[i], isFirst: i == 0)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }

    // MARK: - Daily Forecast Card
    @ViewBuilder
    private func dailyForecastCard(snap: WeatherHydrationSnapshot) -> some View {
        if let daily = snap.dailyForecast, !daily.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.primary)
                    Text("未来 7 天")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }
                VStack(spacing: 0) {
                    ForEach(daily.indices, id: \.self) { i in
                        DailyWeatherRow(info: daily[i], isFirst: i == 0)
                        if i < daily.count - 1 {
                            Divider()
                                .background(AppTheme.cardBorder)
                                .padding(.leading, 44)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }

}

private struct WeatherDetailNavigationBarShadowHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WeatherDetailNavigationBarShadowHiderController {
        WeatherDetailNavigationBarShadowHiderController()
    }

    func updateUIViewController(_ uiViewController: WeatherDetailNavigationBarShadowHiderController, context: Context) {}
}

private final class WeatherDetailNavigationBarShadowHiderController: UIViewController {
    private var previousStandardAppearance: UINavigationBarAppearance?
    private var previousScrollEdgeAppearance: UINavigationBarAppearance?
    private var previousCompactAppearance: UINavigationBarAppearance?
    private var previousCompactScrollEdgeAppearance: UINavigationBarAppearance?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyAppearance()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreAppearance()
    }

    private func applyAppearance() {
        guard let navigationBar = navigationController?.navigationBar else { return }

        previousStandardAppearance = navigationBar.standardAppearance
        previousScrollEdgeAppearance = navigationBar.scrollEdgeAppearance
        previousCompactAppearance = navigationBar.compactAppearance
        previousCompactScrollEdgeAppearance = navigationBar.compactScrollEdgeAppearance

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        let isDark = traitCollection.userInterfaceStyle == .dark
        appearance.backgroundColor = isDark ? UIColor(hex: "#0A1628") : UIColor(hex: "#F4FBFF")
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()

        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.compactScrollEdgeAppearance = appearance
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyAppearance()
    }

    private func restoreAppearance() {
        guard let navigationBar = navigationController?.navigationBar else { return }

        if let previousStandardAppearance {
            navigationBar.standardAppearance = previousStandardAppearance
        }
        navigationBar.scrollEdgeAppearance = previousScrollEdgeAppearance
        navigationBar.compactAppearance = previousCompactAppearance
        navigationBar.compactScrollEdgeAppearance = previousCompactScrollEdgeAppearance
    }
}

// MARK: - WeatherDetailMetricCard
struct WeatherDetailMetricCard: View {
    let symbol: String
    let label: String
    let value: String
    let description: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Spacer()
            }
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                if !description.isEmpty {
                    Text(description)
                        .font(.system(size: 10))
                        .foregroundColor(color.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
// MARK: - HourlyWeatherCell
struct HourlyWeatherCell: View {
    let info: HourlyWeatherInfo
    let isFirst: Bool

    private var timeLabel: String {
        if isFirst { return "现在" }
        let f = DateFormatter()
        f.dateFormat = "HH时"
        return f.string(from: info.time)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(timeLabel)
                .font(.system(size: 11))
                .foregroundColor(isFirst ? AppTheme.primary : AppTheme.textSecondary)
                .fontWeight(isFirst ? .semibold : .regular)
            Image(systemName: info.conditionSymbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 22))
                .frame(height: 26)
            Text("\(info.roundedTemperature)°")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
    }
}

// MARK: - DailyWeatherRow
struct DailyWeatherRow: View {
    let info: DailyWeatherInfo
    let isFirst: Bool

    private var dayLabel: String {
        if isFirst { return "今天" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EEE"
        return f.string(from: info.time)
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(dayLabel)
                .font(.system(size: 13, weight: isFirst ? .semibold : .regular))
                .foregroundColor(isFirst ? AppTheme.textPrimary : AppTheme.textSecondary)
                .frame(width: 40, alignment: .leading)

            Image(systemName: info.conditionSymbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 18))
                .frame(width: 28)

            Spacer()

            HStack(spacing: 4) {
                Text("\(info.roundedLow)°")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 30, alignment: .trailing)

                Capsule()
                    .fill(LinearGradient(
                        colors: [AppTheme.primary.opacity(0.5), AppTheme.stepsColor.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: 60, height: 4)

                Text("\(info.roundedHigh)°")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 30, alignment: .leading)
            }
        }
        .padding(.vertical, 10)
    }
}
