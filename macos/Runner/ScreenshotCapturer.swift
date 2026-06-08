import AppKit
import Foundation

#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif

struct ScreenshotCaptureResult {
    let attachment: LLMService.ScreenshotAttachment?
    let warning: String?
}

@available(macOS 14.0, *)
struct ScreenshotCaptureTargetCandidate {
    let filter: SCContentFilter
    let sourceRect: CGRect?
}

enum ScreenshotCaptureWarning {
    case unsupportedMacOS
    case permissionDenied
    case activeWindowUnavailable
    case captureFailed

    var message: String {
        switch self {
        case .unsupportedMacOS:
            return "Screenshot context requires macOS 14.0 or later."
        case .permissionDenied:
            return """
            Screenshot context skipped. Grant Screen Recording permission in System Settings.
            """
        case .activeWindowUnavailable:
            return """
            Screenshot context skipped. Active app window could not be identified.
            """
        case .captureFailed:
            return "Screenshot context skipped. Screen capture failed."
        }
    }
}

protocol ScreenshotCapturing {
    func capture(
        mode: ScreenshotContextMode,
        activeBundleId: String?,
        activeWindowID: CGWindowID?,
        cursorLocation: NSPoint?
    ) async -> ScreenshotCaptureResult
}

final class ScreenshotCapturer: ScreenshotCapturing {
    private let debugLog: (String) -> Void

    init(debugLog: @escaping (String) -> Void = defaultScreenshotCaptureLog) {
        self.debugLog = debugLog
    }

    func capture(
        mode: ScreenshotContextMode,
        activeBundleId: String?,
        activeWindowID: CGWindowID?,
        cursorLocation: NSPoint?
    ) async -> ScreenshotCaptureResult {
        guard mode != .off else {
            return ScreenshotCaptureResult(attachment: nil, warning: nil)
        }

        guard #available(macOS 14.0, *) else {
            return ScreenshotCaptureResult(
                attachment: nil,
                warning: ScreenshotCaptureWarning.unsupportedMacOS.message
            )
        }

        guard ScreenRecordingPermission.hasAccess() else {
            return ScreenshotCaptureResult(
                attachment: nil,
                warning: ScreenshotCaptureWarning.permissionDenied.message
            )
        }

        return await captureWithScreenCaptureKit(
            mode: mode,
            activeBundleId: activeBundleId,
            activeWindowID: activeWindowID,
            cursorLocation: cursorLocation
        )
    }
}

private extension ScreenshotCapturer {
    @available(macOS 14.0, *)
    func captureWithScreenCaptureKit(
        mode: ScreenshotContextMode,
        activeBundleId: String?,
        activeWindowID: CGWindowID?,
        cursorLocation: NSPoint?
    ) async -> ScreenshotCaptureResult {
        #if canImport(ScreenCaptureKit)
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            guard let target = captureTarget(
                mode: mode,
                content: content,
                activeBundleId: activeBundleId,
                activeWindowID: activeWindowID,
                cursorLocation: cursorLocation
            ) else {
                return ScreenshotCaptureResult(
                    attachment: nil,
                    warning: missingFilterWarning(for: mode)
                )
            }

            guard let attachment = try await captureAttachment(
                target: target
            ) else {
                return ScreenshotCaptureResult(
                    attachment: nil,
                    warning: ScreenshotCaptureWarning.captureFailed.message
                )
            }

            return ScreenshotCaptureResult(
                attachment: attachment,
                warning: nil
            )
        } catch {
            return ScreenshotCaptureResult(
                attachment: nil,
                warning: ScreenshotCaptureWarning.permissionDenied.message
            )
        }
        #else
        return ScreenshotCaptureResult(
            attachment: nil,
            warning: ScreenshotCaptureWarning.captureFailed.message
        )
        #endif
    }

    @available(macOS 14.0, *)
    func captureAttachment(
        target: ScreenshotCaptureTargetCandidate
    ) async throws -> LLMService.ScreenshotAttachment? {
        let filter = target.filter
        let captureRect = target.sourceRect ?? filter.contentRect
        let dimensions = ScreenshotCaptureSizing.outputDimensions(
            contentRect: captureRect,
            pointPixelScale: CGFloat(filter.pointPixelScale)
        )
        let config = SCStreamConfiguration()
        config.width = dimensions.width
        config.height = dimensions.height
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.showsCursor = false
        config.scalesToFit = true
        config.preservesAspectRatio = true
        if let sourceRect = target.sourceRect {
            config.sourceRect = sourceRect
        }

        debugLog(
            "Screenshot capture filter rect: " +
            "\(describeScreenshotCapture(rect: filter.contentRect)), " +
            "source: \(describeScreenshotCapture(rect: captureRect)), " +
            "scale: \(String(format: "%.2f", Double(filter.pointPixelScale))), " +
            "output: \(config.width)x\(config.height)"
        )

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
        debugLog("Screenshot capture image size: \(image.width)x\(image.height)")
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.72]
        ) else {
            return nil
        }

        return LLMService.ScreenshotAttachment(
            mimeType: "image/jpeg",
            base64Data: data.base64EncodedString()
        )
    }

    @available(macOS 14.0, *)
    func captureTarget(
        mode: ScreenshotContextMode,
        content: SCShareableContent,
        activeBundleId: String?,
        activeWindowID: CGWindowID?,
        cursorLocation: NSPoint?
    ) -> ScreenshotCaptureTargetCandidate? {
        switch mode {
        case .off:
            return nil
        case .activeApplication:
            return activeWindowTarget(
                content: content,
                activeBundleId: activeBundleId,
                activeWindowID: activeWindowID,
                cursorLocation: cursorLocation
            )
        case .fullScreen:
            return activeDisplayFilter(
                content: content,
                cursorLocation: cursorLocation
            )
        }
    }

    @available(macOS 14.0, *)
    func activeWindowTarget(
        content: SCShareableContent,
        activeBundleId: String?,
        activeWindowID: CGWindowID?,
        cursorLocation: NSPoint?
    ) -> ScreenshotCaptureTargetCandidate? {
        guard let window = selectedActiveWindow(
            content: content,
            activeBundleId: activeBundleId,
            activeWindowID: activeWindowID,
            cursorLocation: cursorLocation
        ) else {
            return nil
        }
        let displayID = ScreenshotCaptureSelection.selectedDisplayID(
            windowFrame: window.frame,
            screenDisplays: displayCandidates(from: content),
            fallbackDisplayID: content.displays.first?.displayID
        )
        guard let display = content.displays.first(where: {
            $0.displayID == displayID
        }) ?? content.displays.first else {
            return nil
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        guard let visibleSource = ScreenshotCaptureSelection.visibleSourceRect(
            windowFrame: window.frame,
            displayFrame: display.frame,
            filterContentRect: filter.contentRect
        ) else {
            return nil
        }
        debugLog(
            "Screenshot selected window: id=\(window.windowID), " +
            "bundle=\(window.owningApplication?.bundleIdentifier ?? "unknown"), " +
            "frame=\(describeScreenshotCapture(rect: window.frame)), " +
            "display=\(display.displayID), " +
            "displayFrame=\(describeScreenshotCapture(rect: display.frame)), " +
            "visibleSource=\(describeScreenshotCapture(rect: visibleSource.rect)), " +
            "clipped=\(visibleSource.isClipped ? "yes" : "no")"
        )
        return ScreenshotCaptureTargetCandidate(
            filter: filter,
            sourceRect: visibleSource.rect
        )
    }

    @available(macOS 14.0, *)
    func selectedActiveWindow(
        content: SCShareableContent,
        activeBundleId: String?,
        activeWindowID: CGWindowID?,
        cursorLocation: NSPoint?
    ) -> SCWindow? {
        let windowCandidates = content.windows.map { window in
            ScreenshotWindowCandidate(
                windowID: window.windowID,
                bundleID: window.owningApplication?.bundleIdentifier,
                isOnScreen: window.isOnScreen,
                frame: window.frame
            )
        }
        guard let windowID = ScreenshotCaptureSelection.selectedWindowID(
            activeBundleId: activeBundleId,
            activeWindowID: activeWindowID,
            cursorLocation: cursorLocation,
            windowCandidates: windowCandidates
        ) else {
            return nil
        }
        return content.windows.first { $0.windowID == windowID }
    }

    @available(macOS 14.0, *)
    func displayCandidates(
        from content: SCShareableContent
    ) -> [ScreenshotDisplayCandidate] {
        content.displays.map {
            ScreenshotDisplayCandidate(
                displayID: $0.displayID,
                frame: $0.frame
            )
        }
    }

    @available(macOS 14.0, *)
    func activeDisplayFilter(
        content: SCShareableContent,
        cursorLocation: NSPoint?
    ) -> ScreenshotCaptureTargetCandidate? {
        let screenDisplays: [ScreenshotDisplayCandidate] = NSScreen.screens
            .compactMap { screen -> ScreenshotDisplayCandidate? in
                guard let number = screen.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")
                ] as? NSNumber else {
                    return nil
                }
                return ScreenshotDisplayCandidate(
                    displayID: CGDirectDisplayID(number.uint32Value),
                    frame: screen.frame
                )
            }

        guard let displayID = ScreenshotCaptureSelection.selectedDisplayID(
            cursorLocation: cursorLocation,
            screenDisplays: screenDisplays,
            fallbackDisplayID: content.displays.first?.displayID
        ) else {
            return nil
        }

        guard let display = content.displays.first(where: {
            $0.displayID == displayID
        }) ?? content.displays.first else {
            return nil
        }
        debugLog("Screenshot selected display: id=\(display.displayID)")
        return ScreenshotCaptureTargetCandidate(
            filter: SCContentFilter(display: display, excludingWindows: []),
            sourceRect: nil
        )
    }

    func missingFilterWarning(for mode: ScreenshotContextMode) -> String {
        mode == .activeApplication
            ? ScreenshotCaptureWarning.activeWindowUnavailable.message
            : ScreenshotCaptureWarning.captureFailed.message
    }
}

private func describeScreenshotCapture(rect: CGRect) -> String {
    "x=\(Int(rect.origin.x.rounded())), " +
    "y=\(Int(rect.origin.y.rounded())), " +
    "w=\(Int(rect.width.rounded())), " +
    "h=\(Int(rect.height.rounded()))"
}

private func defaultScreenshotCaptureLog(_ message: String) {
    #if DEBUG
    print(message)
    #endif
}
