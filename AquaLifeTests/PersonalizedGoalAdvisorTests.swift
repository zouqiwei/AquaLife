import CoreLocation
import XCTest
@testable import AquaLife

final class PersonalizedGoalAdvisorTests: XCTestCase {
    func testRecommendationUsesBaselineWhenNoFactorDataExists() {
        let result = PersonalizedGoalAdvisor.recommendation(
            input: PersonalizedGoalInput(
                baselineGoal: 2000,
                stepCount: nil,
                sleepMinutes: nil,
                weatherBand: nil,
                previousRecommendedGoal: nil,
                now: fixedDate
            )
        )

        XCTAssertEqual(result.goal, 2000)
        XCTAssertEqual(result.factors, [])
        XCTAssertFalse(result.shouldHighlightUpdate)
        XCTAssertTrue(result.explanation.contains("有限"))
    }

    func testRecommendationAddsStepSleepAndWeatherAdjustments() {
        let result = PersonalizedGoalAdvisor.recommendation(
            input: PersonalizedGoalInput(
                baselineGoal: 2000,
                stepCount: 12500,
                sleepMinutes: 320,
                weatherBand: .hot,
                previousRecommendedGoal: nil,
                now: fixedDate
            )
        )

        XCTAssertEqual(result.goal, 2700)
        XCTAssertEqual(result.factors.map(\.kind), [.activity, .recovery, .weather])
        XCTAssertTrue(result.explanation.contains("较热"))
    }

    func testRecommendationClampsThroughGoalSettings() {
        let result = PersonalizedGoalAdvisor.recommendation(
            input: PersonalizedGoalInput(
                baselineGoal: 3800,
                stepCount: 18000,
                sleepMinutes: 250,
                weatherBand: .hot,
                previousRecommendedGoal: nil,
                now: fixedDate
            )
        )

        XCTAssertEqual(result.goal, 4000)
    }

    func testRecommendationHighlightsMeaningfulRefreshOnly() {
        let result = PersonalizedGoalAdvisor.recommendation(
            input: PersonalizedGoalInput(
                baselineGoal: 2000,
                stepCount: 8100,
                sleepMinutes: 430,
                weatherBand: .mild,
                previousRecommendedGoal: 2100,
                now: fixedDate
            )
        )

        XCTAssertEqual(result.goal, 2200)
        XCTAssertTrue(result.shouldHighlightUpdate)
    }

    func testRecommendationKeepsLowerActivityBandStableUntilEightThousandSteps() {
        let result = PersonalizedGoalAdvisor.recommendation(
            input: PersonalizedGoalInput(
                baselineGoal: 2000,
                stepCount: 7900,
                sleepMinutes: nil,
                weatherBand: nil,
                previousRecommendedGoal: nil,
                now: fixedDate
            )
        )

        XCTAssertEqual(result.goal, 2000)
        XCTAssertEqual(result.factors, [])
    }

    func testRecommendationDoesNotHighlightSameGoalAgain() {
        let result = PersonalizedGoalAdvisor.recommendation(
            input: PersonalizedGoalInput(
                baselineGoal: 2000,
                stepCount: 7900,
                sleepMinutes: 430,
                weatherBand: .mild,
                previousRecommendedGoal: 2100,
                now: fixedDate
            )
        )

        XCTAssertEqual(result.goal, 2100)
        XCTAssertFalse(result.shouldHighlightUpdate)
    }

    func testWeatherProviderMapsTemperatureIntoBands() {
        XCTAssertEqual(WeatherHydrationProvider.band(forTemperatureCelsius: 8), .cool)
        XCTAssertEqual(WeatherHydrationProvider.band(forTemperatureCelsius: 20), .mild)
        XCTAssertEqual(WeatherHydrationProvider.band(forTemperatureCelsius: 28), .warm)
        XCTAssertEqual(WeatherHydrationProvider.band(forTemperatureCelsius: 33), .hot)
    }

    func testWeatherLocationAuthorizationActionDependsOnAuthorizationStatus() {
        XCTAssertEqual(
            WeatherLocationAuthorizationAction.make(for: .authorizedAlways),
            .requestLocation
        )
        XCTAssertEqual(
            WeatherLocationAuthorizationAction.make(for: .authorizedWhenInUse),
            .requestLocation
        )
        XCTAssertEqual(
            WeatherLocationAuthorizationAction.make(for: .notDetermined),
            .requestAuthorization
        )
        XCTAssertEqual(
            WeatherLocationAuthorizationAction.make(for: .denied),
            .unavailable
        )
        XCTAssertEqual(
            WeatherLocationAuthorizationAction.make(for: .restricted),
            .unavailable
        )
    }

    func testWeatherProviderReturnsNilWhenNoWeatherSourceIsAvailable() async {
        let provider = WeatherHydrationProvider(
            locationResolver: { CLLocation(latitude: 31.2304, longitude: 121.4737) },
            weatherLoader: { _ in nil }
        )
        let band = await provider.fetchCurrentBand()

        XCTAssertNil(band)
    }

    func testWeatherProviderMapsFetchedTemperatureIntoHydrationBand() async {
        let snapshot = WeatherHydrationSnapshot(
            temperatureCelsius: 30,
            band: .warm,
            feelsLikeCelsius: nil,
            humidity: nil,
            uvIndex: nil,
            conditionSymbol: "sun.max",
            conditionText: "晴",
            hourlyForecast: nil,
            dailyForecast: nil,
            locationName: nil
        )
        let provider = WeatherHydrationProvider(
            locationResolver: { CLLocation(latitude: 31.2304, longitude: 121.4737) },
            weatherLoader: { _ in snapshot }
        )

        let band = await provider.fetchCurrentBand()

        XCTAssertEqual(band, .warm)
    }

    func testWeatherProviderReturnsNilWhenLocationUnavailable() async {
        let provider = WeatherHydrationProvider(
            locationResolver: { nil },
            weatherLoader: { _ in
                XCTFail("weather loader should not run without a location")
                return nil
            }
        )

        let band = await provider.fetchCurrentBand()

        XCTAssertNil(band)
    }

    func testWeatherSnapshotFormatsReadableStatusLine() {
        let snapshot = WeatherHydrationSnapshot(
            temperatureCelsius: 30,
            band: .warm,
            feelsLikeCelsius: nil,
            humidity: nil,
            uvIndex: nil,
            conditionSymbol: "sun.max",
            conditionText: "晴",
            hourlyForecast: nil,
            dailyForecast: nil,
            locationName: nil
        )

        XCTAssertEqual(snapshot.statusLine, "当前天气：偏热 · 30°C")
        XCTAssertEqual(snapshot.profileSummary, "当前天气：偏热 · 30°C，已计入今日建议")
    }

    private var fixedDate: Date {
        DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 6, day: 24, hour: 9).date!
    }
}
