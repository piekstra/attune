import EventKit
import Foundation

/// Rings the user's iPhone and Apple Watch when a break timer ends —
/// without any app servers — by creating a Reminder due at the timer's end
/// in the user's own Reminders account. iCloud does the transport; the
/// phone and watch fire the notification.
///
/// Boundaries:
/// - Only ever *creates* reminders it owns (and deletes those same
///   reminders when a break is cancelled or acknowledged early). It never
///   reads existing reminders.
/// - Requires the reminders permission, requested lazily the first time
///   the feature actually fires — never at launch.
/// - Needs a real bundle identifier for the TCC permission prompt, so the
///   feature is available in Attune.app but not under bare `swift run`.
@MainActor
public final class ReminderBridge {
    private let store = EKEventStore()
    private var pendingReminderID: String?

    public init() {}

    /// The TCC prompt requires a bundled app; bare executables can't ask.
    public nonisolated static var isSupported: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    public nonisolated static var isDenied: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .denied
    }

    /// Title/due-date construction, separated for testability. The user's
    /// note rides along in the title so the phone says what to do next —
    /// it stays inside their own iCloud account (unlike the webhook, which
    /// deliberately never carries the note).
    public nonisolated static func reminderContent(
        minutes: Int, note: String? = nil, from start: Date
    ) -> (title: String, due: Date) {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = trimmed.isEmpty
            ? "Head back 🔔 — break timer's done"
            : "Head back 🔔 — \(trimmed)"
        return (title: title, due: start.addingTimeInterval(Double(minutes) * 60))
    }

    /// Create the return reminder for a break starting now. Replaces any
    /// still-pending reminder from a previous break.
    public func scheduleReturnReminder(
        minutes: Int, note: String? = nil, from start: Date = Date()
    ) {
        guard Self.isSupported else { return }
        clearPendingReminder()
        store.requestFullAccessToReminders { [weak self] granted, error in
            if let error {
                NSLog("Attune: reminders access error: \(error)")
            }
            guard granted else { return }
            Task { @MainActor in
                self?.createReminder(minutes: minutes, note: note, from: start)
            }
        }
    }

    /// Remove the pending reminder — used when the user cancels the break,
    /// acknowledges the return prompt, or extends by five minutes (a new
    /// reminder replaces it). Safe to call when nothing is pending.
    public func clearPendingReminder() {
        guard let id = pendingReminderID else { return }
        pendingReminderID = nil
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            return
        }
        do {
            try store.remove(reminder, commit: true)
        } catch {
            NSLog("Attune: could not remove return reminder: \(error)")
        }
    }

    private func createReminder(minutes: Int, note: String?, from start: Date) {
        guard let calendar = store.defaultCalendarForNewReminders() else {
            NSLog("Attune: no default reminders list; skipping device ring")
            return
        }
        let content = Self.reminderContent(minutes: minutes, note: note, from: start)
        let reminder = EKReminder(eventStore: store)
        reminder.title = content.title
        reminder.calendar = calendar
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: content.due
        )
        reminder.addAlarm(EKAlarm(absoluteDate: content.due))
        do {
            try store.save(reminder, commit: true)
            pendingReminderID = reminder.calendarItemIdentifier
        } catch {
            NSLog("Attune: could not save return reminder: \(error)")
        }
    }
}
