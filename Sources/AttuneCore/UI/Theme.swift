import AppKit
import SwiftUI

/// Adaptive colors for the app's small amount of custom chrome and the
/// insights chart. Chart hues are the validated reference palette from the
/// design pass (blue slot: #2a78d6 light / #3987e5 dark — both clear 3:1
/// against their surfaces); everything else defers to system semantics so
/// the app looks native in both appearances.
public enum Theme {
    /// Single-series chart hue (average-focus bars).
    public static let chartBar = dynamic(light: "#2a78d6", dark: "#3987e5")
    /// Hairline gridlines behind the chart.
    public static let gridline = dynamic(light: "#e1e0d9", dark: "#2c2c2a")
    /// Axis baseline.
    public static let baseline = dynamic(light: "#c3c2b7", dark: "#383835")
    /// Muted axis labels (works on both surfaces).
    public static let axisLabel = Color(nsColor: .secondaryLabelColor)

    /// Warm accent for the check-in panel's primary action.
    public static let accent = dynamic(light: "#2a78d6", dark: "#3987e5")

    private static func dynamic(light: String, dark: String) -> Color {
        let l = NSColor(hex: light)
        let d = NSColor(hex: dark)
        let dynamicColor = NSColor(
            name: nil,
            dynamicProvider: { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? d : l
            }
        )
        return Color(nsColor: dynamicColor)
    }
}

extension NSColor {
    /// Hex like "#2a78d6". Fails loudly in debug; falls back to gray in release.
    convenience init(hex: String) {
        var value: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let ok = Scanner(string: cleaned).scanHexInt64(&value) && cleaned.count == 6
        assert(ok, "bad hex color: \(hex)")
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
