import Foundation

/// Everything the engine knows when picking guidance.
public struct RecommendationContext: Sendable {
    public let focus: FocusLevel
    public let energy: EnergyLevel
    public let pull: Pull?
    /// Minutes since the user last accepted any break-type suggestion.
    /// `nil` when no break has been recorded yet.
    public let minutesSinceLastBreak: Int?
    /// How many consecutive recent check-ins reported focus >= engaged.
    public let consecutiveHighFocus: Int
    /// Local hour of day (0–23).
    public let hour: Int
    /// Hour after which check-ins stop (from settings) — used for the
    /// end-of-day wind-down.
    public let workEndHour: Int
    /// Real at-keyboard minutes today from the activity monitor, when
    /// available. Grounds the "you've already done a full day" guidance.
    public let activeMinutesToday: Int?
    /// Full-day span today (first activity → last, breaks included), when
    /// available. Grounds the work/life-separation nudge for long, choppy
    /// days that don't rack up active hours but keep you tethered.
    public let fullDaySpanMinutes: Int?
    /// Rotates variants so repeated scenarios don't repeat copy.
    public let variantSeed: Int

    public init(
        focus: FocusLevel,
        energy: EnergyLevel,
        pull: Pull? = nil,
        minutesSinceLastBreak: Int? = nil,
        consecutiveHighFocus: Int = 0,
        hour: Int = 10,
        workEndHour: Int = 18,
        activeMinutesToday: Int? = nil,
        fullDaySpanMinutes: Int? = nil,
        variantSeed: Int = 0
    ) {
        self.focus = focus
        self.energy = energy
        self.pull = pull
        self.minutesSinceLastBreak = minutesSinceLastBreak
        self.consecutiveHighFocus = consecutiveHighFocus
        self.hour = hour
        self.workEndHour = workEndHour
        self.activeMinutesToday = activeMinutesToday
        self.fullDaySpanMinutes = fullDaySpanMinutes
        self.variantSeed = variantSeed
    }
}

/// Deterministic decision matrix mapping a check-in to guidance.
///
/// Priority order matters and encodes clinical judgment:
/// 1. Body first (hyperfocus guard) — physiology outranks productivity.
/// 2. Protect high focus — the cheapest productivity is not losing it.
/// 3. A banked full day + fading focus earns permission to stop, with the
///    measured hours as evidence against "I didn't do enough".
/// 3b. A long *tether* (10+ hour span, breaks included) + fading focus
///    earns the work/life-separation nudge, even if active hours are lower.
/// 4. End-of-day low focus becomes a wind-down, not another push.
/// 5. Route by the *pull* when one was named — the user told us the problem.
/// 6. Route by energy — restlessness wants movement, depletion wants rest.
public enum RecommendationEngine {

    public static func recommend(_ ctx: RecommendationContext) -> Recommendation {
        // 1. Hyperfocus guard: sustained high focus without body care.
        if ctx.focus >= .engaged,
           SchedulePolicy.hyperfocusGuardTriggered(
            consecutiveHighFocus: ctx.consecutiveHighFocus,
            minutesSinceLastBreak: ctx.minutesSinceLastBreak
           ) {
            return pick(Catalog.bodyCare, ctx)
        }

        // 2. High focus: affirm and get out of the way.
        if ctx.focus >= .engaged {
            return pick(Catalog.keepGoing, ctx)
        }

        // 3. A full day already banked + focus fading: permission to stop,
        //    grounded in the measured hours. Outranks everything below —
        //    no break technique beats being done.
        if let active = ctx.activeMinutesToday,
           active >= SchedulePolicy.fullDayActiveMinutes,
           ctx.focus <= .coasting {
            return pick(Catalog.enoughForToday, ctx)
                .substituting(active: formatMinutes(active))
        }

        // 3b. A long tether — first activity to last spans 10+ hours,
        //     breaks and time away included — with focus fading: the
        //     work/life-separation nudge. Fires even when active hours are
        //     lower, because a fragmented long day is its own kind of tired.
        if let span = ctx.fullDaySpanMinutes,
           let active = ctx.activeMinutesToday,
           span >= SchedulePolicy.longWorkDaySpanMinutes,
           ctx.focus <= .coasting {
            return pick(Catalog.longDay, ctx)
                .substituting(active: formatMinutes(active), span: formatMinutes(span))
        }

        // 4. End-of-day low focus: land the plane instead of pushing.
        if ctx.focus <= .foggy, ctx.hour >= ctx.workEndHour - 1 {
            return pick(Catalog.wrapUp, ctx)
        }

        // 5. A named pull routes directly.
        if let pull = ctx.pull {
            switch pull {
            case .worry:
                return pick(Catalog.worryTool, ctx)
            case .notifications:
                return pick(Catalog.environmentFix, ctx)
            case .boredom:
                return pick(Catalog.sprintGame, ctx)
            case .body:
                return pick(Catalog.restorativeBreak, ctx)
            case .people, .homeStuff:
                // Mid focus can usually push through with a micro-break;
                // low focus + life pulling = the legitimized switch.
                if ctx.focus <= .foggy {
                    return pick(Catalog.contextSwitch, ctx)
                }
            case .nothing:
                break
            }
        }

        // 6. Route by energy.
        switch (ctx.focus, ctx.energy) {
        case (.coasting, .wired):
            return pick(Catalog.movementBreak, ctx)
        case (.coasting, .depleted):
            return pick(Catalog.microBreak, ctx)
        case (.coasting, .steady):
            return pick(Catalog.microBreak, ctx)
        case (_, .depleted):
            return pick(Catalog.restorativeBreak, ctx)
        case (_, .wired):
            return pick(Catalog.movementBreak, ctx)
        case (_, .steady):
            // Low focus, steady body, no named pull: offer the trade.
            return pick(Catalog.contextSwitch, ctx)
        }
    }

    private static func pick(
        _ variants: [Recommendation],
        _ ctx: RecommendationContext
    ) -> Recommendation {
        precondition(!variants.isEmpty, "catalog scenario must have variants")
        let index = abs(ctx.variantSeed) % variants.count
        return variants[index]
    }
}
