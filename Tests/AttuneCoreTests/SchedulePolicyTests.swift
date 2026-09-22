import XCTest
@testable import AttuneCore

final class SchedulePolicyTests: XCTestCase {
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

    // MARK: - Adaptive intervals

    func testBaselineIntervalWhenNoFocusReported() {
        let settings = UserSettings(baseIntervalMinutes: 45)
        XCTAssertEqual(
            SchedulePolicy.nextInterval(afterFocus: nil, settings: settings),
            45 * 60
        )
    }

    func testHighFocusStretchesInterval() {
        let settings = UserSettings(baseIntervalMinutes: 45)
        let interval = SchedulePolicy.nextInterval(afterFocus: .lockedIn, settings: settings)
        XCTAssertEqual(interval, 45 * 1.6 * 60, accuracy: 1)
    }

    func testLowFocusTightensInterval() {
        let settings = UserSettings(baseIntervalMinutes: 45)
        let interval = SchedulePolicy.nextInterval(afterFocus: .scattered, settings: settings)
        XCTAssertEqual(interval, 45 * 0.6 * 60, accuracy: 1)
    }

    func testIntervalNeverExceedsNinetyMinutes() {
        let settings = UserSettings(baseIntervalMinutes: 90)
        let interval = SchedulePolicy.nextInterval(afterFocus: .lockedIn, settings: settings)
        XCTAssertEqual(interval, 90 * 60)
    }

    func testIntervalNeverDropsBelowTwentyFiveMinutes() {
        let settings = UserSettings(baseIntervalMinutes: 25)
        let interval = SchedulePolicy.nextInterval(afterFocus: .scattered, settings: settings)
        XCTAssertEqual(interval, 25 * 60)
    }

    func testAdaptiveCadenceOffUsesBaseline() {
        let settings = UserSettings(baseIntervalMinutes: 45, adaptiveCadence: false)
        XCTAssertEqual(
            SchedulePolicy.nextInterval(afterFocus: .lockedIn, settings: settings),
            45 * 60
        )
    }

    // MARK: - Work hours

    func testMidMorningWeekdayIsWithinWorkHours() {
        // Wednesday July 1, 2026, 10 AM.
        let wednesday = date(2026, 7, 1, hour: 10)
        XCTAssertTrue(SchedulePolicy.isWithinWorkHours(
            wednesday, settings: .default, calendar: calendar
        ))
    }

    func testEveningIsOutsideWorkHours() {
        let evening = date(2026, 7, 1, hour: 19)
        XCTAssertFalse(SchedulePolicy.isWithinWorkHours(
            evening, settings: .default, calendar: calendar
        ))
    }

    func testSaturdayIsOutsideDefaultWorkDays() {
        let saturday = date(2026, 7, 4, hour: 10)
        XCTAssertFalse(SchedulePolicy.isWithinWorkHours(
            saturday, settings: .default, calendar: calendar
        ))
    }

    func testNextAllowedDateInsideWorkHoursIsIdentity() {
        let wednesday = date(2026, 7, 1, hour: 10)
        XCTAssertEqual(
            SchedulePolicy.nextAllowedDate(
                from: wednesday, settings: .default, calendar: calendar
            ),
            wednesday
        )
    }

    func testEveningRollsToNextMorning() {
        let wednesdayEvening = date(2026, 7, 1, hour: 20)
        let expected = date(2026, 7, 2, hour: 8)  // Thursday 8 AM
        XCTAssertEqual(
            SchedulePolicy.nextAllowedDate(
                from: wednesdayEvening, settings: .default, calendar: calendar
            ),
            expected
        )
    }

    func testFridayEveningRollsToMondayMorning() {
        let fridayEvening = date(2026, 7, 3, hour: 20)
        let expected = date(2026, 7, 6, hour: 8)  // Monday 8 AM
        XCTAssertEqual(
            SchedulePolicy.nextAllowedDate(
                from: fridayEvening, settings: .default, calendar: calendar
            ),
            expected
        )
    }

    func testEarlyMorningRollsForwardToSameDayStart() {
        let wednesdayEarly = date(2026, 7, 1, hour: 6)
        let expected = date(2026, 7, 1, hour: 8)
        XCTAssertEqual(
            SchedulePolicy.nextAllowedDate(
                from: wednesdayEarly, settings: .default, calendar: calendar
            ),
            expected
        )
    }

    // MARK: - Hyperfocus guard

    func testHyperfocusGuardRequiresStreak() {
        XCTAssertFalse(SchedulePolicy.hyperfocusGuardTriggered(
            consecutiveHighFocus: 1, minutesSinceLastBreak: 300
        ))
    }

    func testHyperfocusGuardRequiresLongStretchWithoutBreak() {
        XCTAssertFalse(SchedulePolicy.hyperfocusGuardTriggered(
            consecutiveHighFocus: 3, minutesSinceLastBreak: 30
        ))
        XCTAssertTrue(SchedulePolicy.hyperfocusGuardTriggered(
            consecutiveHighFocus: 3, minutesSinceLastBreak: 120
        ))
    }

    func testHyperfocusGuardTriggersWhenNoBreakEverRecorded() {
        XCTAssertTrue(SchedulePolicy.hyperfocusGuardTriggered(
            consecutiveHighFocus: 2, minutesSinceLastBreak: nil
        ))
    }
}
