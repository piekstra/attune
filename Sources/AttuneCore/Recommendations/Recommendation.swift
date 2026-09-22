import Foundation

/// A single piece of guidance shown after a check-in.
public struct Recommendation: Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// Affirm and protect what's working.
        case keepGoing
        /// Hydrate, eat, stretch — tending the body during long focus.
        case bodyCare
        /// 2–5 minutes away from the screen.
        case microBreak
        /// Get the heart rate up briefly.
        case movementBreak
        /// A longer, genuinely restorative reset.
        case restorativeBreak
        /// The signature move: redirect this stretch of time to home life,
        /// on purpose, with a planned return.
        case contextSwitch
        /// Change the environment instead of the brain.
        case environmentFix
        /// Park the worry so it stops competing for working memory.
        case worryTool
        /// Reshape a boring task so it can hold attention.
        case sprintGame
        /// End-of-day landing: close loops, stage tomorrow.
        case wrapUp
    }

    /// Stable catalog identifier (e.g. "context-switch.laundry"). Stored in
    /// history so patterns like "which suggestions actually get accepted"
    /// stay analyzable across versions.
    public let id: String
    public let kind: Kind
    public let title: String
    public let body: String
    /// One or two sentences of honest rationale. Shown behind a "why this
    /// works" disclosure — ADHD users deserve reasons, not commands.
    public let whyItWorks: String
    /// When set, the UI offers a one-click countdown for this many minutes,
    /// with a gentle return prompt at the end.
    public let timerMinutes: Int?
    /// Keys into docs/RESEARCH.md for the curious.
    public let researchKeys: [String]

    public init(
        id: String,
        kind: Kind,
        title: String,
        body: String,
        whyItWorks: String,
        timerMinutes: Int? = nil,
        researchKeys: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.whyItWorks = whyItWorks
        self.timerMinutes = timerMinutes
        self.researchKeys = researchKeys
    }

    /// Fill measured-time placeholders in copy that cites the activity
    /// counter: "{active}" with real at-keyboard hours, "{span}" with the
    /// full-day bracket (e.g. "10h 30m"). Only the placeholders whose value
    /// is provided are replaced.
    public func substituting(active: String? = nil, span: String? = nil) -> Recommendation {
        var newTitle = title
        var newBody = body
        if let active {
            newTitle = newTitle.replacingOccurrences(of: "{active}", with: active)
            newBody = newBody.replacingOccurrences(of: "{active}", with: active)
        }
        if let span {
            newTitle = newTitle.replacingOccurrences(of: "{span}", with: span)
            newBody = newBody.replacingOccurrences(of: "{span}", with: span)
        }
        return Recommendation(
            id: id,
            kind: kind,
            title: newTitle,
            body: newBody,
            whyItWorks: whyItWorks,
            timerMinutes: timerMinutes,
            researchKeys: researchKeys
        )
    }
}
