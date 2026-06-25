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

    var roundedTemperatureCelsius: Int {
        Int(temperatureCelsius.rounded())
    }

    var bandLabel: String {
        switch band {
        case .cool:
            return "偏凉"
        case .mild:
            return "舒适"
        case .warm:
            return "偏热"
        case .hot:
            return "炎热"
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
    typealias WeatherLoader = @Sendable (CLLocation) async -> Double?

    private let locationResolver: LocationResolver
    private let weatherLoader: WeatherLoader

    init(
        locationResolver: @escaping LocationResolver = {
            await WeatherLocationClient.shared.currentLocation()
        },
        weatherLoader: @escaping WeatherLoader = { location in
            await WeatherKitClient.shared.temperatureCelsius(at: location)
        }
    ) {
        self.locationResolver = locationResolver
        self.weatherLoader = weatherLoader
    }

    func fetchCurrentWeather() async -> WeatherHydrationSnapshot? {
        guard let location = await locationResolver(),
              let temperature = await weatherLoader(location) else {
            return nil
        }

        return WeatherHydrationSnapshot(
            temperatureCelsius: temperature,
            band: Self.band(forTemperatureCelsius: temperature)
        )
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

    func temperatureCelsius(at location: CLLocation) async -> Double? {
        do {
            let weather = try await service.weather(for: location)
            return weather.currentWeather.temperature.value
        } catch {
            return nil
        }
    }
}
