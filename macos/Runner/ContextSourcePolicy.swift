import Foundation

/// Decides what screen context a shortcut run sends next to the selection.
///
/// App context and the screenshot are independent: a usable Accessibility
/// read is always sent, and the screenshot is taken whenever its own setting
/// is on, next to App context or in place of an unusable read. An unusable
/// read that still reached the right field sends what it has: app, window,
/// field label and nearby text.
enum ContextSourcePolicy {
    /// Why the screenshot is taken or skipped. The raw value is the slug the
    /// Accessibility debug saver records.
    enum ScreenshotReason: String, Equatable {
        case screenshotOff
        /// App context is off, so the screenshot is the only source.
        case accessibilityOff
        /// Sent next to App context.
        case accessibilityUsable
        case accessibilityUnusable
    }

    struct Decision: Equatable {
        let accessibilityContext: AccessibilityContext?
        let accessibilityFallbackReason: AccessibilityContext.UnusableReason?
        let screenshotReason: ScreenshotReason

        var takesScreenshot: Bool {
            screenshotReason != .screenshotOff
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
        case .unusable(let reason, let partial)?:
            return Decision(
                accessibilityContext: reason.keepsPartialContext
                    ? partial
                    : nil,
                accessibilityFallbackReason: reason,
                screenshotReason: screenshotMode == .off
                    ? .screenshotOff
                    : .accessibilityUnusable
            )
        case .usable(let context)?:
            return Decision(
                accessibilityContext: context,
                accessibilityFallbackReason: nil,
                screenshotReason: screenshotMode == .off
                    ? .screenshotOff
                    : .accessibilityUsable
            )
        }
    }
}
