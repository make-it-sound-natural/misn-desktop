import AppKit
import os.log

/// Where a screenshot would be taken, recorded when the shortcut fired.
struct ScreenshotTarget {
    let bundleId: String?
    let windowID: CGWindowID?
    let cursorLocation: NSPoint?
}

/// The screen context a shortcut run sends next to the selected text.
struct CollectedContext {
    let accessibilityContext: AccessibilityContext?
    let accessibilityFallbackReason: AccessibilityContext.UnusableReason?
    let screenshot: ScreenshotCaptureResult
}

/// Runs the Accessibility read and the screenshot for a shortcut run and
/// applies `ContextSourcePolicy` to them.
final class ContextSourceCollector {
    private let accessibilityCapturer: AccessibilityContextCapturing
    private let screenshotCapturer: ScreenshotCapturing
    private let accessibilityDebugSaver: AccessibilityContextDebugSaver
    private let screenshotDebugSaver: ScreenshotDebugSaver
    private let captureDeadline: TimeInterval
    /// Serial, so a hung app cannot pile up reads from repeated shortcuts.
    private let accessibilityQueue = DispatchQueue(
        label: "com.makeitsoundnatural.accessibility-context",
        qos: .userInitiated
    )

    private let logger = OSLog(
        subsystem: "com.makeitsoundnatural.macos",
        category: "ContextSource"
    )

    init(
        accessibilityCapturer: AccessibilityContextCapturing =
            AccessibilityContextCapturer<LiveAXElementReader>(),
        screenshotCapturer: ScreenshotCapturing = ScreenshotCapturer(),
        accessibilityDebugSaver: AccessibilityContextDebugSaver =
            AccessibilityContextDebugSaver(),
        screenshotDebugSaver: ScreenshotDebugSaver = ScreenshotDebugSaver(),
        captureDeadline: TimeInterval = AccessibilityContextLimits.captureDeadline
    ) {
        self.accessibilityCapturer = accessibilityCapturer
        self.screenshotCapturer = screenshotCapturer
        self.accessibilityDebugSaver = accessibilityDebugSaver
        self.screenshotDebugSaver = screenshotDebugSaver
        self.captureDeadline = captureDeadline
    }

    /// Starts the Accessibility read in the background; call it before
    /// Cmd+C so it overlaps the copy. Returns nil when App context is off, so
    /// nothing is read.
    func startAccessibilityCapture(
        _ request: AccessibilityContextRequest
    ) -> PendingAccessibilityContextCapture? {
        guard request.mode != .off else { return nil }
        return PendingAccessibilityContextCapture(
            request: request,
            capturer: accessibilityCapturer,
            queue: accessibilityQueue
        )
    }

    func collect(
        accessibility pending: PendingAccessibilityContextCapture?,
        copiedText: String,
        screenshotMode: ScreenshotContextMode,
        screenshotTarget: ScreenshotTarget
    ) async -> CollectedContext {
        let accessibility = await pending?.result(
            copiedText: copiedText,
            deadline: captureDeadline
        )
        if let accessibility = accessibility {
            log(Self.describe(accessibility))
        }

        let decision = ContextSourcePolicy.decide(
            accessibility: accessibility,
            screenshotMode: screenshotMode
        )
        let screenshot = await screenshot(
            for: decision,
            mode: screenshotMode,
            target: screenshotTarget
        )

        if let accessibility = accessibility {
            _ = accessibilityDebugSaver.saveIfEnabled(
                result: accessibility,
                screenshotTaken: screenshot.attachment != nil,
                screenshotReason: decision.screenshotReason.rawValue
            )
        }
        return CollectedContext(
            accessibilityContext: decision.accessibilityContext,
            accessibilityFallbackReason: decision.accessibilityFallbackReason,
            screenshot: screenshot
        )
    }

    private func screenshot(
        for decision: ContextSourcePolicy.Decision,
        mode: ScreenshotContextMode,
        target: ScreenshotTarget
    ) async -> ScreenshotCaptureResult {
        guard decision.takesScreenshot else {
            log("Screenshot: skipped/\(decision.screenshotReason.rawValue)")
            return ScreenshotCaptureResult(attachment: nil, warning: nil)
        }

        let start = ProcessInfo.processInfo.systemUptime
        let result = await screenshotCapturer.capture(
            mode: mode,
            activeBundleId: target.bundleId,
            activeWindowID: target.windowID,
            cursorLocation: target.cursorLocation
        )
        let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1_000
        let outcome = result.attachment.map {
            "attached, base64Length=\($0.base64Data.count)"
        } ?? "not attached"
        log(
            "Screenshot: \(Self.format(elapsed)) ms, \(outcome), " +
            "reason=\(decision.screenshotReason.rawValue)"
        )

        if let warning = result.warning {
            log("Screenshot context warning: \(warning)")
        }
        if let attachment = result.attachment {
            _ = screenshotDebugSaver.saveIfEnabled(
                attachment: attachment,
                mode: mode
            )
        }
        return result
    }

    /// Lengths only; the captured text never reaches the log.
    private static func describe(_ result: AccessibilityContextResult) -> String {
        switch result {
        case .usable(let context):
            return "AX context: \(format(context.timings.total)) ms, usable, " +
                "mode=\(context.mode.rawValue), " +
                "beforeLength=\(context.textBeforeSelection.count), " +
                "afterLength=\(context.textAfterSelection.count), " +
                "nearbyLength=\(context.nearbyText.count)" +
                describe(context.nearbyWalk, ms: context.timings.nearby)
        case .unusable(let reason, let partial):
            let electron = partial.requestedManualAccessibility
                ? ", requested AXManualAccessibility"
                : ""
            return "AX context: \(format(partial.timings.total)) ms, " +
                "unusable/\(reason.rawValue), mode=\(partial.mode.rawValue)" +
                electron
        }
    }

    private static func describe(_ walk: NearbyTextWalk?, ms: Double) -> String {
        guard let walk = walk else { return "" }
        return ", nearby: \(format(ms)) ms, nodes=\(walk.nodesVisited), " +
            "cutoff=\(walk.cutoff?.rawValue ?? "none")"
    }

    private static func format(_ milliseconds: Double) -> String {
        String(format: "%.1f", milliseconds)
    }

    private func log(_ message: String) {
        os_log("%{private}@", log: logger, type: .debug, message)
        #if DEBUG
        print(message)
        #endif
    }
}
