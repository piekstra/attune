import Foundation

/// How focused the user reports feeling, on a 5-point scale.
///
/// The labels deliberately describe *states*, not grades. "Scattered" is
/// information about the brain's current mode, not a failure. This framing
/// matters for ADHD users, for whom self-report tools easily become
/// self-criticism tools (see docs/DESIGN.md, "Shame-free by design").
public enum FocusLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case scattered = 1
    case foggy = 2
    case coasting = 3
    case engaged = 4
    case lockedIn = 5

    public var label: String {
        switch self {
        case .scattered: return "Scattered"
        case .foggy: return "Foggy"
        case .coasting: return "Coasting"
        case .engaged: return "Engaged"
        case .lockedIn: return "Locked in"
        }
    }

    public var emoji: String {
        switch self {
        case .scattered: return "🌪️"
        case .foggy: return "🌫️"
        case .coasting: return "🚲"
        case .engaged: return "🎯"
        case .lockedIn: return "🔒"
        }
    }

    public static func < (lhs: FocusLevel, rhs: FocusLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A quick body-state read. ADHD adults measurably under-detect internal
/// body signals (interoception), so the check-in asks directly rather than
/// assuming people notice on their own.
public enum EnergyLevel: String, Codable, CaseIterable, Sendable {
    case depleted
    case steady
    case wired

    public var label: String {
        switch self {
        case .depleted: return "Running on empty"
        case .steady: return "Steady"
        case .wired: return "Wired / restless"
        }
    }

    public var emoji: String {
        switch self {
        case .depleted: return "🪫"
        case .steady: return "🔋"
        case .wired: return "⚡"
        }
    }
}

/// What, if anything, is pulling attention away right now. Optional —
/// naming the pull often matters more than the answer itself.
public enum Pull: String, Codable, CaseIterable, Sendable {
    case nothing
    case notifications
    case people
    case boredom
    case worry
    case body
    case homeStuff

    public var label: String {
        switch self {
        case .nothing: return "Nothing much"
        case .notifications: return "Notifications & pings"
        case .people: return "People & kids"
        case .boredom: return "Boredom"
        case .worry: return "Worry / racing thoughts"
        case .body: return "Hunger or tiredness"
        case .homeStuff: return "Home stuff on my mind"
        }
    }
}

/// What happened when a check-in was offered.
public enum CheckInOutcome: String, Codable, Sendable {
    /// User answered the questions.
    case completed
    /// User clicked "not now".
    case skipped
    /// Panel timed out with no interaction. Recorded without judgment.
    case missed
    /// A meeting was in progress, so the check-in never appeared.
    case deferredForMeeting
}

/// What the user did with the recommendation they were shown.
public enum RecommendationAction: String, Codable, Sendable {
    /// Chose to act on the suggestion (took the break, made the switch, ...).
    case accepted
    /// Chose to keep working — always a legitimate answer.
    case keptWorking
    /// Asked to be re-asked later.
    case snoozed
}

/// One check-in record. Everything Attune knows lives in these,
/// stored locally on the user's machine and nowhere else.
public struct CheckIn: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let focus: FocusLevel?
    public let energy: EnergyLevel?
    public let pull: Pull?
    public let outcome: CheckInOutcome
    public let recommendationID: String?
    public let action: RecommendationAction?

    public init(
        id: UUID = UUID(),
        date: Date,
        focus: FocusLevel? = nil,
        energy: EnergyLevel? = nil,
        pull: Pull? = nil,
        outcome: CheckInOutcome,
        recommendationID: String? = nil,
        action: RecommendationAction? = nil
    ) {
        self.id = id
        self.date = date
        self.focus = focus
        self.energy = energy
        self.pull = pull
        self.outcome = outcome
        self.recommendationID = recommendationID
        self.action = action
    }
}
