import Foundation

/// Decides what screen context a shortcut run sends next to the selection.
///
/// The Accessibility read comes first. Nearby text replaces the screenshot;
/// a field excerpt alone only complements it. The screenshot is taken only
/// when its own setting is on, so App context never turns it on, and turning
/// it off never affects App context.
enum ContextSourcePolicy {
    /// Why the screenshot is taken or skipped. The raw value is the slug the
    /// Accessibility debug saver records.
    enum ScreenshotReason: String, Equatable {
        /// Accessibility produced nearby text, which replaces the screenshot.
        case nearbyTextAvailable
        case screenshotOff
        /// App context is off, so the screenshot is the only source.
        case accessibilityOff
        /// Accessibility produced only the field excerpt.
        case noNearbyText
        case accessibilityUnusable
    }

    struct Decision: Equatable {
        let accessibilityContext: AccessibilityContext?
        let accessibilityFallbackReason: AccessibilityContext.UnusableReason?
        let screenshotReason: ScreenshotReason

        var takesScreenshot: Bool {
            switch screenshotReason {
            case .nearbyTextAvailable, .screenshotOff:
                return false
            case .accessibilityOff, .noNearbyText, .accessibilityUnusable:
                return true
            }
        }
    }

    /// - Parameter accessibility: nil when App context is off, so nothing was
    ///   read.
    static func decide(
        accessibility: AccessibilityContextResult?,
        screenshotMode: ScreenshotContextMode
    ) -> Decision {
        switch accessibility {
        case nil:
            return Decision(
                accessibilityContext: nil,
                accessibilityFallbackReason: nil,
                screenshotReason: screenshotMode == .off
                    ? .screenshotOff
                    : .accessibilityOff
            )
        case .unusable(let reason, _)?:
            return Decision(
                accessibilityContext: nil,
                accessibilityFallbackReason: reason,
                screenshotReason: screenshotMode == .off
                    ? .screenshotOff
                    : .accessibilityUnusable
            )
        case .usable(let context)?:
            let screenshotReason: ScreenshotReason
            if !context.nearbyText.isEmpty {
                screenshotReason = .nearbyTextAvailable
            } else if screenshotMode == .off {
                screenshotReason = .screenshotOff
            } else {
                screenshotReason = .noNearbyText
            }
            return Decision(
                accessibilityContext: context,
                accessibilityFallbackReason: nil,
                screenshotReason: screenshotReason
            )
        }
    }
}
