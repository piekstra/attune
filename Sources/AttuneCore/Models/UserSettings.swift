import Foundation

/// User-tunable behavior. Defaults are chosen from the research summarized
/// in docs/DESIGN.md; every one of them is overridable because autonomy is
/// the point (self-determination theory: tools that support autonomy are the
/// ones that keep getting used).
public struct UserSettings: Codable, Equatable, Sendable {
    /// Baseline minutes between check-ins. The scheduler adapts around this.
    public var baseIntervalMinutes: Int

    /// Whether the interval adapts to reported focus (stretching out when
    /// focus is high, tightening when it is low).
    public var adaptiveCadence: Bool

    /// Hour of day (0–23, local time) when check-ins may start.
    public var workStartHour: Int

    /// Hour of day (0–23, local time) after which check-ins stop.
    public var workEndHour: Int

    /// Weekdays check-ins run on. Uses Calendar weekday numbers (1 = Sunday).
    public var workDays: Set<Int>

    /// Hold check-ins while a Zoom meeting appears to be in progress.
    public var deferDuringMeetings: Bool

    /// Treat *any* microphone use as a call (covers Meet, Teams, FaceTime, …),
    /// not just Zoom. Off by default: dictation and voice memos would
    /// otherwise silence check-ins.
    public var anyMicUseCountsAsMeeting: Bool

    /// Play a soft sound when a check-in appears. A gentle audio cue helps
    /// the check-in get noticed without demanding eyes-on-screen.
    public var playSound: Bool

    /// Master switch, togglable from the menu ("Pause for today").
    public var paused: Bool

    /// When a break timer starts, create a Reminder due at its end so the
    /// user's own iCloud rings their iPhone and Apple Watch wherever they
    /// are. No app servers involved; see ReminderBridge.
    public var ringAppleDevicesViaReminders: Bool

    /// Optional URL POSTed a short "head back" message when a break timer
    /// ends — covers Android via ntfy, Home Assistant, and anything else
    /// with an HTTP endpoint. Empty string = off. This is the app's single,
    /// opt-in, user-configured network call; see WebhookNotifier.
    public var breakEndWebhookURL: String

    public init(
        baseIntervalMinutes: Int = 45,
        adaptiveCadence: Bool = true,
        workStartHour: Int = 8,
        workEndHour: Int = 18,
        workDays: Set<Int> = [2, 3, 4, 5, 6],  // Mon–Fri
        deferDuringMeetings: Bool = true,
        anyMicUseCountsAsMeeting: Bool = false,
        playSound: Bool = true,
        paused: Bool = false,
        ringAppleDevicesViaReminders: Bool = false,
        breakEndWebhookURL: String = ""
    ) {
        self.baseIntervalMinutes = baseIntervalMinutes
        self.adaptiveCadence = adaptiveCadence
        self.workStartHour = workStartHour
        self.workEndHour = workEndHour
        self.workDays = workDays
        self.deferDuringMeetings = deferDuringMeetings
        self.anyMicUseCountsAsMeeting = anyMicUseCountsAsMeeting
        self.playSound = playSound
        self.paused = paused
        self.ringAppleDevicesViaReminders = ringAppleDevicesViaReminders
        self.breakEndWebhookURL = breakEndWebhookURL
    }

    public static let `default` = UserSettings()

    // Manual decoding with per-key defaults: settings files written by
    // older versions must never fail to decode (and silently reset) just
    // because a new key was added.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = UserSettings.default
        baseIntervalMinutes =
            try c.decodeIfPresent(Int.self, forKey: .baseIntervalMinutes) ?? d.baseIntervalMinutes
        adaptiveCadence =
            try c.decodeIfPresent(Bool.self, forKey: .adaptiveCadence) ?? d.adaptiveCadence
        workStartHour =
            try c.decodeIfPresent(Int.self, forKey: .workStartHour) ?? d.workStartHour
        workEndHour =
            try c.decodeIfPresent(Int.self, forKey: .workEndHour) ?? d.workEndHour
        workDays =
            try c.decodeIfPresent(Set<Int>.self, forKey: .workDays) ?? d.workDays
        deferDuringMeetings =
            try c.decodeIfPresent(Bool.self, forKey: .deferDuringMeetings) ?? d.deferDuringMeetings
        anyMicUseCountsAsMeeting =
            try c.decodeIfPresent(Bool.self, forKey: .anyMicUseCountsAsMeeting) ?? d.anyMicUseCountsAsMeeting
        playSound =
            try c.decodeIfPresent(Bool.self, forKey: .playSound) ?? d.playSound
        paused =
            try c.decodeIfPresent(Bool.self, forKey: .paused) ?? d.paused
        ringAppleDevicesViaReminders =
            try c.decodeIfPresent(Bool.self, forKey: .ringAppleDevicesViaReminders) ?? d.ringAppleDevicesViaReminders
        breakEndWebhookURL =
            try c.decodeIfPresent(String.self, forKey: .breakEndWebhookURL) ?? d.breakEndWebhookURL
    }
}
