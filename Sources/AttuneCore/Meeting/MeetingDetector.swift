import AppKit
import CoreAudio
import Foundation

/// Detects "the user appears to be in a call" without any special
/// permissions, screen recording, or network access.
///
/// Two cheap signals:
/// 1. Zoom is running (`NSWorkspace`, public API).
/// 2. The default audio *input* device is in use by some process
///    (CoreAudio's `kAudioDevicePropertyDeviceIsRunningSomewhere`). Zoom
///    keeps the input device open for the whole meeting even while muted,
///    so this holds across mute/unmute.
///
/// Default policy: in a meeting when Zoom is running AND the mic is live.
/// The optional broader mode treats any mic use as a call, which also covers
/// Meet/Teams/FaceTime at the cost of false positives from dictation or
/// voice memos — the user chooses.
///
/// Known limitation, documented in the README: Zoom open in the background
/// while another app records audio will read as "in a meeting". The failure
/// mode is a deferred check-in, never a missed meeting interruption — the
/// design errs on the side of not interrupting.
public protocol MeetingDetecting {
    func isInMeeting(settings: UserSettings) -> Bool
}

public final class MeetingDetector: MeetingDetecting {
    static let zoomBundleID = "us.zoom.xos"

    public init() {}

    public func isInMeeting(settings: UserSettings) -> Bool {
        guard settings.deferDuringMeetings else { return false }
        let micLive = Self.isDefaultInputDeviceInUse()
        if settings.anyMicUseCountsAsMeeting {
            return micLive
        }
        return Self.isZoomRunning() && micLive
    }

    public static func isZoomRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == zoomBundleID
        }
    }

    public static func isDefaultInputDeviceInUse() -> Bool {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var defaultInputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputAddress,
            0, nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else {
            return false
        }

        var isRunning: UInt32 = 0
        var runningSize = UInt32(MemoryLayout<UInt32>.size)
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let runningStatus = AudioObjectGetPropertyData(
            deviceID,
            &runningAddress,
            0, nil,
            &runningSize,
            &isRunning
        )
        guard runningStatus == noErr else { return false }
        return isRunning != 0
    }
}
