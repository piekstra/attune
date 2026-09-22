import SwiftUI

/// Personal patterns from the last two weeks of check-ins. The headline
/// insight is *when this particular brain focuses best* — ADHD chronotypes
/// vary widely (delayed rhythms are common), so Attune learns the pattern
/// from the user's own data instead of assuming a schedule.
///
/// Deliberately absent: streaks, scores, grades, comparisons. The stats
/// here count moments of noticing and acting — things the user did for
/// themselves, not compliance metrics.
public struct InsightsView: View {
    /// Real at-keyboard time plus the full-day bracket, from the activity
    /// monitor. `todayMinutes`/`weekMinutes` are *active* minutes; the span
    /// fields are the wider first-activity-to-last bracket.
    public struct ActivitySummary {
        public let todayMinutes: Int
        public let weekMinutes: Int
        public let todaySpanMinutes: Int?
        public let todayAwayMinutes: Int?
        public let todayFirstActivity: Date?
        public let todayLastActivity: Date?
        public let weekAverageSpanMinutes: Int?

        public init(
            todayMinutes: Int,
            weekMinutes: Int,
            todaySpanMinutes: Int? = nil,
            todayAwayMinutes: Int? = nil,
            todayFirstActivity: Date? = nil,
            todayLastActivity: Date? = nil,
            weekAverageSpanMinutes: Int? = nil
        ) {
            self.todayMinutes = todayMinutes
            self.weekMinutes = weekMinutes
            self.todaySpanMinutes = todaySpanMinutes
            self.todayAwayMinutes = todayAwayMinutes
            self.todayFirstActivity = todayFirstActivity
            self.todayLastActivity = todayLastActivity
            self.weekAverageSpanMinutes = weekAverageSpanMinutes
        }
    }

    /// Check-ins from the window being summarized (most recent last).
    public let history: [CheckIn]
    public let activity: ActivitySummary?
    public let calendar: Calendar

    public init(
        history: [CheckIn],
        activity: ActivitySummary? = nil,
        calendar: Calendar = .current
    ) {
        self.history = history
        self.activity = activity
        self.calendar = calendar
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your last two weeks")
                .font(.title2.weight(.semibold))

            if let activity {
                hoursTiles(activity)
            }
            statTiles

            if hasChartData {
                FocusByHourChart(
                    byHour: HistoryAnalysis.averageFocusByHour(
                        history: history, calendar: calendar
                    )
                )
            } else {
                emptyState
            }

            Spacer(minLength: 0)

            Text("Everything on this page lives only on this Mac.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 600, height: 640)
    }

    private var hasChartData: Bool {
        history.contains { $0.outcome == .completed && $0.focus != nil }
    }

    /// The anti-anxiety row: hours that actually happened, counted from
    /// keyboard/mouse presence. On scattered days the felt answer to
    /// "did I work enough?" skews hard toward no; this is the measured one.
    /// The span/away tiles add the other half of the balance question — how
    /// long work was in the picture, not just how much got done.
    private func hoursTiles(_ activity: ActivitySummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                StatTile(
                    value: formatMinutes(activity.todayMinutes),
                    label: "active today",
                    detail: "real hours at the keyboard"
                )
                StatTile(
                    value: activity.todaySpanMinutes.map(formatMinutes) ?? "—",
                    label: "work-day span",
                    detail: bracketDetail(activity)
                )
                StatTile(
                    value: activity.todayAwayMinutes.map(formatMinutes) ?? "—",
                    label: "away in between",
                    detail: "unprompted breaks & time out"
                )
            }
            separationNote(activity)
        }
    }

    /// "6:05 AM → 4:12 PM" when the day's bracket is known.
    private func bracketDetail(_ activity: ActivitySummary) -> String {
        if let first = activity.todayFirstActivity,
           let last = activity.todayLastActivity {
            return "\(formatClockTime(first)) → \(formatClockTime(last))"
        }
        return "first activity → last"
    }

    /// A single gentle caption about work/life separation. Long brackets get
    /// named (that's the whole point of the feature); otherwise it stays
    /// neutral and adds the 7-day typical span for context.
    @ViewBuilder
    private func separationNote(_ activity: ActivitySummary) -> some View {
        if let span = activity.todaySpanMinutes,
           span >= SchedulePolicy.longWorkDaySpanMinutes {
            Text("Work has been in the picture for \(formatMinutes(span)) today — a wide bracket. A clean evening isn't a reward to earn; it's what makes tomorrow work.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if let weekAvg = activity.weekAverageSpanMinutes {
            Text("Last 7 days: \(formatMinutes(activity.weekMinutes)) active. A typical work day spans about \(formatMinutes(weekAvg)) from first to last.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("Last 7 days: \(formatMinutes(activity.weekMinutes)) active. Presence only — Attune never sees what you do.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statTiles: some View {
        let wins = HistoryAnalysis.wins(history: history)
        let peak = HistoryAnalysis.peakFocusWindow(history: history, calendar: calendar)
        return HStack(spacing: 12) {
            StatTile(
                value: "\(wins.checkIns)",
                label: "moments of noticing",
                detail: "check-ins you answered"
            )
            StatTile(
                value: "\(wins.actedOn)",
                label: "times you acted",
                detail: "suggestions you ran with"
            )
            StatTile(
                value: peak.map { peakWindowText(startHour: $0.startHour) } ?? "—",
                label: "sharpest window",
                detail: peak != nil
                    ? "guard it for deep work"
                    : "keeps building as you check in"
            )
        }
    }

    private func peakWindowText(startHour: Int) -> String {
        "\(hourLabel(startHour))–\(hourLabel(startHour + 2))"
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.title)
                .foregroundStyle(.tertiary)
            Text("No patterns yet — that's expected.")
                .font(.headline)
            Text("After a few days of check-ins, this page starts showing when your focus runs strongest, from your own data.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

/// Hour label like "9 AM".
func hourLabel(_ hour: Int) -> String {
    let h = ((hour % 24) + 24) % 24
    switch h {
    case 0: return "12 AM"
    case 1...11: return "\(h) AM"
    case 12: return "12 PM"
    default: return "\(h - 12) PM"
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let value: String
    let label: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title.weight(.semibold))
            Text(label)
                .font(.caption.weight(.medium))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

// MARK: - Chart

/// Single-series bar chart: average reported focus (1–5) per hour of day.
/// Mark and color choices follow the data-viz pass: one validated hue,
/// thin bars with rounded data-ends anchored to the baseline, 2pt gaps,
/// hairline gridlines, muted axis text, a direct label on the peak bar
/// only, and a hover tooltip carrying the exact values.
struct FocusByHourChart: View {
    let byHour: [Int: (average: Double, count: Int)]

    @State private var hoveredHour: Int?

    private let plotHeight: CGFloat = 180
    /// Hours shown: 6 AM through 9 PM covers flexible work schedules.
    private let hours = Array(6...21)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Average focus by hour of day")
                    .font(.headline)
                Spacer()
                Text(tooltipText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .opacity(hoveredHour == nil ? 0 : 1)
            }

            HStack(alignment: .top, spacing: 8) {
                yAxisLabels
                plot
            }

            xAxisLabels
        }
    }

    private var tooltipText: String {
        guard let hour = hoveredHour, let entry = byHour[hour] else { return " " }
        let avg = String(format: "%.1f", entry.average)
        let unit = entry.count == 1 ? "check-in" : "check-ins"
        return "\(hourLabel(hour)) · avg \(avg) · \(entry.count) \(unit)"
    }

    private var peakHour: Int? {
        byHour.max { $0.value.average < $1.value.average }?.key
    }

    private var yAxisLabels: some View {
        VStack(spacing: 0) {
            ForEach([5, 4, 3, 2, 1], id: \.self) { level in
                Text("\(level)")
                    .font(.caption2)
                    .foregroundStyle(Theme.axisLabel)
                    .frame(height: plotHeight / 5, alignment: .top)
            }
        }
        .frame(width: 12)
    }

    private var plot: some View {
        ZStack(alignment: .bottom) {
            // Hairline gridlines at each focus level.
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { _ in
                    Rectangle()
                        .fill(Theme.gridline)
                        .frame(height: 1)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: plotHeight)

            // Bars.
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(hours, id: \.self) { hour in
                    bar(for: hour)
                }
            }
            .frame(height: plotHeight)

            // Baseline.
            Rectangle()
                .fill(Theme.baseline)
                .frame(height: 1)
        }
    }

    private func bar(for hour: Int) -> some View {
        let entry = byHour[hour]
        let height = entry.map { CGFloat($0.average / 5.0) * plotHeight } ?? 0
        let isPeak = hour == peakHour
        let isHovered = hour == hoveredHour

        return VStack(spacing: 2) {
            if isPeak, let entry {
                Text(String(format: "%.1f", entry.average))
                    .font(.caption2.weight(.semibold))
            }
            UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 4
            )
            .fill(Theme.chartBar)
            .opacity(entry == nil ? 0 : (isHovered ? 1.0 : 0.85))
            .frame(height: max(height, entry == nil ? 0 : 2))
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
        .contentShape(Rectangle())
        .onHover { inside in
            hoveredHour = inside ? hour : (hoveredHour == hour ? nil : hoveredHour)
        }
        .help(entry == nil ? "No check-ins at \(hourLabel(hour))" : tooltipHelp(hour: hour))
    }

    private func tooltipHelp(hour: Int) -> String {
        guard let entry = byHour[hour] else { return "" }
        return "\(hourLabel(hour)): average focus \(String(format: "%.1f", entry.average)) across \(entry.count) check-in(s)"
    }

    private var xAxisLabels: some View {
        HStack(spacing: 2) {
            Color.clear.frame(width: 20, height: 1)  // y-axis gutter
            ForEach(hours, id: \.self) { hour in
                Text(hour % 3 == 0 ? shortHourLabel(hour) : "")
                    .font(.caption2)
                    .foregroundStyle(Theme.axisLabel)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func shortHourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12a"
        case 1...11: return "\(hour)a"
        case 12: return "12p"
        default: return "\(hour - 12)p"
        }
    }
}
