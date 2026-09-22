import SwiftUI

/// What a finished check-in hands back to the app.
public struct CheckInResult {
    public let focus: FocusLevel
    public let energy: EnergyLevel
    public let pull: Pull?
    public let recommendation: Recommendation
    public let action: RecommendationAction

    public init(
        focus: FocusLevel, energy: EnergyLevel, pull: Pull?,
        recommendation: Recommendation, action: RecommendationAction
    ) {
        self.focus = focus
        self.energy = energy
        self.pull = pull
        self.recommendation = recommendation
        self.action = action
    }
}

/// The check-in itself: two quick questions, one optional, then guidance.
/// Designed to be answerable in under ten seconds with single clicks —
/// the act of answering *is* the intervention (metacognitive pause), so
/// nothing here may feel like a form.
public struct CheckInView: View {
    public let makeRecommendation: (FocusLevel, EnergyLevel, Pull?) -> Recommendation
    public let onComplete: (CheckInResult) -> Void
    public let onSkip: () -> Void
    /// Invoked when the user accepts a suggestion that carries a timer.
    /// The string is the optional "note to my future self" typed on the
    /// guidance card.
    public let onStartTimer: (Recommendation, String?) -> Void

    private enum Step {
        case focus
        case energy
        case pull
        case guidance(Recommendation)
    }

    @State private var step: Step = .focus
    @State private var focus: FocusLevel?
    @State private var energy: EnergyLevel?

    public init(
        makeRecommendation: @escaping (FocusLevel, EnergyLevel, Pull?) -> Recommendation,
        onComplete: @escaping (CheckInResult) -> Void,
        onSkip: @escaping () -> Void,
        onStartTimer: @escaping (Recommendation, String?) -> Void
    ) {
        self.makeRecommendation = makeRecommendation
        self.onComplete = onComplete
        self.onSkip = onSkip
        self.onStartTimer = onStartTimer
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            switch step {
            case .focus:
                question("Where's your head right now?") {
                    HStack(spacing: 6) {
                        ForEach(FocusLevel.allCases, id: \.rawValue) { level in
                            ChoiceButton(emoji: level.emoji, label: level.label) {
                                focus = level
                                withAnimation(.easeOut(duration: 0.15)) { step = .energy }
                            }
                        }
                    }
                }
            case .energy:
                question("And your body?") {
                    HStack(spacing: 6) {
                        ForEach(EnergyLevel.allCases, id: \.rawValue) { level in
                            ChoiceButton(emoji: level.emoji, label: level.label) {
                                energy = level
                                withAnimation(.easeOut(duration: 0.15)) { step = .pull }
                            }
                        }
                    }
                }
            case .pull:
                question("Anything pulling at you?") {
                    pullGrid
                }
            case .guidance(let recommendation):
                GuidanceCard(
                    recommendation: recommendation,
                    onAction: { action, note in
                        finish(recommendation: recommendation, action: action, note: note)
                    }
                )
            }
        }
        .padding(18)
        .frame(width: 380)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(Theme.accent)
            Text(headerTitle)
                .font(.headline)
            Spacer()
            if !isGuidance {
                Button("Not now") { onSkip() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Skips this check-in. No penalty, ever.")
            }
        }
    }

    private var isGuidance: Bool {
        if case .guidance = step { return true }
        return false
    }

    private var headerTitle: String {
        isGuidance ? "A thought" : "Focus check"
    }

    private func question(
        _ text: String,
        @ViewBuilder choices: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.title3.weight(.medium))
            choices()
            Text("One click. No wrong answers.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var pullGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(Pull.allCases, id: \.rawValue) { pull in
                    ChipButton(label: pull.label) {
                        advance(pull: pull)
                    }
                }
            }
            Button("Skip this one") { advance(pull: nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func advance(pull: Pull?) {
        guard let focus, let energy else { return }
        let recommendation = makeRecommendation(focus, energy, pull)
        withAnimation(.easeOut(duration: 0.15)) {
            step = .guidance(recommendation)
        }
        self.chosenPull = pull
    }

    @State private var chosenPull: Pull?

    private func finish(
        recommendation: Recommendation,
        action: RecommendationAction,
        note: String?
    ) {
        guard let focus, let energy else { return }
        if action == .accepted, recommendation.timerMinutes != nil {
            onStartTimer(recommendation, note)
        }
        onComplete(
            CheckInResult(
                focus: focus, energy: energy, pull: chosenPull,
                recommendation: recommendation, action: action
            )
        )
    }
}

// MARK: - Guidance card

struct GuidanceCard: View {
    let recommendation: Recommendation
    let onAction: (RecommendationAction, String?) -> Void

    @State private var showWhy = false
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recommendation.title)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(recommendation.body)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DisclosureGroup(isExpanded: $showWhy) {
                Text(recommendation.whyItWorks)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            } label: {
                Text("Why this works")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }

            if recommendation.timerMinutes != nil {
                VStack(alignment: .leading, spacing: 3) {
                    TextField(
                        "",
                        text: $note,
                        prompt: Text("Note to your future self — where are you leaving off?")
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .onSubmit { onAction(.accepted, note) }
                    Text("Optional. Shown when the timer rings — and on your iPhone reminder, if that's on.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 2)
            }

            HStack(spacing: 8) {
                if let minutes = recommendation.timerMinutes {
                    Button("Start \(minutes)-min timer") {
                        onAction(.accepted, note)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                } else {
                    Button("On it") { onAction(.accepted, nil) }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                }
                Button("Keep working") { onAction(.keptWorking, nil) }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Ask me in 15") { onAction(.snoozed, nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
    }
}

// MARK: - Buttons

/// Emoji-over-label button used for the focus and energy scales.
struct ChoiceButton: View {
    let emoji: String
    let label: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emoji).font(.title2)
                Text(label)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(hovering ? Color.primary.opacity(0.08) : Color.primary.opacity(0.03))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Compact text chip used for the optional "pull" question.
struct ChipButton: View {
    let label: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(hovering ? Color.primary.opacity(0.08) : Color.primary.opacity(0.03))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
