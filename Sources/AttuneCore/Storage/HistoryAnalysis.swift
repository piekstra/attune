import Foundation

/// Derived, testable statistics over the check-in history. These feed both
/// the recommendation engine (hyperfocus guard inputs) and the Insights
/// window (personal focus-by-hour patterns).
public enum HistoryAnalysis {

    /// Catalog ID prefixes that count as an actual break from work
    /// (history stores recommendation IDs, so matching happens on those).
    private static let breakIDPrefixes: [String] = [
        "body-care.", "micro.", "movement.", "restore.", "context-switch.",
    ]

    /// Minutes since the user last *accepted* a break-type recommendation.
    /// `nil` if no such acceptance is on record.
    public static func minutesSinceLastBreak(
        history: [CheckIn],
        now: Date = Date()
    ) -> Int? {
        let lastBreak = history.last { entry in
            guard entry.action == .accepted,
                  let recID = entry.recommendationID else { return false }
            return breakIDPrefixes.contains { recID.hasPrefix($0) }
        }
        guard let date = lastBreak?.date else { return nil }
        return max(0, Int(now.timeIntervalSince(date) / 60))
    }

    /// Consecutive most-recent completed check-ins reporting focus >= engaged.
    /// Skipped/missed entries end the streak count conservatively (we don't
    /// know what happened, so we don't assume hyperfocus continued).
    public static func consecutiveHighFocus(history: [CheckIn]) -> Int {
        var streak = 0
        for entry in history.reversed() {
            guard entry.outcome == .completed else { break }
            guard let focus = entry.focus, focus >= .engaged else { break }
            streak += 1
        }
        return streak
    }

    /// Average reported focus per local hour of day, for completed check-ins
    /// in the window. Returns hour -> (average 1...5, sample count).
    public static func averageFocusByHour(
        history: [CheckIn],
        calendar: Calendar = .current
    ) -> [Int: (average: Double, count: Int)] {
        var sums: [Int: (total: Int, count: Int)] = [:]
        for entry in history where entry.outcome == .completed {
            guard let focus = entry.focus else { continue }
            let hour = calendar.component(.hour, from: entry.date)
            let existing = sums[hour] ?? (0, 0)
            sums[hour] = (existing.total + focus.rawValue, existing.count + 1)
        }
        return sums.mapValues { (Double($0.total) / Double($0.count), $0.count) }
    }

    /// The contiguous 2-hour window with the best average focus, if there is
    /// enough data to say (>= 4 samples across the window). Powers the
    /// "your sharpest window" insight — chronotype varies a lot in ADHD, so
    /// this is learned from the user's own data rather than assumed.
    public static func peakFocusWindow(
        history: [CheckIn],
        calendar: Calendar = .current
    ) -> (startHour: Int, average: Double)? {
        let byHour = averageFocusByHour(history: history, calendar: calendar)
        var best: (startHour: Int, average: Double)?
        for start in 0...22 {
            guard let a = byHour[start], let b = byHour[start + 1] else { continue }
            let count = a.count + b.count
            guard count >= 4 else { continue }
            let weighted = (a.average * Double(a.count) + b.average * Double(b.count))
                / Double(count)
            if weighted > (best?.average ?? 0) {
                best = (start, weighted)
            }
        }
        return best
    }

    /// Counts used by the Insights window's "wins" section: moments of
    /// noticing (completed check-ins) and times the user acted on guidance.
    public static func wins(history: [CheckIn]) -> (checkIns: Int, actedOn: Int) {
        let completed = history.filter { $0.outcome == .completed }.count
        let acted = history.filter { $0.action == .accepted }.count
        return (completed, acted)
    }
}
