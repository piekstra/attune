import Foundation

/// Pure scheduling rules, kept free of timers and system state so they can
/// be tested exhaustively. `CheckInScheduler` turns these into actual timers.
///
/// The shape of the policy:
///
/// - Baseline ~45 min. Sustained attention degrades measurably with time on
///   task (the "vigilance decrement"), and micro-break research shows
///   benefits from brief recovery well before the classic 90-minute
///   ultradian mark.
/// - High focus *stretches* the next interval (×1.6, capped at 90 min):
///   flow is precious and interruptions are expensive, so when things are
///   going well Attune backs off.
/// - Low focus *tightens* it (×0.6, floored at 25 min): a struggling brain
///   benefits from an earlier chance to change course — but never so often
///   that the tool itself becomes the distraction.
public enum SchedulePolicy {
    public static let minIntervalMinutes = 25
    public static let maxIntervalMinutes = 90

    /// Minutes between a meeting ending and the follow-up check-in.
    /// Interruption research finds task boundaries are the cheapest moment
    /// to interrupt; the end of a call is exactly such a boundary. The small
    /// grace period lets the user finish post-call notes first.
    public static let postMeetingGraceMinutes = 2

    /// How often to re-check whether a meeting has ended.
    public static let meetingPollSeconds: TimeInterval = 120

    /// Reported high focus this many check-ins in a row, without a real
    /// break, triggers the hyperfocus body-care nudge.
    public static let hyperfocusStreakThreshold = 2
    public static let hyperfocusMinutesWithoutBreak = 100

    /// Active at-keyboard minutes that count as "a full day's work is
    /// already in the bank" (7 hours). Past this, low-focus check-ins get
    /// the permission-to-stop framing instead of another push.
    public static let fullDayActiveMinutes = 420

    /// Full-day *span* — first activity to last, breaks and time away
    /// included — that counts as a long tether to work (10 hours). Past
    /// this, a fading-focus check-in gets the work/life-separation nudge,
    /// even if active minutes alone haven't hit `fullDayActiveMinutes`
    /// (a fragmented 6-hour day can still stretch across a 10-hour bracket).
    public static let longWorkDaySpanMinutes = 600

    /// Interval until the next check-in, given what the user just reported.
    /// `lastFocus == nil` means the previous check-in was skipped or missed;
    /// the baseline applies.
    public static func nextInterval(
        afterFocus lastFocus: FocusLevel?,
        settings: UserSettings
    ) -> TimeInterval {
        let base = Double(settings.baseIntervalMinutes)
        guard settings.adaptiveCadence, let focus = lastFocus else {
            return clamp(base) * 60
        }

        let scaled: Double
        switch focus {
        case .lockedIn, .engaged:
            scaled = base * 1.6
        case .coasting:
            scaled = base
        case .foggy, .scattered:
            scaled = base * 0.6
        }
        return clamp(scaled) * 60
    }

    private static func clamp(_ minutes: Double) -> Double {
        min(max(minutes, Double(minIntervalMinutes)), Double(maxIntervalMinutes))
    }

    /// Whether `date` falls inside the user's check-in window.
    public static func isWithinWorkHours(
        _ date: Date,
        settings: UserSettings,
        calendar: Calendar = .current
    ) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        guard settings.workDays.contains(weekday) else { return false }
        let hour = calendar.component(.hour, from: date)
        return hour >= settings.workStartHour && hour < settings.workEndHour
    }

    /// The next moment a check-in is allowed to fire at or after `date`.
    /// Inside work hours this is `date` itself; otherwise the start of the
    /// next working day.
    public static func nextAllowedDate(
        from date: Date,
        settings: UserSettings,
        calendar: Calendar = .current
    ) -> Date {
        if isWithinWorkHours(date, settings: settings, calendar: calendar) {
            return date
        }
        // Walk forward day by day (bounded — a week is always enough when
        // at least one work day is configured).
        var candidate = date
        for _ in 0..<8 {
            let weekday = calendar.component(.weekday, from: candidate)
            let hour = calendar.component(.hour, from: candidate)
            let sameDayStartIsAhead =
                calendar.isDate(candidate, inSameDayAs: date)
                    ? hour < settings.workStartHour
                    : true
            if settings.workDays.contains(weekday), sameDayStartIsAhead,
               let start = calendar.date(
                bySettingHour: settings.workStartHour,
                minute: 0, second: 0, of: candidate
               ), start >= date {
                return start
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else { break }
            candidate = calendar.startOfDay(for: next)
        }
        // No work days configured — fall back to "now" so the app still works.
        return date
    }

    /// True when the recent run of check-ins looks like hyperfocus that has
    /// gone on long enough to start costing the body: consecutive high-focus
    /// reports and no accepted break for a long stretch.
    public static func hyperfocusGuardTriggered(
        consecutiveHighFocus: Int,
        minutesSinceLastBreak: Int?
    ) -> Bool {
        guard consecutiveHighFocus >= hyperfocusStreakThreshold else { return false }
        guard let minutes = minutesSinceLastBreak else {
            // Never taken a break Attune knows about; streak alone decides.
            return true
        }
        return minutes >= hyperfocusMinutesWithoutBreak
    }
}
