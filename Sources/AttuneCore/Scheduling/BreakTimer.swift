import Combine
import Foundation

/// Countdown for an accepted suggestion ("20-minute laundry trade",
/// "5-minute walk"). The timer is the load-bearing half of the context
/// switch: it externalizes time (which ADHD brains under-track) and turns
/// "I'll come back in a bit" into a definite boundary with a prompt at
/// the end.
@MainActor
public final class BreakTimer: ObservableObject {
    @Published public private(set) var remainingSeconds: Int = 0
    @Published public private(set) var isRunning = false
    /// What the countdown is for, e.g. "Movement break" — shown in the menu bar.
    @Published public private(set) var label: String = ""

    /// The user's optional "note to my future self", carried through the
    /// break and shown back at the return prompt. This is the
    /// ready-to-resume plan that research says cuts attention residue —
    /// held by the app so working memory doesn't have to.
    @Published public private(set) var note: String = ""

    /// Fires when the countdown reaches zero (not when cancelled).
    public var onCompleted: (() -> Void)?
    /// Fires every tick so the menu bar can show remaining minutes.
    public var onTick: (() -> Void)?

    private var timer: Timer?

    public init() {}

    public func start(minutes: Int, label: String, note: String = "") {
        cancel()
        self.label = label
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        remainingSeconds = minutes * 60
        isRunning = true
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        onTick?()
    }

    public func cancel() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        remainingSeconds = 0
        label = ""
        note = ""
        onTick?()
    }

    public var remainingMinutesDisplay: String {
        let minutes = Int(ceil(Double(remainingSeconds) / 60))
        return "\(minutes)m"
    }

    private func tick() {
        guard isRunning else { return }
        remainingSeconds -= 1
        onTick?()
        if remainingSeconds <= 0 {
            timer?.invalidate()
            timer = nil
            isRunning = false
            onTick?()
            onCompleted?()
        }
    }
}
