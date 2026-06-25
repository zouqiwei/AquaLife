import Foundation

enum DateHelper {
    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    static func startOfDay(_ date: Date = .now) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    static func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        fmt.locale = Locale(identifier: "zh_CN")
        return fmt.string(from: date)
    }

    static func storageDayKey(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    static func lastDays(_ count: Int, endingAt date: Date = .now) -> [Date] {
        guard count > 0 else { return [] }
        let end = startOfDay(date)
        return (0..<count).reversed().compactMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: end)
        }
    }

    static func last7Days() -> [Date] {
        lastDays(7)
    }

    static func minutesToHoursString(_ minutes: Int) -> String {
        guard minutes > 0 else { return "暂无" }
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m) 分钟" }
        if m == 0 { return "\(h) 小时" }
        return "\(h)h \(m)m"
    }
}
