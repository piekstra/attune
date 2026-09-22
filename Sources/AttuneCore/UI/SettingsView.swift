import ServiceManagement
import SwiftUI

/// All the knobs, phrased in plain language. Autonomy support is a design
/// requirement, not a nicety: tools that let people set their own terms are
/// the ones that survive week three.
public struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    public init(model: SettingsModel) {
        self.model = model
    }

    private let weekdaySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    public var body: some View {
        Form {
            Section("Check-in rhythm") {
                Stepper(
                    "About every \(model.settings.baseIntervalMinutes) minutes",
                    value: $model.settings.baseIntervalMinutes,
                    in: SchedulePolicy.minIntervalMinutes...SchedulePolicy.maxIntervalMinutes,
                    step: 5
                )
                Toggle(isOn: $model.settings.adaptiveCadence) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Adapt to my focus")
                        Text("Waits longer when you're locked in; checks sooner when you're struggling.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Work window") {
                Picker("From", selection: $model.settings.workStartHour) {
                    ForEach(4..<13, id: \.self) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
                Picker("Until", selection: $model.settings.workEndHour) {
                    ForEach(13..<24, id: \.self) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { day in
                        dayToggle(day)
                    }
                }
            }

            Section("Meetings") {
                Toggle(isOn: $model.settings.deferDuringMeetings) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hold check-ins during Zoom calls")
                        Text("Detected locally: Zoom running with the microphone live. The check-in arrives a couple of minutes after the call ends instead.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: $model.settings.anyMicUseCountsAsMeeting) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Treat any microphone use as a call")
                        Text("Also covers Meet, Teams, FaceTime — but dictation and voice memos will pause check-ins too.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!model.settings.deferDuringMeetings)
            }

            Section("When you step away") {
                Toggle(isOn: $model.settings.ringAppleDevicesViaReminders) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ring my iPhone & Apple Watch when a break ends")
                        Text(reminderBridgeCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!ReminderBridge.isSupported)
                VStack(alignment: .leading, spacing: 2) {
                    TextField(
                        "Break-end webhook URL",
                        text: $model.settings.breakEndWebhookURL,
                        prompt: Text("https://ntfy.sh/your-private-topic")
                    )
                    Text("Optional. POSTs a short “head back” message when a break timer ends — covers Android via the free ntfy app, Home Assistant, and anything with an HTTP endpoint. Empty means off; this is the app's only network call.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Delivery") {
                Toggle("Soft sound when a check-in appears", isOn: $model.settings.playSound)
                launchAtLogin
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 520)
    }

    private func dayToggle(_ day: Int) -> some View {
        let isOn = model.settings.workDays.contains(day)
        return Button {
            if isOn {
                model.settings.workDays.remove(day)
            } else {
                model.settings.workDays.insert(day)
            }
        } label: {
            Text(weekdaySymbols[day - 1])
                .font(.caption.weight(isOn ? .semibold : .regular))
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isOn ? Theme.accent.opacity(0.2) : Color.primary.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }

    private var reminderBridgeCaption: String {
        if !ReminderBridge.isSupported {
            return "Available when running the bundled app (Scripts/make-app.sh). Creates a Reminder due at timer end; your iCloud delivers the buzz — no app servers."
        }
        if ReminderBridge.isDenied {
            return "Reminders access is off. Enable it in System Settings → Privacy & Security → Reminders."
        }
        return "Creates a Reminder due at timer end; your iCloud delivers the buzz to your devices — no app servers involved."
    }

    @ViewBuilder
    private var launchAtLogin: some View {
        if Bundle.main.bundleIdentifier != nil {
            LaunchAtLoginToggle()
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Launch at login")
                Text("Available when running the bundled Attune.app (see README: Scripts/make-app.sh).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// SMAppService-backed toggle; only functional inside a real .app bundle.
struct LaunchAtLoginToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle("Launch at login", isOn: $enabled)
                .onChange(of: enabled) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                        error = nil
                    } catch {
                        self.error = error.localizedDescription
                        enabled = SMAppService.mainApp.status == .enabled
                    }
                }
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}
