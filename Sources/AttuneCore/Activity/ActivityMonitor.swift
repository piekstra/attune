import CoreGraphics
import Foundation

/// Reads seconds since the user's last input event (keyboard, mouse,
/// scroll) from Quartz event counters. This requires no permissions and no
/// event tap — it never sees *what* was typed or clicked, only how long ago
/// something was.
public enum SystemIdleTime {
    private static let inputEventTypes: [CGEventType] = [
        .keyDown,
        .flagsChanged,
        .leftMouseDown,
        .rightMouseDown,
        .otherMouseDown,
        .mouseMoved,
        .leftMouseDragged,
        .scrollWheel,
    ]

    public static func secondsSinceLastInput() -> TimeInterval {
        inputEventTypes
            .map {
                CGEventSource.secondsSinceLastEventType(
                    .combinedSessionState,
                    eventType: $0
                )
            }
            .min() ?? .infinity
    }
}

/// Once a minute, checks whether the user has been active recently and, if
/// so, credits a minute to the local activity record.
///
/// Why this exists (user-facing rationale, see README): with ADHD, the
/// *memory* of a scattered day compresses toward "I got nothing done and
/// barely worked", and the usual response is working longer to make up for
/// a shortfall that may not exist. A trustworthy count of real at-computer
/// hours gives the evening decision — "am I actually done?" — an evidence
/// base instead of an anxiety base.
@MainActor
public final class ActivityMonitor {
    private let store: ActivityStore
    private let idleThresholdSeconds: TimeInterval
    private let idleSecondsProvider: () -> TimeInterval
    private var timer: Timer?

    public init(
        store: ActivityStore,
        idleThresholdSeconds: TimeInterval = 120,
        idleSecondsProvider: @escaping () -> TimeInterval = SystemIdleTime.secondsSinceLastInput
    ) {
        self.store = store
        self.idleThresholdSeconds = idleThresholdSeconds
        self.idleSecondsProvider = idleSecondsProvider
    }

    public func start() {
        stop()
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        t.tolerance = 10
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func tick(now: Date = Date()) {
        if idleSecondsProvider() < idleThresholdSeconds {
            store.credit(minutes: 1, at: now)
        }
    }
}
