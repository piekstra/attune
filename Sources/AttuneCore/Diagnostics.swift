import Foundation

/// `attune --diagnostics` output: everything needed to sanity-check an
/// installation from the terminal, with zero side effects on stored data.
public enum Diagnostics {
    public static func report(now: Date = Date()) -> String {
        var lines: [String] = []
        lines.append("Attune diagnostics")
        lines.append(String(repeating: "-", count: 40))

        if let dir = try? StoragePaths.appSupportDirectory() {
            lines.append("Data folder:        \(dir.path)")
        } else {
            lines.append("Data folder:        UNAVAILABLE")
        }

        let zoom = MeetingDetector.isZoomRunning()
        let mic = MeetingDetector.isDefaultInputDeviceInUse()
        lines.append("Zoom running:       \(zoom)")
        lines.append("Microphone in use:  \(mic)")
        lines.append("Meeting verdict:    \(zoom && mic) (default policy: Zoom AND mic)")

        let idle = SystemIdleTime.secondsSinceLastInput()
        lines.append(String(format: "Idle time:          %.0fs since last input", idle))

        let settings = (try? SettingsStore())?.load() ?? .default
        lines.append("Base interval:      \(settings.baseIntervalMinutes) min (adaptive: \(settings.adaptiveCadence))")
        lines.append("Work window:        \(settings.workStartHour):00–\(settings.workEndHour):00, days \(settings.workDays.sorted())")
        lines.append("Within work hours:  \(SchedulePolicy.isWithinWorkHours(now, settings: settings))")

        for focus in [FocusLevel.scattered, .coasting, .lockedIn] {
            let interval = SchedulePolicy.nextInterval(afterFocus: focus, settings: settings)
            lines.append(String(
                format: "Next interval after \"%@\": %.0f min",
                focus.label, interval / 60
            ))
        }

        if let store = try? ActivityStore() {
            lines.append("Active today:       \(formatMinutes(store.minutesToday(now: now)))")
            lines.append("Active last 7 days: \(formatMinutes(store.minutesInLastDays(7, now: now)))")
            let span = store.spanMinutesToday(now: now).map(formatMinutes) ?? "—"
            let away = store.awayMinutesToday(now: now).map(formatMinutes) ?? "—"
            lines.append("Work-day span:      \(span)  (away: \(away))")
            if let first = store.firstActivity(on: now), let last = store.lastActivity(on: now) {
                lines.append("Bracket:            \(formatClockTime(first)) → \(formatClockTime(last))")
            }
        }

        if let historyStore = try? HistoryStore() {
            let recent = historyStore.recent(days: 14)
            lines.append("Check-ins (14d):    \(recent.count) recorded")
        }

        return lines.joined(separator: "\n")
    }
}
