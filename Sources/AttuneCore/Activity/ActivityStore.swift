import Foundation

/// One day of at-computer activity, minutes credited per local hour.
///
/// Deliberately coarse: Attune records *that* you were at the keyboard,
/// never what you did there. No app names, no window titles, no keystrokes —
/// presence only. That's all the mental-health use case needs: an objective
/// answer to "did I actually work today?", which ADHD time blindness and
/// performance anxiety reliably distort toward "no".
public struct DayActivity: Codable, Equatable, Sendable {
    /// Index 0–23 = local hour; value = active minutes credited in that hour.
    public var minutesByHour: [Int]

    /// Earliest and latest moments any activity was credited this day. The
    /// gap between them is the *full-day span* — how long the person was
    /// tethered to work end-to-end, unprompted breaks and appointments
    /// included. Distinct from active minutes, which count only time at the
    /// keyboard. Optional so activity files written before this existed
    /// still decode (synthesized Codable treats a missing optional as nil).
    public var firstActivity: Date?
    public var lastActivity: Date?

    public init(
        minutesByHour: [Int] = Array(repeating: 0, count: 24),
        firstActivity: Date? = nil,
        lastActivity: Date? = nil
    ) {
        self.minutesByHour = minutesByHour
        self.firstActivity = firstActivity
        self.lastActivity = lastActivity
    }

    public var totalMinutes: Int {
        minutesByHour.reduce(0, +)
    }

    /// First/last local hour (0–23) with any credited activity — the
    /// coarse fallback used to estimate a span for legacy days recorded
    /// before precise timestamps were kept.
    var firstActiveHour: Int? { minutesByHour.firstIndex { $0 > 0 } }
    var lastActiveHour: Int? { minutesByHour.lastIndex { $0 > 0 } }
}

/// Persistence and queries for daily activity. Keys are local dates
/// ("2026-07-03"); everything stays in the same local Application Support
/// folder as the rest of Attune's data.
public final class ActivityStore {
    private let fileURL: URL
    private let calendar: Calendar
    private var days: [String: DayActivity]
    /// Days of history to keep.
    private let retentionDays = 120

    public init(fileURL: URL, calendar: Calendar = .current) {
        self.fileURL = fileURL
        self.calendar = calendar
        self.days = Self.load(from: fileURL)
    }

    public convenience init(calendar: Calendar = .current) throws {
        let dir = try StoragePaths.appSupportDirectory()
        self.init(
            fileURL: dir.appendingPathComponent("activity.json"),
            calendar: calendar
        )
    }

    /// Credit active minutes to the day/hour containing `date`, and stretch
    /// the day's first/last-activity bracket to include this moment.
    /// Persists at most once per call — the file is tiny.
    public func credit(minutes: Int = 1, at date: Date = Date()) {
        let key = dayKey(for: date)
        let hour = calendar.component(.hour, from: date)
        var day = days[key] ?? DayActivity()
        day.minutesByHour[hour] += minutes
        if let first = day.firstActivity {
            day.firstActivity = min(first, date)
        } else {
            day.firstActivity = date
        }
        if let last = day.lastActivity {
            day.lastActivity = max(last, date)
        } else {
            day.lastActivity = date
        }
        days[key] = day
        prune(now: date)
        persist()
    }

    public func minutes(on date: Date) -> Int {
        days[dayKey(for: date)]?.totalMinutes ?? 0
    }

    public func minutesToday(now: Date = Date()) -> Int {
        minutes(on: now)
    }

    /// Total active minutes over the last `dayCount` days including today.
    public func minutesInLastDays(_ dayCount: Int, now: Date = Date()) -> Int {
        var total = 0
        for offset in 0..<dayCount {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            total += minutes(on: day)
        }
        return total
    }

    // MARK: - Full-day span

    /// First moment of activity on `date`, precise when available.
    public func firstActivity(on date: Date) -> Date? {
        days[dayKey(for: date)]?.firstActivity
    }

    /// Latest moment of activity on `date`, precise when available.
    public func lastActivity(on date: Date) -> Date? {
        days[dayKey(for: date)]?.lastActivity
    }

    /// The full-day span in minutes: from the first activity of the day to
    /// the last, including every unprompted break and time away in between.
    /// Prefers precise timestamps; falls back to an hour-granularity
    /// estimate for legacy days recorded before timestamps were kept.
    /// `nil` when the day has no activity at all.
    public func spanMinutes(on date: Date) -> Int? {
        guard let day = days[dayKey(for: date)] else { return nil }
        if let first = day.firstActivity, let last = day.lastActivity {
            return max(0, Int(last.timeIntervalSince(first) / 60))
        }
        // Legacy fallback: bracket the first and last active hours.
        if let firstHour = day.firstActiveHour, let lastHour = day.lastActiveHour {
            return (lastHour - firstHour) * 60
        }
        return nil
    }

    public func spanMinutesToday(now: Date = Date()) -> Int? {
        spanMinutes(on: now)
    }

    /// Minutes inside the day's bracket that were *not* at the keyboard —
    /// unprompted breaks, lunch, appointments. Span minus active, floored
    /// at zero. `nil` when there's no span yet.
    public func awayMinutes(on date: Date) -> Int? {
        guard let span = spanMinutes(on: date) else { return nil }
        return max(0, span - minutes(on: date))
    }

    public func awayMinutesToday(now: Date = Date()) -> Int? {
        awayMinutes(on: now)
    }

    /// Average full-day span over the last `dayCount` days, counting only
    /// days with real activity (so days off don't dilute it). `nil` until
    /// there's at least one such day.
    public func averageSpanMinutes(lastDays dayCount: Int, now: Date = Date()) -> Int? {
        var total = 0
        var count = 0
        for offset in 0..<dayCount {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now),
                  minutes(on: day) > 0,
                  let span = spanMinutes(on: day) else { continue }
            total += span
            count += 1
        }
        return count > 0 ? total / count : nil
    }

    private func dayKey(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func prune(now: Date) {
        guard days.count > retentionDays,
              let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: now)
        else { return }
        let cutoffKey = dayKey(for: cutoffDate)
        days = days.filter { $0.key >= cutoffKey }
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(days)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Attune: failed to save activity: \(error)")
        }
    }

    private static func load(from url: URL) -> [String: DayActivity] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: DayActivity].self, from: data)) ?? [:]
    }
}

/// "4h 05m" style formatting for activity durations.
public func formatMinutes(_ minutes: Int) -> String {
    let h = minutes / 60
    let m = minutes % 60
    if h == 0 { return "\(m)m" }
    return String(format: "%dh %02dm", h, m)
}

/// Short wall-clock label like "6:05 AM", used for the day's bracket.
public func formatClockTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
}
