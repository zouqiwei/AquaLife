//
//  WeatherHydrationProvider.swift
//  AquaLife
//
//  Created by zouqiwei on 2026/06/25.
//

import CoreLocation
import Foundation
import WeatherKit

struct WeatherHydrationSnapshot: Equatable {
    let temperatureCelsius: Double
    let band: WeatherHydrationBand
    /// 体感温度（°C）
    let feelsLikeCelsius: Double?
    /// 相对湿度（0.0 ~ 1.0）
    let humidity: Double?
    /// UV 指数（0 ~ 11+）
    let uvIndex: Int?
    /// SF Symbol 名称，对应当前天气状况
    let conditionSymbol: String
    /// 天气状况中文描述
    let conditionText: String

    var roundedTemperatureCelsius: Int {
        Int(temperatureCelsius.rounded())
    }

    var roundedFeelsLike: Int? {
        feelsLikeCelsius.map { Int($0.rounded()) }
    }

    var humidityPercent: Int? {
        humidity.map { Int(($0 * 100).rounded()) }
    }

    var uvLabel: String {
        guard let uv = uvIndex else { return "--" }
        switch uv {
        case 0...2:  return "低 (\(uv))"
        case 3...5:  return "中 (\(uv))"
        case 6...7:  return "高 (\(uv))"
        case 8...10: return "很高 (\(uv))"
        default:     return "极高 (\(uv))"
        }
    }

    var bandLabel: String {
        switch band {
        case .cool: return "偏凉"
        case .mild: return "舒适"
        case .warm: return "偏热"
        case .hot:  return "炎热"
        }
    }

    var statusLine: String {
        "当前天气：\(bandLabel) · \(roundedTemperatureCelsius)°C"
    }

    var profileSummary: String {
        "\(statusLine)，已计入今日建议"
    }
}

struct WeatherHydrationProvider {
    typealias LocationResolver = @Sendable () async -> CLLocation?
    typealias WeatherLoader = @Sendable (CLLocation) async -> WeatherHydrationSnapshot?

    private let locationResolver: LocationResolver
    private let weatherLoader: WeatherLoader

    init(
        locationResolver: @escaping LocationResolver = {
            await WeatherLocationClient.shared.currentLocation()
        },
        weatherLoader: @escaping WeatherLoader = { location in
            await WeatherKitClient.shared.fetchSnapshot(at: location)
        }
    ) {
        self.locationResolver = locationResolver
        self.weatherLoader = weatherLoader
    }

    func fetchCurrentWeather() async -> WeatherHydrationSnapshot? {
        guard let location = await locationResolver(),
              let snapshot = await weatherLoader(location) else {
            return nil
        }
        return snapshot
    }

    func fetchCurrentBand() async -> WeatherHydrationBand? {
        await fetchCurrentWeather()?.band
    }

    static func band(forTemperatureCelsius temperature: Double) -> WeatherHydrationBand {
        switch temperature {
        case ..<12:
            return .cool
        case ..<26:
            return .mild
        case ..<32:
            return .warm
        default:
            return .hot
        }
    }
}

@MainActor
private final class WeatherLocationClient: NSObject, @preconcurrency CLLocationManagerDelegate {
    static let shared = WeatherLocationClient()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func currentLocation() async -> CLLocation? {
        guard CLLocationManager.locationServicesEnabled() else { return nil }

        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            return nil
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                self.manager.requestLocation()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            resume(with: nil)
        case .notDetermined:
            break
        @unknown default:
            resume(with: nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        resume(with: locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resume(with: nil)
    }

    private func resume(with location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }
}

private actor WeatherKitClient {
    static let shared = WeatherKitClient()

    private let service = WeatherService()

    func fetchSnapshot(at location: CLLocation) async -> WeatherHydrationSnapshot? {
        do {
            let weather = try await service.weather(for: location)
            let current = weather.currentWeather
            let temp = current.temperature.value
            let feelsLike = current.apparentTemperature.value
            let humidity = current.humidity
            let uv = current.uvIndex.value
            let symbol = current.symbolName
            let condition = current.condition
            let conditionText = Self.chineseCondition(condition)
            return WeatherHydrationSnapshot(
                temperatureCelsius: temp,
                band: WeatherHydrationProvider.band(forTemperatureCelsius: temp),
                feelsLikeCelsius: feelsLike,
                humidity: humidity,
                uvIndex: uv,
                conditionSymbol: symbol,
                conditionText: conditionText
            )
        } catch {
            print("WeatherKit Error: \(error)")
            return nil
        }
    }

    private static func chineseCondition(_ condition: WeatherCondition) -> String {
        switch condition {
        case .blizzard:            return "暴风雪"
        case .blowingDust:         return "扬尘"
        case .blowingSnow:         return "风吹雪"
        case .breezy:              return "微风"
        case .clear:               return "晴"
        case .cloudy:              return "阴"
        case .drizzle:             return "小雨"
        case .flurries:            return "小雪"
        case .foggy:               return "雾"
        case .freezingDrizzle:     return "冻雨"
        case .freezingRain:        return "冻雨"
        case .frigid:              return "严寒"
        case .hail:                return "冰雹"
        case .haze:                return "霾"
        case .heavyRain:           return "大雨"
        case .heavySnow:           return "大雪"
        case .hot:                 return "高温"
        case .hurricane:           return "飓风"
        case .isolatedThunderstorms: return "局部雷阵雨"
        case .mostlyClear:         return "大部晴朗"
        case .mostlyCloudy:        return "多云"
        case .partlyCloudy:        return "局部多云"
        case .rain:                return "雨"
        case .scatteredThunderstorms: return "分散雷阵雨"
        case .sleet:               return "雨夹雪"
        case .smoky:               return "烟雾"
        case .snow:                return "雪"
        case .strongStorms:        return "强风暴"
        case .sunFlurries:         return "晴间小雪"
        case .sunShowers:          return "晴间阵雨"
        case .thunderstorms:       return "雷阵雨"
        case .tropicalStorm:       return "热带风暴"
        case .windy:               return "大风"
        case .wintryMix:           return "雨雪混合"
        @unknown default:          return "未知"
        }
    }
}
