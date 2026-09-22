import AppKit
import SwiftUI

/// Composition root: owns every component and wires the flows together.
///
///   scheduler fires ──▶ check-in panel ──▶ engine picks guidance
///        ▲                                     │
///        └── schedule next (adaptive) ◀── user responds / timer runs
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let showCheckInOnLaunch: Bool

    private var settingsModel: SettingsModel!
    private var history: HistoryStore!
    private var activityStore: ActivityStore!
    private var activityMonitor: ActivityMonitor!
    private var scheduler: CheckInScheduler!
    private let meetingDetector = MeetingDetector()
    private let breakTimer = BreakTimer()
    private let reminderBridge = ReminderBridge()

    private var statusItem: StatusItemController!
    private let checkInPanel = PanelController()
    private let returnPanel = PanelController()
    private var insightsWindow: NSWindow?
    private var settingsWindow: NSWindow?

    /// Seconds a check-in panel waits before quietly recording "missed".
    private let checkInTimeout: TimeInterval = 150

    public init(showCheckInOnLaunch: Bool = false) {
        self.showCheckInOnLaunch = showCheckInOnLaunch
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            settingsModel = SettingsModel(store: try SettingsStore())
            history = try HistoryStore()
            activityStore = try ActivityStore()
        } catch {
            // Application Support being unavailable is not survivable in a
            // useful way; fail visibly rather than half-run.
            let alert = NSAlert()
            alert.messageText = "Attune couldn't access its data folder"
            alert.informativeText = String(describing: error)
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        activityMonitor = ActivityMonitor(store: activityStore)
        activityMonitor.start()

        scheduler = CheckInScheduler(
            meetingDetector: meetingDetector,
            settingsProvider: { [weak self] in
                self?.settingsModel.settings ?? .default
            }
        )
        scheduler.onFire = { [weak self] in self?.presentCheckIn() }
        scheduler.onDeferredForMeeting = { [weak self] in
            guard let self else { return }
            self.history.append(
                CheckIn(date: Date(), outcome: .deferredForMeeting)
            )
        }

        breakTimer.onTick = { [weak self] in
            guard let self else { return }
            self.statusItem.setCountdown(
                self.breakTimer.isRunning ? self.breakTimer.remainingMinutesDisplay : nil
            )
        }
        breakTimer.onCompleted = { [weak self] in self?.breakTimerEnded() }

        setUpStatusItem()

        if showCheckInOnLaunch || isFirstLaunch {
            // First launch: show a check-in right away so the app introduces
            // itself by doing its job, not with a manual.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.presentCheckIn()
            }
        } else {
            scheduler.scheduleNext()
        }
    }

    public func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private var isFirstLaunch: Bool {
        history.all.isEmpty
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        statusItem = StatusItemController()
        statusItem.menuInfoProvider = { [weak self] in
            guard let self else {
                return .init(
                    nextFireDate: nil, paused: false,
                    deferredForMeeting: false, breakTimerRunning: false
                )
            }
            return .init(
                nextFireDate: self.scheduler.nextFireDate,
                paused: self.settingsModel.settings.paused,
                deferredForMeeting: self.scheduler.state == .deferredForMeeting,
                breakTimerRunning: self.breakTimer.isRunning,
                todayActiveMinutes: self.activityStore.minutesToday(),
                todaySpanMinutes: self.activityStore.spanMinutesToday()
            )
        }
        statusItem.onCheckInNow = { [weak self] in self?.presentCheckIn() }
        statusItem.onSnooze30 = { [weak self] in self?.scheduler.snooze(minutes: 30) }
        statusItem.onTogglePause = { [weak self] in self?.togglePause() }
        statusItem.onShowInsights = { [weak self] in self?.showInsights() }
        statusItem.onShowSettings = { [weak self] in self?.showSettings() }
        statusItem.onCancelBreakTimer = { [weak self] in self?.cancelBreak() }
        statusItem.onAbout = {
            NSWorkspace.shared.open(URL(string: "https://github.com/piekstra/attune")!)
        }
    }

    private func togglePause() {
        settingsModel.settings.paused.toggle()
        if settingsModel.settings.paused {
            scheduler.pause()
        } else {
            scheduler.resume()
        }
    }

    // MARK: - Check-in flow

    private func presentCheckIn() {
        guard !checkInPanel.isVisible else { return }
        let view = CheckInView(
            makeRecommendation: { [weak self] focus, energy, pull in
                self?.makeRecommendation(focus: focus, energy: energy, pull: pull)
                    ?? Catalog.microBreak[0]
            },
            onComplete: { [weak self] result in self?.completeCheckIn(result) },
            onSkip: { [weak self] in self?.skipCheckIn() },
            onStartTimer: { [weak self] recommendation, note in
                guard let self, let minutes = recommendation.timerMinutes else { return }
                self.startBreak(
                    minutes: minutes,
                    label: recommendation.title,
                    note: note ?? ""
                )
            }
        )
        checkInPanel.show(
            view,
            playSound: settingsModel.settings.playSound,
            timeout: checkInTimeout,
            onTimeout: { [weak self] in self?.missCheckIn() }
        )
    }

    private func makeRecommendation(
        focus: FocusLevel, energy: EnergyLevel, pull: Pull?
    ) -> Recommendation {
        let now = Date()
        let context = RecommendationContext(
            focus: focus,
            energy: energy,
            pull: pull,
            minutesSinceLastBreak: HistoryAnalysis.minutesSinceLastBreak(
                history: history.all, now: now
            ),
            consecutiveHighFocus: HistoryAnalysis.consecutiveHighFocus(
                history: history.all
            ),
            hour: Calendar.current.component(.hour, from: now),
            workEndHour: settingsModel.settings.workEndHour,
            activeMinutesToday: activityStore.minutesToday(now: now),
            fullDaySpanMinutes: activityStore.spanMinutesToday(now: now),
            variantSeed: history.all.count
        )
        return RecommendationEngine.recommend(context)
    }

    private func completeCheckIn(_ result: CheckInResult) {
        history.append(
            CheckIn(
                date: Date(),
                focus: result.focus,
                energy: result.energy,
                pull: result.pull,
                outcome: .completed,
                recommendationID: result.recommendation.id,
                action: result.action
            )
        )
        checkInPanel.close()
        if result.action == .snoozed {
            scheduler.snooze(minutes: 15)
        } else {
            scheduler.scheduleNext(afterFocus: result.focus)
        }
    }

    private func skipCheckIn() {
        history.append(CheckIn(date: Date(), outcome: .skipped))
        checkInPanel.close()
        scheduler.scheduleNext()
    }

    private func missCheckIn() {
        history.append(CheckIn(date: Date(), outcome: .missed))
        scheduler.scheduleNext()
    }

    // MARK: - Break lifecycle

    /// One path for every break start, so the away-from-Mac bridges always
    /// travel with the timer.
    private func startBreak(minutes: Int, label: String, note: String = "") {
        breakTimer.start(minutes: minutes, label: label, note: note)
        if settingsModel.settings.ringAppleDevicesViaReminders {
            reminderBridge.scheduleReturnReminder(minutes: minutes, note: note)
        }
    }

    private func cancelBreak() {
        breakTimer.cancel()
        // The break didn't run its course, so the phone shouldn't buzz.
        reminderBridge.clearPendingReminder()
    }

    private func breakTimerEnded() {
        // The reminder (if any) is firing on the user's devices right now —
        // leave it; it gets cleaned up when they acknowledge the return
        // prompt. The webhook is the "everything else" channel (ntfy on
        // Android, Home Assistant, ...).
        WebhookNotifier.sendBreakEnded(
            urlString: settingsModel.settings.breakEndWebhookURL,
            breakLabel: breakTimer.label.isEmpty ? "break" : breakTimer.label
        )
        presentReturnPrompt()
    }

    private func presentReturnPrompt() {
        // Captured now: starting the five-more timer resets the break state.
        let note = breakTimer.note
        let view = ReturnPromptView(
            breakLabel: breakTimer.label,
            note: note,
            onBack: { [weak self] in
                guard let self else { return }
                self.reminderBridge.clearPendingReminder()
                self.returnPanel.close()
            },
            onFiveMore: { [weak self] in
                guard let self else { return }
                self.reminderBridge.clearPendingReminder()
                self.returnPanel.close()
                self.startBreak(minutes: 5, label: "5 more minutes", note: note)
            }
        )
        returnPanel.show(view, playSound: settingsModel.settings.playSound)
    }

    // MARK: - Windows

    private func showInsights() {
        let now = Date()
        let view = InsightsView(
            history: history.recent(days: 14),
            activity: .init(
                todayMinutes: activityStore.minutesToday(now: now),
                weekMinutes: activityStore.minutesInLastDays(7, now: now),
                todaySpanMinutes: activityStore.spanMinutesToday(now: now),
                todayAwayMinutes: activityStore.awayMinutesToday(now: now),
                todayFirstActivity: activityStore.firstActivity(on: now),
                todayLastActivity: activityStore.lastActivity(on: now),
                weekAverageSpanMinutes: activityStore.averageSpanMinutes(lastDays: 7, now: now)
            )
        )
        presentWindow(
            &insightsWindow,
            title: "Attune — Insights",
            content: view
        )
    }

    private func showSettings() {
        presentWindow(
            &settingsWindow,
            title: "Attune — Settings",
            content: SettingsView(model: settingsModel)
        )
    }

    private func presentWindow<Content: View>(
        _ slot: inout NSWindow?,
        title: String,
        content: Content
    ) {
        if let window = slot {
            window.contentViewController = NSHostingController(rootView: content)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        slot = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
