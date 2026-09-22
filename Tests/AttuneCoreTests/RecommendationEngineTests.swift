import XCTest
@testable import AttuneCore

final class RecommendationEngineTests: XCTestCase {

    private func context(
        focus: FocusLevel,
        energy: EnergyLevel,
        pull: Pull? = nil,
        minutesSinceLastBreak: Int? = 30,
        consecutiveHighFocus: Int = 0,
        hour: Int = 10,
        workEndHour: Int = 18,
        activeMinutesToday: Int? = nil,
        fullDaySpanMinutes: Int? = nil,
        variantSeed: Int = 0
    ) -> RecommendationContext {
        RecommendationContext(
            focus: focus, energy: energy, pull: pull,
            minutesSinceLastBreak: minutesSinceLastBreak,
            consecutiveHighFocus: consecutiveHighFocus,
            hour: hour, workEndHour: workEndHour,
            activeMinutesToday: activeMinutesToday,
            fullDaySpanMinutes: fullDaySpanMinutes,
            variantSeed: variantSeed
        )
    }

    // MARK: - Priority rules

    func testHighFocusGetsProtected() {
        let rec = RecommendationEngine.recommend(
            context(focus: .lockedIn, energy: .steady)
        )
        XCTAssertEqual(rec.kind, .keepGoing)
    }

    func testHyperfocusStreakTriggersBodyCareEvenWhenLockedIn() {
        let rec = RecommendationEngine.recommend(
            context(
                focus: .lockedIn, energy: .steady,
                minutesSinceLastBreak: 150, consecutiveHighFocus: 3
            )
        )
        XCTAssertEqual(rec.kind, .bodyCare)
    }

    func testFullDayBankedWithFadingFocusGetsPermissionToStop() {
        let rec = RecommendationEngine.recommend(
            context(
                focus: .foggy, energy: .depleted,
                hour: 15,  // well before end of day — hours banked still wins
                activeMinutesToday: 450
            )
        )
        XCTAssertEqual(rec.kind, .wrapUp)
        XCTAssertTrue(rec.id.hasPrefix("enough."))
        // The measured figure is substituted into the copy.
        XCTAssertFalse(rec.body.contains("{active}"))
        XCTAssertTrue(rec.title.contains("bank") || rec.body.contains("7h 30m"))
    }

    func testFullDayBankedDoesNotInterruptHighFocus() {
        let rec = RecommendationEngine.recommend(
            context(focus: .lockedIn, energy: .steady, activeMinutesToday: 500)
        )
        XCTAssertEqual(rec.kind, .keepGoing)
    }

    func testLongSpanWithFadingFocusGetsSeparationNudge() {
        // 5h active, but the day spans 11h (early start, appointments) —
        // active hours haven't hit the 7h "banked" bar, so the span rule
        // is what fires.
        let rec = RecommendationEngine.recommend(
            context(
                focus: .coasting, energy: .steady,
                hour: 16,
                activeMinutesToday: 300,
                fullDaySpanMinutes: 660
            )
        )
        XCTAssertEqual(rec.kind, .wrapUp)
        XCTAssertTrue(rec.id.hasPrefix("long-day."))
        // Both measured figures land in the copy, no raw placeholders left.
        XCTAssertFalse(rec.body.contains("{span}"))
        XCTAssertFalse(rec.body.contains("{active}"))
        XCTAssertTrue(rec.body.contains("11h 00m"))
        XCTAssertTrue(rec.body.contains("5h 00m"))
    }

    func testBankedHoursOutrankLongSpanWhenBothTrigger() {
        // A long day that also banked 7h+ active should get the
        // "hours in the bank" message, not the separation one.
        let rec = RecommendationEngine.recommend(
            context(
                focus: .foggy, energy: .depleted,
                hour: 17,
                activeMinutesToday: 450,
                fullDaySpanMinutes: 660
            )
        )
        XCTAssertTrue(rec.id.hasPrefix("enough."))
    }

    func testLongSpanDoesNotInterruptHighFocus() {
        let rec = RecommendationEngine.recommend(
            context(
                focus: .lockedIn, energy: .steady,
                activeMinutesToday: 300, fullDaySpanMinutes: 700
            )
        )
        XCTAssertEqual(rec.kind, .keepGoing)
    }

    func testModerateSpanDoesNotTriggerSeparationNudge() {
        // An 8-hour span with fading focus is normal, not a nudge trigger.
        let rec = RecommendationEngine.recommend(
            context(
                focus: .coasting, energy: .steady,
                hour: 14,
                activeMinutesToday: 300,
                fullDaySpanMinutes: 480
            )
        )
        XCTAssertFalse(rec.id.hasPrefix("long-day."))
    }

    func testLateDayLowFocusWindsDown() {
        let rec = RecommendationEngine.recommend(
            context(focus: .foggy, energy: .depleted, hour: 17, workEndHour: 18)
        )
        XCTAssertEqual(rec.kind, .wrapUp)
    }

    // MARK: - Pull routing

    func testWorryRoutesToWorryTool() {
        let rec = RecommendationEngine.recommend(
            context(focus: .coasting, energy: .steady, pull: .worry)
        )
        XCTAssertEqual(rec.kind, .worryTool)
    }

    func testNotificationsRouteToEnvironmentFix() {
        let rec = RecommendationEngine.recommend(
            context(focus: .scattered, energy: .steady, pull: .notifications)
        )
        XCTAssertEqual(rec.kind, .environmentFix)
    }

    func testBoredomRoutesToSprintGame() {
        let rec = RecommendationEngine.recommend(
            context(focus: .coasting, energy: .steady, pull: .boredom)
        )
        XCTAssertEqual(rec.kind, .sprintGame)
    }

    func testBodyPullRoutesToRestorativeBreak() {
        let rec = RecommendationEngine.recommend(
            context(focus: .coasting, energy: .steady, pull: .body)
        )
        XCTAssertEqual(rec.kind, .restorativeBreak)
    }

    func testLowFocusWithHomePullGetsLegitimizedContextSwitch() {
        let rec = RecommendationEngine.recommend(
            context(focus: .scattered, energy: .steady, pull: .homeStuff)
        )
        XCTAssertEqual(rec.kind, .contextSwitch)
        XCTAssertNotNil(rec.timerMinutes, "context switches always carry a return timer")
    }

    func testMidFocusWithPeoplePullStaysAtWork() {
        let rec = RecommendationEngine.recommend(
            context(focus: .coasting, energy: .steady, pull: .people)
        )
        XCTAssertNotEqual(rec.kind, .contextSwitch)
    }

    // MARK: - Energy routing

    func testWiredEnergyGetsMovement() {
        let rec = RecommendationEngine.recommend(
            context(focus: .coasting, energy: .wired)
        )
        XCTAssertEqual(rec.kind, .movementBreak)
    }

    func testLowFocusDepletedGetsRestorativeBreak() {
        let rec = RecommendationEngine.recommend(
            context(focus: .scattered, energy: .depleted)
        )
        XCTAssertEqual(rec.kind, .restorativeBreak)
    }

    func testLowFocusSteadyOffersTheTrade() {
        let rec = RecommendationEngine.recommend(
            context(focus: .foggy, energy: .steady)
        )
        XCTAssertEqual(rec.kind, .contextSwitch)
    }

    // MARK: - Variants

    func testVariantSeedRotatesCopy() {
        let first = RecommendationEngine.recommend(
            context(focus: .lockedIn, energy: .steady, variantSeed: 0)
        )
        let second = RecommendationEngine.recommend(
            context(focus: .lockedIn, energy: .steady, variantSeed: 1)
        )
        XCTAssertNotEqual(first.id, second.id)
    }

    // MARK: - Catalog integrity

    func testCatalogIDsAreUnique() {
        let ids = Catalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "duplicate catalog IDs")
    }

    func testCatalogCopyIsComplete() {
        for rec in Catalog.all {
            XCTAssertFalse(rec.title.isEmpty, "\(rec.id) missing title")
            XCTAssertFalse(rec.body.isEmpty, "\(rec.id) missing body")
            XCTAssertFalse(rec.whyItWorks.isEmpty, "\(rec.id) missing rationale")
            XCTAssertFalse(rec.researchKeys.isEmpty, "\(rec.id) missing research keys")
            if let minutes = rec.timerMinutes {
                XCTAssertTrue((1...30).contains(minutes), "\(rec.id) timer out of range")
            }
        }
    }

    func testCatalogAvoidsShamingLanguage() {
        // Guardrail on the copy itself: words that grade the person rather
        // than describe the state must not appear in anything shown to users.
        let banned = ["lazy", "failure ", "should have", "wasted", "excuse", "discipline"]
        for rec in Catalog.all {
            let text = (rec.title + " " + rec.body + " " + rec.whyItWorks).lowercased()
            for word in banned {
                XCTAssertFalse(
                    text.contains(word),
                    "\(rec.id) contains shaming language: '\(word)'"
                )
            }
        }
    }

    func testEveryResearchKeyIsDocumented() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let research = try String(
            contentsOf: repoRoot.appendingPathComponent("docs/RESEARCH.md"),
            encoding: .utf8
        )
        for rec in Catalog.all {
            for key in rec.researchKeys {
                XCTAssertTrue(
                    research.contains("`\(key)`"),
                    "\(rec.id) cites '\(key)' but docs/RESEARCH.md has no such entry"
                )
            }
        }
    }

    func testSubstitutionFillsPlaceholder() {
        let rec = Catalog.enoughForToday[0].substituting(active: "7h 05m")
        XCTAssertTrue(rec.body.contains("7h 05m"))
        XCTAssertFalse(rec.body.contains("{active}"))
    }

    func testSpanSubstitutionFillsBothPlaceholders() {
        let rec = Catalog.longDay[0].substituting(active: "5h 00m", span: "11h 00m")
        XCTAssertTrue(rec.body.contains("5h 00m"))
        XCTAssertTrue(rec.body.contains("11h 00m"))
        XCTAssertFalse(rec.body.contains("{span}"))
        XCTAssertFalse(rec.body.contains("{active}"))
    }

    func testEveryCatalogPlaceholderGetsResolvedByEngine() {
        // No recommendation the engine can return should ever reach a user
        // with a raw {placeholder} still in it. Exercise the span/banked
        // paths that carry placeholders and assert they come out clean.
        let spanRec = RecommendationEngine.recommend(
            context(focus: .coasting, energy: .steady, hour: 16,
                    activeMinutesToday: 300, fullDaySpanMinutes: 660)
        )
        let bankedRec = RecommendationEngine.recommend(
            context(focus: .foggy, energy: .depleted, hour: 16,
                    activeMinutesToday: 450)
        )
        for rec in [spanRec, bankedRec] {
            XCTAssertFalse(rec.title.contains("{"), "\(rec.id) title has a raw placeholder")
            XCTAssertFalse(rec.body.contains("{"), "\(rec.id) body has a raw placeholder")
        }
    }
}
