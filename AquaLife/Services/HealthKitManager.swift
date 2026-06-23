import HealthKit
import Foundation

enum HealthKitStatus: Equatable {
    case unknown
    case available
    case notAvailable
    case needsAuthorization
    case readFailed

    var title: String {
        switch self {
        case .unknown: return "等待连接"
        case .available: return "已连接"
        case .notAvailable: return "当前设备不可用"
        case .needsAuthorization: return "需要授权"
        case .readFailed: return "读取失败"
        }
    }

    var message: String {
        switch self {
        case .unknown:
            return "正在检查健康数据权限"
        case .available:
            return "健康数据可正常读取"
        case .notAvailable:
            return "当前设备不支持 HealthKit，模拟器可能无法读取健康数据"
        case .needsAuthorization:
            return "请允许 AquaLife 读取健康数据"
        case .readFailed:
            return "健康数据读取失败，可稍后重试"
        }
    }

    var needsUserAttention: Bool {
        self == .notAvailable || self == .needsAuthorization || self == .readFailed
    }
}

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    @Published private(set) var status: HealthKitStatus = .unknown

    // MARK: - Types
    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let heart = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(heart) }
        if let water = HKObjectType.quantityType(forIdentifier: .dietaryWater) { types.insert(water) }
        return types
    }()

    private let writeTypes: Set<HKSampleType> = {
        var types = Set<HKSampleType>()
        if let water = HKObjectType.quantityType(forIdentifier: .dietaryWater) { types.insert(water) }
        return types
    }()

    // MARK: - Authorization
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            status = .notAvailable
            return false
        }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            status = .available
            return true
        } catch {
            status = .needsAuthorization
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }

    private func markReadFailed() {
        status = .readFailed
    }

    // MARK: - Water
    /// 写入饮水记录到 HealthKit
    func saveWater(amount ml: Double, date: Date = .now) async throws {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date)
        try await store.save(sample)
    }

    /// 读取今日总饮水量（ml）
    func fetchTodayWater() async -> Double {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return 0 }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: waterType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if error != nil {
                    Task { @MainActor in self.markReadFailed() }
                    continuation.resume(returning: 0)
                    return
                }
                let total = result?.sumQuantity()?.doubleValue(for: .literUnit(with: .milli)) ?? 0
                continuation.resume(returning: total)
            }
            store.execute(query)
        }
    }

    // MARK: - Steps
    /// 读取今日步数
    func fetchTodaySteps() async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: .now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if error != nil {
                    Task { @MainActor in self.markReadFailed() }
                    continuation.resume(returning: 0)
                    return
                }
                let steps = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                continuation.resume(returning: steps)
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep
    /// 读取昨晚睡眠时长（分钟）
    func fetchLastNightSleep() async -> Int {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: .now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if error != nil {
                    Task { @MainActor in self.markReadFailed() }
                    continuation.resume(returning: 0)
                    return
                }
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                let asleepSamples = samples.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                }
                let totalSeconds = asleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: Int(totalSeconds / 60))
            }
            store.execute(query)
        }
    }

    // MARK: - Heart Rate
    /// 读取最新心率
    func fetchLatestHeartRate() async -> Double? {
        guard let heartType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if error != nil {
                    Task { @MainActor in self.markReadFailed() }
                    continuation.resume(returning: nil)
                    return
                }
                let bpm = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: bpm)
            }
            store.execute(query)
        }
    }

    // MARK: - Weekly Water Data
    /// 读取最近 7 天每日饮水量（ml）
    func fetchWeeklyWater() async -> [(date: Date, amount: Double)] {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return [] }
        let calendar = Calendar.current
        let now = Date()
        var results: [(date: Date, amount: Double)] = []

        for dayOffset in (0..<7).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: now)),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { continue }

            let predicate = HKQuery.predicateForSamples(withStart: day, end: nextDay, options: .strictStartDate)
            let amount: Double = await withCheckedContinuation { continuation in
                let query = HKStatisticsQuery(quantityType: waterType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                    if error != nil {
                        Task { @MainActor in self.markReadFailed() }
                        continuation.resume(returning: 0)
                        return
                    }
                    let val = result?.sumQuantity()?.doubleValue(for: .literUnit(with: .milli)) ?? 0
                    continuation.resume(returning: val)
                }
                self.store.execute(query)
            }
            results.append((date: day, amount: amount))
        }
        return results
    }
}
