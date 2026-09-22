import Foundation

/// Owns the timers. All the *rules* live in `SchedulePolicy`; this class
/// just turns them into wall-clock behavior and handles the meeting dance:
///
///   fire due → meeting in progress? → hold, poll every 2 min
///            → meeting over → wait a short grace period → fire
///
/// so check-ins land just after the natural boundary of a call, never
/// during it.
@MainActor
public final class CheckInScheduler {

    public enum State: Equatable {
        case idle
        case waiting(until: Date)
        case deferredForMeeting
        case paused
    }

    public private(set) var state: State = .idle

    /// Called when a check-in should be shown.
    public var onFire: (() -> Void)?
    /// Called once each time a due check-in gets held for a meeting,
    /// so the app can record the deferral.
    public var onDeferredForMeeting: (() -> Void)?

    private let meetingDetector: MeetingDetecting
    private let settingsProvider: () -> UserSettings
    private var timer: Timer?

    public init(
        meetingDetector: MeetingDetecting,
        settingsProvider: @escaping () -> UserSettings
    ) {
        self.meetingDetector = meetingDetector
        self.settingsProvider = settingsProvider
    }

    /// Schedule the next check-in based on what the user just reported
    /// (nil = skipped/missed/first launch → baseline interval).
    public func scheduleNext(afterFocus focus: FocusLevel? = nil, from now: Date = Date()) {
        let settings = settingsProvider()
        guard !settings.paused else {
            transition(to: .paused)
            return
        }
        let interval = SchedulePolicy.nextInterval(afterFocus: focus, settings: settings)
        let target = now.addingTimeInterval(interval)
        let allowed = SchedulePolicy.nextAllowedDate(from: target, settings: settings)
        scheduleFire(at: allowed)
    }

    /// "Remind me in N minutes."
    public func snooze(minutes: Int, from now: Date = Date()) {
        scheduleFire(at: now.addingTimeInterval(Double(minutes) * 60))
    }

    public func pause() {
        transition(to: .paused)
    }

    public func resume(from now: Date = Date()) {
        guard state == .paused else { return }
        scheduleNext(from: now)
    }

    public var nextFireDate: Date? {
        if case .waiting(let date) = state { return date }
        return nil
    }

    // MARK: - Internals

    private func scheduleFire(at date: Date) {
        transition(to: .waiting(until: date))
        let interval = max(1, date.timeIntervalSinceNow)
        setTimer(interval: interval) { [weak self] in
            self?.fireIfPossible()
        }
    }

    private func fireIfPossible() {
        let settings = settingsProvider()
        guard !settings.paused else {
            transition(to: .paused)
            return
        }
        // Outside work hours (e.g. the machine slept through the window):
        // quietly move to the next allowed time.
        let now = Date()
        if !SchedulePolicy.isWithinWorkHours(now, settings: settings) {
            let next = SchedulePolicy.nextAllowedDate(from: now, settings: settings)
            scheduleFire(at: next)
            return
        }
        if meetingDetector.isInMeeting(settings: settings) {
            if state != .deferredForMeeting {
                transition(to: .deferredForMeeting)
                onDeferredForMeeting?()
            }
            setTimer(interval: SchedulePolicy.meetingPollSeconds) { [weak self] in
                self?.pollMeeting()
            }
            return
        }
        transition(to: .idle)
        onFire?()
    }

    private func pollMeeting() {
        let settings = settingsProvider()
        if meetingDetector.isInMeeting(settings: settings) {
            setTimer(interval: SchedulePolicy.meetingPollSeconds) { [weak self] in
                self?.pollMeeting()
            }
        } else {
            // Meeting over — fire after the grace period, at the boundary.
            let grace = Double(SchedulePolicy.postMeetingGraceMinutes) * 60
            scheduleFire(at: Date().addingTimeInterval(grace))
        }
    }

    private func setTimer(interval: TimeInterval, block: @escaping () -> Void) {
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: false) { _ in
            block()
        }
        // Tolerance lets the system coalesce wakeups; a check-in landing a
        // minute late is free, a battery hit is not.
        t.tolerance = min(60, interval * 0.1)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func transition(to newState: State) {
        if case .paused = newState {
            timer?.invalidate()
            timer = nil
        }
        state = newState
    }
}
