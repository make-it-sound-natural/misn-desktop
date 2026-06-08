import CoreGraphics
import Foundation

enum ScreenRecordingPermissionStatus: String {
    case granted
    case promptMayBeVisible
    case manualGrantRequired
    case unsupported

    var channelResponse: [String: String] {
        ["status": rawValue]
    }
}

struct ScreenRecordingPermissionProbe {
    let isSupported: () -> Bool
    let requestAccess: () -> Bool
    let preflight: () -> Bool
    let didRequestBefore: () -> Bool
    let markRequested: () -> Void
}

struct ScreenRecordingPermission {
    static func request(
        for mode: ScreenshotContextMode
    ) -> ScreenRecordingPermissionStatus {
        status(
            for: mode,
            probe: liveProbe
        )
    }

    static func check(
        for mode: ScreenshotContextMode
    ) -> ScreenRecordingPermissionStatus {
        check(
            for: mode,
            probe: liveProbe
        )
    }

    static func check(
        for mode: ScreenshotContextMode,
        probe: ScreenRecordingPermissionProbe
    ) -> ScreenRecordingPermissionStatus {
        guard mode != .off else {
            return .granted
        }
        guard probe.isSupported() else {
            return .unsupported
        }
        return probe.preflight() ? .granted : .manualGrantRequired
    }

    static func status(
        for mode: ScreenshotContextMode,
        probe: ScreenRecordingPermissionProbe
    ) -> ScreenRecordingPermissionStatus {
        guard mode != .off else {
            return .granted
        }
        guard probe.isSupported() else {
            return .unsupported
        }
        if probe.preflight() {
            return .granted
        }
        guard probe.didRequestBefore() else {
            probe.markRequested()
            return probe.requestAccess() ? .granted : .promptMayBeVisible
        }
        return .manualGrantRequired
    }

    static func hasAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    private static var liveProbe: ScreenRecordingPermissionProbe {
        ScreenRecordingPermissionProbe(
            isSupported: {
                if #available(macOS 14.0, *) {
                    return true
                }
                return false
            },
            requestAccess: CGRequestScreenCaptureAccess,
            preflight: CGPreflightScreenCaptureAccess,
            didRequestBefore: {
                UserDefaults.standard.bool(
                    forKey: "screen_recording_permission_requested"
                )
            },
            markRequested: {
                UserDefaults.standard.set(
                    true,
                    forKey: "screen_recording_permission_requested"
                )
            }
        )
    }
}
