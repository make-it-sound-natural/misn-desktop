import Cocoa

/// Colors for the status bubble, mirrored from the Dart palette.
///
/// The bubble is drawn by AppKit, so it cannot read `AppColors`. Keeping the
/// hex strings here — spelled the same way as in `lib/theme/app_theme.dart` —
/// makes the pairing greppable from one place. Unnamed RGB triples at the call
/// site hid the fact that `textSecondary` had moved from `#667085` to
/// `#5B6478`, leaving the spinner on the old value.
enum BubbleColors {

    /// `AppColors.surface` at the bubble's translucency.
    static let backgroundLight = hex(0xF5F5F5, alpha: 0.95)

    /// `AppColors.darkSurface` lightened for a floating panel.
    static let backgroundDark = hex(0x333333, alpha: 0.95)

    /// `AppColors.border`.
    static let trackLight = hex(0xE0E0E0)

    /// `AppColors.darkBorder`.
    static let trackDark = hex(0x3A3A3C)

    /// `AppColors.textSecondary`.
    static let arcLight = hex(0x5B6478)

    /// `AppColors.darkTextSecondary`.
    static let arcDark = hex(0xC7C7CC)

    private static func hex(_ value: Int, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha
        )
    }
}
