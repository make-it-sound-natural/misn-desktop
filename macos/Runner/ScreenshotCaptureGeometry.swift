import AppKit
import Foundation

struct ScreenshotDisplayCandidate {
    let displayID: CGDirectDisplayID
    let frame: CGRect
}

struct ScreenshotWindowCandidate {
    let windowID: CGWindowID
    let bundleID: String?
    let isOnScreen: Bool
    let frame: CGRect?
}

struct ScreenshotVisibleSourceRect {
    let rect: CGRect
    let isClipped: Bool
}

enum ScreenshotCaptureSizing {
    static func outputDimensions(
        contentRect: CGRect,
        pointPixelScale: CGFloat,
        maxDimension: CGFloat = 1_600
    ) -> (width: Int, height: Int) {
        let pixelWidth = max(1, contentRect.width * pointPixelScale)
        let pixelHeight = max(1, contentRect.height * pointPixelScale)
        let largestSide = max(pixelWidth, pixelHeight)
        let scaleDown = min(1, maxDimension / largestSide)
        return (
            width: max(1, Int((pixelWidth * scaleDown).rounded())),
            height: max(1, Int((pixelHeight * scaleDown).rounded()))
        )
    }
}

enum ScreenshotCaptureSelection {
    static func visibleSourceRect(
        windowFrame: CGRect,
        displayFrame: CGRect,
        filterContentRect: CGRect
    ) -> ScreenshotVisibleSourceRect? {
        let visibleFrame = windowFrame.intersection(displayFrame)
        guard !visibleFrame.isNull,
              visibleFrame.width > 0,
              visibleFrame.height > 0 else {
            return nil
        }

        let sourceRect = CGRect(
            x: filterContentRect.origin.x
                + visibleFrame.origin.x
                - displayFrame.origin.x,
            y: filterContentRect.origin.y
                + visibleFrame.origin.y
                - displayFrame.origin.y,
            width: visibleFrame.width,
            height: visibleFrame.height
        )
        return ScreenshotVisibleSourceRect(
            rect: sourceRect,
            isClipped: !visibleFrame.equalTo(windowFrame)
        )
    }

    static func selectedDisplayID(
        cursorLocation: NSPoint?,
        screenDisplays: [ScreenshotDisplayCandidate],
        fallbackDisplayID: CGDirectDisplayID?
    ) -> CGDirectDisplayID? {
        if let cursorLocation,
           let matchingDisplay = screenDisplays.first(where: {
               $0.frame.contains(cursorLocation)
           }) {
            return matchingDisplay.displayID
        }

        if let fallbackDisplayID,
           screenDisplays.contains(
               where: { $0.displayID == fallbackDisplayID }
           ) {
            return fallbackDisplayID
        }

        return screenDisplays.first?.displayID ?? fallbackDisplayID
    }

    static func selectedDisplayID(
        windowFrame: CGRect,
        screenDisplays: [ScreenshotDisplayCandidate],
        fallbackDisplayID: CGDirectDisplayID?
    ) -> CGDirectDisplayID? {
        let bestMatch = screenDisplays
            .map { display -> (displayID: CGDirectDisplayID, area: CGFloat) in
                let intersection = display.frame.intersection(windowFrame)
                if intersection.isNull {
                    return (display.displayID, 0)
                }
                return (
                    display.displayID,
                    intersection.width * intersection.height
                )
            }
            .max { lhs, rhs in lhs.area < rhs.area }

        if let bestMatch, bestMatch.area > 0 {
            return bestMatch.displayID
        }

        if let fallbackDisplayID,
           screenDisplays.contains(
               where: { $0.displayID == fallbackDisplayID }
           ) {
            return fallbackDisplayID
        }

        return screenDisplays.first?.displayID ?? fallbackDisplayID
    }

    static func selectedWindowID(
        activeBundleId: String?,
        activeWindowID: CGWindowID?,
        cursorLocation: NSPoint? = nil,
        windowCandidates: [ScreenshotWindowCandidate]
    ) -> CGWindowID? {
        guard let activeBundleId = activeBundleId else { return nil }

        let appWindows = windowCandidates.filter {
            $0.bundleID == activeBundleId && $0.isOnScreen
        }

        if let activeWindowID,
           appWindows.contains(where: { $0.windowID == activeWindowID }) {
            return activeWindowID
        }

        if appWindows.count == 1 {
            return appWindows[0].windowID
        }

        if let cursorLocation,
           let cursorMatch = windowIDContaining(
               cursor: cursorLocation,
               in: appWindows
           ) {
            return cursorMatch
        }

        return nil
    }

    static func windowIDContaining(
        cursor: NSPoint,
        in windows: [ScreenshotWindowCandidate]
    ) -> CGWindowID? {
        let containing = windows.filter { candidate in
            guard let frame = candidate.frame else { return false }
            return frame.contains(cursor)
        }
        switch containing.count {
        case 0:
            return nil
        case 1:
            return containing[0].windowID
        default:
            let best = containing.min { lhs, rhs in
                windowArea(lhs.frame) < windowArea(rhs.frame)
            }
            return best?.windowID
        }
    }

    private static func windowArea(_ frame: CGRect?) -> CGFloat {
        guard let frame else { return .greatestFiniteMagnitude }
        return frame.width * frame.height
    }
}
