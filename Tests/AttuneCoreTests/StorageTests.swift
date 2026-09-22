import XCTest
@testable import AttuneCore

final class StorageTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("attune-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return cal
    }

    private func date(
        _ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    // MARK: - HistoryStore

    func testHistoryRoundTrips() {
        let url = tempDir.appendingPathComponent("history.json")
        let store = HistoryStore(fileURL: url)
        let entry = CheckIn(
            date: Date(),
            focus: .engaged,
            energy: .steady,
            pull: .homeStuff,
            outcome: .completed,
            recommendationID: "keep-going.protect",
            action: .keptWorking
        )
        store.append(entry)

        let reloaded = HistoryStore(fileURL: url)
        XCTAssertEqual(reloaded.all.count, 1)
        XCTAssertEqual(reloaded.all.first?.focus, .engaged)
        XCTAssertEqual(reloaded.all.first?.pull, .homeStuff)
        XCTAssertEqual(reloaded.all.first?.recommendationID, "keep-going.protect")
    }

    func testHistoryCapsEntries() {
        let url = tempDir.appendingPathComponent("history.json")
        let store = HistoryStore(fileURL: url, maxEntries: 10)
        for i in 0..<25 {
            store.append(CheckIn(
                date: Date().addingTimeInterval(Double(i)),
                outcome: .skipped
            ))
        }
        XCTAssertEqual(store.all.count, 10)
    }

    func testRecentFiltersOldEntries() {
        let url = tempDir.appendingPathComponent("history.json")
        let store = HistoryStore(fileURL: url)
        let now = Date()
        store.append(CheckIn(date: now.addingTimeInterval(-20 * 24 * 3600), outcome: .completed))
        store.append(CheckIn(date: now.addingTimeInterval(-3600), outcome: .completed))
        XCTAssertEqual(store.recent(days: 14, from: now).count, 1)
    }

    // MARK: - SettingsStore

    func testSettingsRoundTrip() {
        let url = tempDir.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: url)
        var settings = UserSettings.default
        settings.baseIntervalMinutes = 60
        settings.anyMicUseCountsAsMeeting = true
        store.save(settings)

        let reloaded = SettingsStore(fileURL: url).load()
        XCTAssertEqual(reloaded.baseIntervalMinutes, 60)
        XCTAssertTrue(reloaded.anyMicUseCountsAsMeeting)
    }

    func testMissingSettingsFileYieldsDefaults() {
        let store = SettingsStore(fileURL: tempDir.appendingPathComponent("nope.json"))
        XCTAssertEqual(store.load(), .default)
    }

    // MARK: - ActivityStore

    func testActivityCreditsAccumulate() {
        let url = tempDir.appendingPathComponent("activity.json")
        let store = ActivityStore(fileURL: url, calendar: calendar)
        let morning = date(2026, 7, 1, hour: 9)
        for minute in 0..<30 {
            store.credit(at: morning.addingTimeInterval(Double(minute) * 60))
        }
        XCTAssertEqual(store.minutesToday(now: morning), 30)
    }

    func testActivityPersistsAcrossReload() {
        let url = tempDir.appendingPathComponent("activity.json")
        let store = ActivityStore(fileURL: url, calendar: calendar)
        let when = date(2026, 7, 1, hour: 14)
        store.credit(minutes: 5, at: when)

        let reloaded = ActivityStore(fileURL: url, calendar: calendar)
        XCTAssertEqual(reloaded.minutesToday(now: when), 5)
    }

    func testWeekTotalSpansDays() {
        let url = tempDir.appendingPathComponent("activity.json")
        let store = ActivityStore(fileURL: url, calendar: calendar)
        let wednesday = date(2026, 7, 1, hour: 10)
        let tuesday = date(2026, 6, 30, hour: 10)
        let lastMonth = date(2026, 6, 1, hour: 10)
        store.credit(minutes: 100, at: wednesday)
        store.credit(minutes: 50, at: tuesday)
        store.credit(minutes: 999, at: lastMonth)
        XCTAssertEqual(store.minutesInLastDays(7, now: wednesday), 150)
    }

    // MARK: - Full-day span

    func testSpanIsFirstToLastActivityIncludingGaps() {
        // The issue's scenario: active 6am, break, appointment, back at 4pm.
        // Active minutes are modest; the span is the full bracket.
        let url = tempDir.appendingPathComponent("activity.json")
        let store = ActivityStore(fileURL: url, calendar: calendar)
        store.credit(at: date(2026, 7, 1, hour: 6, minute: 0))   // first
        store.credit(at: date(2026, 7, 1, hour: 8, minute: 30))
        store.credit(at: date(2026, 7, 1, hour: 13, minute: 0))
        store.credit(at: date(2026, 7, 1, hour: 16, minute: 0))  // last
        let now = date(2026, 7, 1, hour: 16, minute: 30)
        // 6:00 → 16:00 = 10 hours = 600 minutes.
        XCTAssertEqual(store.spanMinutesToday(now: now), 600)
        // Four credited minutes → 596 minutes "away".
        XCTAssertEqual(store.minutesToday(now: now), 4)
        XCTAssertEqual(store.awayMinutesToday(now: now), 596)
    }

    func testSpanGrowsAsTheDayGoesOn() {
        let url = tempDir.appendingPathComponent("activity.json")
        let store = ActivityStore(fileURL: url, calendar: calendar)
        store.credit(at: date(2026, 7, 1, hour: 6, minute: 0))
        store.credit(at: date(2026, 7, 1, hour: 8, minute: 0))
        XCTAssertEqual(store.spanMinutes(on: date(2026, 7, 1, hour: 8)), 120)
        store.credit(at: date(2026, 7, 1, hour: 14, minute: 0))
        XCTAssertEqual(store.spanMinutes(on: date(2026, 7, 1, hour: 14)), 480)
    }

    func testFirstAndLastActivityExposed() {
        let url = tempDir.appendingPathComponent("activity.json")
        let store = ActivityStore(fileURL: url, calendar: calendar)
        let first = date(2026, 7, 1, hour: 7, minute: 15)
        let last = date(2026, 7, 1, hour: 18, minute: 45)
        store.credit(at: last)   // deliberately out of order
        store.credit(at: first)
        XCTAssertEqual(store.firstActivity(on: first), first)
        XCTAssertEqual(store.lastActivity(on: first), last)
    }

    func testSpanNilWhenNoActivity() {
        let url = tempDir.appendingPathComponent("activity.json")
        let store = ActivityStore(fileURL: url, calendar: calendar)
        XCTAssertNil(store.spanMinutesToday(now: date(2026, 7, 1, hour: 10)))
        XCTAssertNil(store.awayMinutesToday(now: date(2026, 7, 1, hour: 10)))
    }

    func testSpanPersistsAcrossReload() {
        let url = tempDir.appendingPathComponent("activity.json")
        let store = ActivityStore(fileURL: url, calendar: calendar)
        store.credit(at: date(2026, 7, 1, hour: 9, minute: 0))
        store.credit(at: date(2026, 7, 1, hour: 17, minute: 0))
        let reloaded = ActivityStore(fileURL: url, calendar: calendar)
        XCTAssertEqual(reloaded.spanMinutes(on: date(2026, 7, 1, hour: 17)), 480)
    }

    func testAverageSpanIgnoresDaysOff() {
        let url = tempDir.appendingPathComponent("activity.json")
        let store = ActivityStore(fileURL: url, calendar: calendar)
        // Wednesday: 8h span. Tuesday: 10h span. Monday: no activity.
        store.credit(at: date(2026, 7, 1, hour: 9))
        store.credit(at: date(2026, 7, 1, hour: 17))
        store.credit(at: date(2026, 6, 30, hour: 8))
        store.credit(at: date(2026, 6, 30, hour: 18))
        let now = date(2026, 7, 1, hour: 18)
        // (480 + 600) / 2 = 540, the empty Monday excluded.
        XCTAssertEqual(store.averageSpanMinutes(lastDays: 7, now: now), 540)
    }

    func testLegacyDayWithoutTimestampsFallsBackToHourSpan() throws {
        // A DayActivity written before span tracking existed: minutesByHour
        // only, no first/last. Span should estimate from active hours.
        var byHour = Array(repeating: 0, count: 24)
        byHour[9] = 30
        byHour[15] = 20
        let legacy = ["2026-07-01": DayActivity(minutesByHour: byHour)]
        let url = tempDir.appendingPathComponent("activity.json")
        let encoder = JSONEncoder()
        try encoder.encode(legacy).write(to: url)

        let store = ActivityStore(fileURL: url, calendar: calendar)
        // Hours 9→15 → 6 hours estimated span.
        XCTAssertEqual(store.spanMinutes(on: date(2026, 7, 1, hour: 16)), 360)
    }

    func testLegacyActivityJSONStillDecodes() throws {
        // Exact old on-disk shape: a dict of {minutesByHour:[...]} only.
        let json = """
        {"2026-07-01":{"minutesByHour":[0,0,0,0,0,0,0,0,0,60,0,0,0,0,0,0,0,0,0,0,0,0,0,0]}}
        """
        let url = tempDir.appendingPathComponent("activity.json")
        try Data(json.utf8).write(to: url)
        let store = ActivityStore(fileURL: url, calendar: calendar)
        XCTAssertEqual(store.minutes(on: date(2026, 7, 1, hour: 9)), 60)
    }

    // MARK: - HistoryAnalysis

    func testConsecutiveHighFocusCountsFromTheEnd() {
        let now = Date()
        let history = [
            CheckIn(date: now, focus: .scattered, energy: .steady, outcome: .completed),
            CheckIn(date: now, focus: .engaged, energy: .steady, outcome: .completed),
            CheckIn(date: now, focus: .lockedIn, energy: .steady, outcome: .completed),
        ]
        XCTAssertEqual(HistoryAnalysis.consecutiveHighFocus(history: history), 2)
    }

    func testSkippedCheckInEndsHighFocusStreak() {
        let now = Date()
        let history = [
            CheckIn(date: now, focus: .lockedIn, energy: .steady, outcome: .completed),
            CheckIn(date: now, outcome: .skipped),
        ]
        XCTAssertEqual(HistoryAnalysis.consecutiveHighFocus(history: history), 0)
    }

    func testMinutesSinceLastBreakFindsAcceptedBreaks() {
        let now = Date()
        let history = [
            CheckIn(
                date: now.addingTimeInterval(-90 * 60),
                focus: .coasting, energy: .steady,
                outcome: .completed,
                recommendationID: "movement.stairs",
                action: .accepted
            ),
            CheckIn(
                date: now.addingTimeInterval(-45 * 60),
                focus: .engaged, energy: .steady,
                outcome: .completed,
                recommendationID: "keep-going.protect",
                action: .keptWorking
            ),
        ]
        XCTAssertEqual(
            HistoryAnalysis.minutesSinceLastBreak(history: history, now: now),
            90
        )
    }

    func testMinutesSinceLastBreakNilWhenNoBreaks() {
        XCTAssertNil(HistoryAnalysis.minutesSinceLastBreak(history: [], now: Date()))
    }

    func testAverageFocusByHourAggregates() {
        let nineAM = date(2026, 7, 1, hour: 9)
        let history = [
            CheckIn(date: nineAM, focus: .engaged, energy: .steady, outcome: .completed),
            CheckIn(date: nineAM.addingTimeInterval(600), focus: .foggy, energy: .steady, outcome: .completed),
        ]
        let byHour = HistoryAnalysis.averageFocusByHour(history: history, calendar: calendar)
        XCTAssertEqual(byHour[9]?.average ?? 0, 3.0, accuracy: 0.001)  // (4 + 2) / 2
        XCTAssertEqual(byHour[9]?.count, 2)
    }

    func testPeakWindowNeedsEnoughSamples() {
        let nineAM = date(2026, 7, 1, hour: 9)
        let history = [
            CheckIn(date: nineAM, focus: .lockedIn, energy: .steady, outcome: .completed),
            CheckIn(date: nineAM.addingTimeInterval(3600), focus: .lockedIn, energy: .steady, outcome: .completed),
        ]
        XCTAssertNil(
            HistoryAnalysis.peakFocusWindow(history: history, calendar: calendar),
            "two samples must not be enough to declare a pattern"
        )
    }

    func testPeakWindowFindsBestTwoHourStretch() {
        var history: [CheckIn] = []
        let base = date(2026, 7, 1, hour: 0)
        // Strong mornings at 9 and 10, weak afternoons at 14 and 15.
        for day in 0..<3 {
            let dayOffset = Double(day) * 24 * 3600
            history.append(CheckIn(
                date: base.addingTimeInterval(dayOffset + 9 * 3600),
                focus: .lockedIn, energy: .steady, outcome: .completed
            ))
            history.append(CheckIn(
                date: base.addingTimeInterval(dayOffset + 10 * 3600),
                focus: .engaged, energy: .steady, outcome: .completed
            ))
            history.append(CheckIn(
                date: base.addingTimeInterval(dayOffset + 14 * 3600),
                focus: .foggy, energy: .steady, outcome: .completed
            ))
            history.append(CheckIn(
                date: base.addingTimeInterval(dayOffset + 15 * 3600),
                focus: .scattered, energy: .steady, outcome: .completed
            ))
        }
        let peak = HistoryAnalysis.peakFocusWindow(history: history, calendar: calendar)
        XCTAssertEqual(peak?.startHour, 9)
    }

    func testFormatMinutes() {
        XCTAssertEqual(formatMinutes(0), "0m")
        XCTAssertEqual(formatMinutes(45), "45m")
        XCTAssertEqual(formatMinutes(60), "1h 00m")
        XCTAssertEqual(formatMinutes(425), "7h 05m")
    }
}
