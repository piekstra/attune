import XCTest
@testable import AttuneCore

final class AwayBridgeTests: XCTestCase {

    // MARK: - Settings migration

    func testOldSettingsFileWithoutNewKeysDecodesWithDefaults() throws {
        // A settings.json written before the away-from-Mac features existed.
        let legacyJSON = """
        {
          "baseIntervalMinutes": 60,
          "adaptiveCadence": false,
          "workStartHour": 9,
          "workEndHour": 17,
          "workDays": [2, 3, 4],
          "deferDuringMeetings": true,
          "anyMicUseCountsAsMeeting": false,
          "playSound": false,
          "paused": false
        }
        """
        let settings = try JSONDecoder().decode(
            UserSettings.self, from: Data(legacyJSON.utf8)
        )
        // Old values survive…
        XCTAssertEqual(settings.baseIntervalMinutes, 60)
        XCTAssertFalse(settings.adaptiveCadence)
        XCTAssertEqual(settings.workDays, [2, 3, 4])
        // …new keys get their defaults instead of failing the decode.
        XCTAssertFalse(settings.ringAppleDevicesViaReminders)
        XCTAssertEqual(settings.breakEndWebhookURL, "")
    }

    func testEmptySettingsFileDecodesToDefaults() throws {
        let settings = try JSONDecoder().decode(
            UserSettings.self, from: Data("{}".utf8)
        )
        XCTAssertEqual(settings, .default)
    }

    func testNewSettingsRoundTrip() throws {
        var settings = UserSettings.default
        settings.ringAppleDevicesViaReminders = true
        settings.breakEndWebhookURL = "https://ntfy.sh/my-topic"
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(UserSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }

    // MARK: - Webhook

    func testWebhookRequestShape() throws {
        let url = try XCTUnwrap(URL(string: "https://ntfy.sh/topic"))
        let request = WebhookNotifier.makeRequest(url: url, message: "hello")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url, url)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Title"), "Break timer done")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Tags"), "bell")
        XCTAssertEqual(request.httpBody, Data("hello".utf8))
        XCTAssertEqual(request.timeoutInterval, 10)
    }

    func testWebhookURLValidation() {
        XCTAssertNil(WebhookNotifier.validatedURL(from: ""))
        XCTAssertNil(WebhookNotifier.validatedURL(from: "   "))
        XCTAssertNil(WebhookNotifier.validatedURL(from: "not a url"))
        XCTAssertNil(WebhookNotifier.validatedURL(from: "ftp://example.com/x"))
        XCTAssertNil(WebhookNotifier.validatedURL(from: "https://"))
        XCTAssertEqual(
            WebhookNotifier.validatedURL(from: " https://ntfy.sh/topic ")?.absoluteString,
            "https://ntfy.sh/topic"
        )
        XCTAssertNotNil(WebhookNotifier.validatedURL(from: "http://homeassistant.local:8123/api/webhook/abc"))
    }

    // MARK: - Reminder content

    func testReminderContentDueDate() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let content = ReminderBridge.reminderContent(minutes: 20, from: start)
        XCTAssertEqual(
            content.due.timeIntervalSince(start), 20 * 60, accuracy: 0.001
        )
        XCTAssertFalse(content.title.isEmpty)
    }

    func testReminderTitleCarriesTheNote() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let content = ReminderBridge.reminderContent(
            minutes: 15, note: "  next: re-run the failing test  ", from: start
        )
        XCTAssertEqual(content.title, "Head back 🔔 — next: re-run the failing test")
    }

    func testReminderTitleFallsBackWhenNoteEmpty() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for note in [nil, "", "   "] as [String?] {
            let content = ReminderBridge.reminderContent(
                minutes: 15, note: note, from: start
            )
            XCTAssertEqual(content.title, "Head back 🔔 — break timer's done")
        }
    }

    // MARK: - Break timer note lifecycle

    @MainActor
    func testBreakTimerCarriesAndClearsNote() {
        let timer = BreakTimer()
        timer.start(minutes: 15, label: "House sprint", note: "  fold, then invoice draft ")
        XCTAssertEqual(timer.note, "fold, then invoice draft")
        timer.cancel()
        XCTAssertEqual(timer.note, "")
    }
}
