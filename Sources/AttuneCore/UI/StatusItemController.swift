import AppKit

/// The menu bar presence. Shows a brain icon (plus a countdown while a
/// break timer runs) and a menu rebuilt fresh each time it opens so the
/// "next check-in" line and pause state are always current.
@MainActor
public final class StatusItemController: NSObject, NSMenuDelegate {

    public struct MenuInfo {
        public let nextFireDate: Date?
        public let paused: Bool
        public let deferredForMeeting: Bool
        public let breakTimerRunning: Bool
        /// Real at-keyboard minutes so far today, if tracking is available.
        public let todayActiveMinutes: Int?
        /// Full-day span so far today (first activity → last), if available.
        public let todaySpanMinutes: Int?

        public init(
            nextFireDate: Date?,
            paused: Bool,
            deferredForMeeting: Bool,
            breakTimerRunning: Bool,
            todayActiveMinutes: Int? = nil,
            todaySpanMinutes: Int? = nil
        ) {
            self.nextFireDate = nextFireDate
            self.paused = paused
            self.deferredForMeeting = deferredForMeeting
            self.breakTimerRunning = breakTimerRunning
            self.todayActiveMinutes = todayActiveMinutes
            self.todaySpanMinutes = todaySpanMinutes
        }
    }

    public var onCheckInNow: (() -> Void)?
    public var onSnooze30: (() -> Void)?
    public var onTogglePause: (() -> Void)?
    public var onShowInsights: (() -> Void)?
    public var onShowSettings: (() -> Void)?
    public var onCancelBreakTimer: (() -> Void)?
    public var onAbout: (() -> Void)?
    public var menuInfoProvider: (() -> MenuInfo)?

    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    public override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "brain.head.profile",
                accessibilityDescription: "Attune focus check-ins"
            )
            button.imagePosition = .imageLeft
        }
        menu.delegate = self
        statusItem.menu = menu

        // One startup breadcrumb for support: menu bar overflow on notched
        // Macs silently hides status items, and that is otherwise
        // indistinguishable from the app not running.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            let frame = self.statusItem.button?.window?.frame ?? .zero
            NSLog(
                "Attune status item: visible=%d frame=%@",
                self.statusItem.isVisible ? 1 : 0,
                NSStringFromRect(frame)
            )
        }
    }

    /// Countdown text next to the icon while a break timer runs, e.g. "12m".
    public func setCountdown(_ text: String?) {
        statusItem.button?.title = text.map { " \($0)" } ?? ""
    }

    // MARK: - NSMenuDelegate

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let info = menuInfoProvider?() ?? MenuInfo(
            nextFireDate: nil, paused: false,
            deferredForMeeting: false, breakTimerRunning: false
        )

        menu.addItem(disabledItem(statusLine(info)))
        if let minutes = info.todayActiveMinutes {
            menu.addItem(disabledItem("Active today: \(formatMinutes(minutes))"))
        }
        if let span = info.todaySpanMinutes {
            menu.addItem(disabledItem("Work-day span: \(formatMinutes(span))"))
        }
        menu.addItem(.separator())

        menu.addItem(item("Check in now", #selector(checkInNow), key: "c"))
        if !info.paused {
            menu.addItem(item("Snooze next check-in 30 min", #selector(snooze30)))
        }
        if info.breakTimerRunning {
            menu.addItem(item("Cancel break timer", #selector(cancelBreakTimer)))
        }
        menu.addItem(.separator())

        menu.addItem(item("Insights…", #selector(showInsights), key: "i"))
        menu.addItem(item("Settings…", #selector(showSettings), key: ","))
        menu.addItem(.separator())

        menu.addItem(item(
            info.paused ? "Resume check-ins" : "Pause check-ins",
            #selector(togglePause)
        ))
        menu.addItem(.separator())

        menu.addItem(item("About Attune", #selector(about)))
        let quit = NSMenuItem(
            title: "Quit Attune",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)
    }

    private func statusLine(_ info: MenuInfo) -> String {
        if info.paused { return "Check-ins paused" }
        if info.deferredForMeeting { return "Holding until your meeting ends" }
        if let next = info.nextFireDate {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Next check-in around \(formatter.string(from: next))"
        }
        return "Attune is running"
    }

    // MARK: - Actions

    @objc private func checkInNow() { onCheckInNow?() }
    @objc private func snooze30() { onSnooze30?() }
    @objc private func togglePause() { onTogglePause?() }
    @objc private func showInsights() { onShowInsights?() }
    @objc private func showSettings() { onShowSettings?() }
    @objc private func cancelBreakTimer() { onCancelBreakTimer?() }
    @objc private func about() { onAbout?() }

    // MARK: - Helpers

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
