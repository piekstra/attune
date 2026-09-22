import SwiftUI

/// Shown when a break timer finishes. The job is a soft landing back into
/// work: re-entry is where task switches fail, so the prompt hands the user
/// the smallest possible first step instead of a blank page.
public struct ReturnPromptView: View {
    public let breakLabel: String
    /// The "note to my future self" left when the break started, if any.
    public let note: String?
    public let onBack: () -> Void
    public let onFiveMore: () -> Void

    public init(
        breakLabel: String,
        note: String? = nil,
        onBack: @escaping () -> Void,
        onFiveMore: @escaping () -> Void
    ) {
        self.breakLabel = breakLabel
        self.note = note
        self.onBack = onBack
        self.onFiveMore = onFiveMore
    }

    private var trimmedNote: String? {
        guard let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(Theme.accent)
                Text("Timer's up")
                    .font(.headline)
                Spacer()
            }
            if let trimmedNote {
                VStack(alignment: .leading, spacing: 6) {
                    Text("You left yourself a note:")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(trimmedNote)
                        .font(.callout.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.accent.opacity(0.12))
                        )
                }
                Text("Welcome back. Read it once, then take the smallest step it points at.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Welcome back. Ease in — re-read the last thing you wrote or did, then take the smallest next step. Thirty seconds of re-reading beats five minutes of \"where was I?\"")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button("Back at it") { onBack() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                Button("5 more minutes") { onFiveMore() }
                    .buttonStyle(.bordered)
                Spacer()
            }
        }
        .padding(18)
        .frame(width: 380)
    }
}
