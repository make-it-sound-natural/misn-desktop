import AppKit
import XCTest
@testable import Make_It_Sound_Natural

final class ScreenshotCapturerTests: XCTestCase {
    func testOffModeSkipsCapture() async {
        let capturer = ScreenshotCapturer()
        let result = await capturer.capture(
            mode: .off,
            activeBundleId: "com.example.app",
            activeWindowID: 10,
            cursorLocation: .zero
        )

        XCTAssertNil(result.attachment)
        XCTAssertNil(result.warning)
    }

    func testUnsupportedMacOSWarningMessageIsStable() {
        XCTAssertEqual(
            ScreenshotCaptureWarning.unsupportedMacOS.message,
            "Screenshot context requires macOS 14.0 or later."
        )
    }

    func testScreenshotOutputDimensionsPreserveAspectRatioWhenDownscaling() {
        let dimensions = ScreenshotCaptureSizing.outputDimensions(
            contentRect: CGRect(x: 0, y: 0, width: 2_000, height: 1_000),
            pointPixelScale: 2,
            maxDimension: 1_600
        )

        XCTAssertEqual(dimensions.width, 1_600)
        XCTAssertEqual(dimensions.height, 800)
    }

    func testScreenshotOutputDimensionsUseNativeSizeWhenSmallEnough() {
        let dimensions = ScreenshotCaptureSizing.outputDimensions(
            contentRect: CGRect(x: 0, y: 0, width: 500, height: 300),
            pointPixelScale: 2,
            maxDimension: 1_600
        )

        XCTAssertEqual(dimensions.width, 1_000)
        XCTAssertEqual(dimensions.height, 600)
    }

    func testPermissionStatusGrantsOffModeWithoutRequest() {
        let status = ScreenRecordingPermission.status(
            for: .off,
            probe: ScreenRecordingPermissionProbe(
                isSupported: { false },
                requestAccess: { XCTFail("Off mode should not request access"); return false },
                preflight: { XCTFail("Off mode should not preflight"); return false },
                didRequestBefore: { false },
                markRequested: { XCTFail("Off mode should not mark requested") }
            )
        )

        XCTAssertEqual(status, .granted)
    }

    func testPermissionStatusReturnsUnsupported() {
        let status = ScreenRecordingPermission.status(
            for: .fullScreen,
            probe: ScreenRecordingPermissionProbe(
                isSupported: { false },
                requestAccess: { XCTFail("Unsupported OS should not request"); return false },
                preflight: { XCTFail("Unsupported OS should not preflight"); return false },
                didRequestBefore: { false },
                markRequested: { XCTFail("Unsupported OS should not mark requested") }
            )
        )

        XCTAssertEqual(status, .unsupported)
    }

    func testPermissionStatusReturnsGrantedWhenRequestSucceeds() {
        var didMarkRequested = false
        let status = ScreenRecordingPermission.status(
            for: .fullScreen,
            probe: ScreenRecordingPermissionProbe(
                isSupported: { true },
                requestAccess: { true },
                preflight: { false },
                didRequestBefore: { false },
                markRequested: { didMarkRequested = true }
            )
        )

        XCTAssertEqual(status, .granted)
        XCTAssertTrue(didMarkRequested)
    }

    func testPermissionStatusReturnsGrantedWhenPreflightSucceeds() {
        let status = ScreenRecordingPermission.status(
            for: .fullScreen,
            probe: ScreenRecordingPermissionProbe(
                isSupported: { true },
                requestAccess: {
                    XCTFail("Granted permission should not request")
                    return false
                },
                preflight: { true },
                didRequestBefore: { true },
                markRequested: {
                    XCTFail("Granted permission should not mark requested")
                }
            )
        )

        XCTAssertEqual(status, .granted)
    }

    func testPermissionCheckUsesPreflightWithoutRequest() {
        let status = ScreenRecordingPermission.check(
            for: .fullScreen,
            probe: ScreenRecordingPermissionProbe(
                isSupported: { true },
                requestAccess: {
                    XCTFail("No-prompt check should not request")
                    return false
                },
                preflight: { true },
                didRequestBefore: { false },
                markRequested: {
                    XCTFail("No-prompt check should not mark requested")
                }
            )
        )

        XCTAssertEqual(status, .granted)
    }

    func testPermissionStatusReturnsPromptMayBeVisibleOnFirstRequest() {
        var didMarkRequested = false
        let status = ScreenRecordingPermission.status(
            for: .fullScreen,
            probe: ScreenRecordingPermissionProbe(
                isSupported: { true },
                requestAccess: { false },
                preflight: { false },
                didRequestBefore: { false },
                markRequested: { didMarkRequested = true }
            )
        )

        XCTAssertEqual(status, .promptMayBeVisible)
        XCTAssertTrue(didMarkRequested)
    }

    func testPermissionStatusReturnsManualWhenRequestAndPreflightFail() {
        let status = ScreenRecordingPermission.status(
            for: .fullScreen,
            probe: ScreenRecordingPermissionProbe(
                isSupported: { true },
                requestAccess: {
                    XCTFail("Existing request should not request")
                    return false
                },
                preflight: { false },
                didRequestBefore: { true },
                markRequested: { XCTFail("Existing request should not mark requested") }
            )
        )

        XCTAssertEqual(status, .manualGrantRequired)
    }

    func testDraggableAppPermissionViewWritesFileURL() {
        let appURL = URL(fileURLWithPath: "/Applications/Test.app")
        let view = DraggableAppPermissionView(
            appURL: appURL,
            title: "Test",
            subtitle: "Drag"
        )

        let item = view.pasteboardItem()

        XCTAssertEqual(item.string(forType: .fileURL), appURL.absoluteString)
    }

    func testPermissionGuideTextParsesOpenSettingsOnAppear() {
        let text = ScreenRecordingPermissionGuideText(
            arguments: [
                "title": "Title",
                "openSettingsOnAppear": true
            ]
        )

        XCTAssertEqual(text.title, "Title")
        XCTAssertTrue(text.openSettingsOnAppear)
    }

    func testPermissionGuideTextDefaultsToManualAddControls() {
        let text = ScreenRecordingPermissionGuideText(arguments: [:])

        XCTAssertTrue(text.manualAddRequired)
        XCTAssertTrue(text.presentation.showsDragInstructions)
        XCTAssertTrue(text.presentation.showsRevealInFinder)
    }

    func testPermissionGuideTextHidesManualAddControlsWhenAppIsListed() {
        let text = ScreenRecordingPermissionGuideText(
            arguments: ["manualAddRequired": false]
        )

        XCTAssertFalse(text.manualAddRequired)
        XCTAssertFalse(text.presentation.showsDragInstructions)
        XCTAssertFalse(text.presentation.showsRevealInFinder)
    }

    func testListedPermissionGuideContentOmitsManualAddViews() {
        let controller = ScreenRecordingPermissionGuideController(
            text: ScreenRecordingPermissionGuideText(
                arguments: ["manualAddRequired": false]
            ),
            appURL: URL(fileURLWithPath: "/Applications/Test.app")
        )

        let content = controller.makeContentViewForTesting()

        XCTAssertFalse(
            content.containsSubview(ofType: DraggableAppPermissionView.self)
        )
        XCTAssertFalse(content.containsButton(titled: "Reveal in Finder"))
    }

    func testManualAddPermissionGuideContentKeepsManualAddViews() {
        let controller = ScreenRecordingPermissionGuideController(
            text: ScreenRecordingPermissionGuideText(
                arguments: [
                    "manualAddRequired": true,
                    "revealInFinder": "Reveal in Finder"
                ]
            ),
            appURL: URL(fileURLWithPath: "/Applications/Test.app")
        )

        let content = controller.makeContentViewForTesting()

        XCTAssertTrue(
            content.containsSubview(ofType: DraggableAppPermissionView.self)
        )
        XCTAssertTrue(content.containsButton(titled: "Reveal in Finder"))
    }

    func testDraggableAppPermissionViewLayoutAvoidsOverlappingText() {
        XCTAssertGreaterThanOrEqual(
            DraggableAppPermissionView.preferredHeight,
            104
        )
        XCTAssertGreaterThan(
            DraggableAppPermissionView.titleFrame.minY,
            DraggableAppPermissionView.subtitleFrame.maxY - 1
        )
        XCTAssertGreaterThan(DraggableAppPermissionView.titleFrame.width, 0)
        XCTAssertGreaterThan(DraggableAppPermissionView.subtitleFrame.width, 0)
    }

    func testSelectedDisplayUsesCursorContainingFrame() {
        let displays = [
            ScreenshotDisplayCandidate(
                displayID: 100,
                frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
            ),
            ScreenshotDisplayCandidate(
                displayID: 200,
                frame: CGRect(x: 1440, y: 0, width: 1440, height: 900)
            )
        ]

        let selected = ScreenshotCaptureSelection.selectedDisplayID(
            cursorLocation: NSPoint(x: 1600, y: 400),
            screenDisplays: displays,
            fallbackDisplayID: 100
        )

        XCTAssertEqual(selected, 200)
    }

    func testSelectedDisplayFallsBackWhenCursorIsUnavailable() {
        let displays = [
            ScreenshotDisplayCandidate(
                displayID: 100,
                frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
            ),
            ScreenshotDisplayCandidate(
                displayID: 200,
                frame: CGRect(x: 1440, y: 0, width: 1440, height: 900)
            )
        ]

        let selected = ScreenshotCaptureSelection.selectedDisplayID(
            cursorLocation: nil,
            screenDisplays: displays,
            fallbackDisplayID: 100
        )

        XCTAssertEqual(selected, 100)
    }

    func testSelectedDisplayUsesLargestWindowIntersection() {
        let displays = [
            ScreenshotDisplayCandidate(
                displayID: 100,
                frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
            ),
            ScreenshotDisplayCandidate(
                displayID: 200,
                frame: CGRect(x: 1440, y: 0, width: 1440, height: 900)
            )
        ]

        let selected = ScreenshotCaptureSelection.selectedDisplayID(
            windowFrame: CGRect(x: 1300, y: 100, width: 500, height: 500),
            screenDisplays: displays,
            fallbackDisplayID: 100
        )

        XCTAssertEqual(selected, 200)
    }

    func testSelectedDisplayForWindowFallsBackWithoutIntersection() {
        let displays = [
            ScreenshotDisplayCandidate(
                displayID: 100,
                frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
            )
        ]

        let selected = ScreenshotCaptureSelection.selectedDisplayID(
            windowFrame: CGRect(x: 2000, y: 2000, width: 500, height: 500),
            screenDisplays: displays,
            fallbackDisplayID: 100
        )

        XCTAssertEqual(selected, 100)
    }

    func testVisibleSourceRectKeepsFullyVisibleWindow() throws {
        let result = try XCTUnwrap(
            ScreenshotCaptureSelection.visibleSourceRect(
                windowFrame: CGRect(x: 100, y: 120, width: 400, height: 300),
                displayFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
                filterContentRect: CGRect(x: 0, y: 0, width: 1_000, height: 800)
            )
        )

        XCTAssertEqual(result.rect, CGRect(x: 100, y: 120, width: 400, height: 300))
        XCTAssertFalse(result.isClipped)
    }

    func testVisibleSourceRectClipsRightEdge() throws {
        let result = try XCTUnwrap(
            ScreenshotCaptureSelection.visibleSourceRect(
                windowFrame: CGRect(x: 800, y: 100, width: 300, height: 200),
                displayFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
                filterContentRect: CGRect(x: 0, y: 0, width: 1_000, height: 800)
            )
        )

        XCTAssertEqual(result.rect, CGRect(x: 800, y: 100, width: 200, height: 200))
        XCTAssertTrue(result.isClipped)
    }

    func testVisibleSourceRectClipsLeftTopAndBottomEdges() throws {
        let filterRect = CGRect(x: 0, y: 0, width: 1_000, height: 800)
        let displayFrame = CGRect(x: 0, y: 0, width: 1_000, height: 800)

        let left = try XCTUnwrap(
            ScreenshotCaptureSelection.visibleSourceRect(
                windowFrame: CGRect(x: -100, y: 100, width: 300, height: 200),
                displayFrame: displayFrame,
                filterContentRect: filterRect
            )
        )
        let top = try XCTUnwrap(
            ScreenshotCaptureSelection.visibleSourceRect(
                windowFrame: CGRect(x: 100, y: -50, width: 300, height: 200),
                displayFrame: displayFrame,
                filterContentRect: filterRect
            )
        )
        let bottom = try XCTUnwrap(
            ScreenshotCaptureSelection.visibleSourceRect(
                windowFrame: CGRect(x: 100, y: 700, width: 300, height: 200),
                displayFrame: displayFrame,
                filterContentRect: filterRect
            )
        )

        XCTAssertEqual(left.rect, CGRect(x: 0, y: 100, width: 200, height: 200))
        XCTAssertEqual(top.rect, CGRect(x: 100, y: 0, width: 300, height: 150))
        XCTAssertEqual(bottom.rect, CGRect(x: 100, y: 700, width: 300, height: 100))
        XCTAssertTrue(left.isClipped)
        XCTAssertTrue(top.isClipped)
        XCTAssertTrue(bottom.isClipped)
    }

    func testVisibleSourceRectReturnsNilWhenWindowIsOutsideDisplay() {
        let result = ScreenshotCaptureSelection.visibleSourceRect(
            windowFrame: CGRect(x: 1_200, y: 100, width: 300, height: 200),
            displayFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            filterContentRect: CGRect(x: 0, y: 0, width: 1_000, height: 800)
        )

        XCTAssertNil(result)
    }

    func testVisibleSourceRectConvertsToFilterCoordinates() throws {
        let result = try XCTUnwrap(
            ScreenshotCaptureSelection.visibleSourceRect(
                windowFrame: CGRect(x: 120, y: 70, width: 300, height: 200),
                displayFrame: CGRect(x: 100, y: 50, width: 1_000, height: 800),
                filterContentRect: CGRect(x: 10, y: 20, width: 1_000, height: 800)
            )
        )

        XCTAssertEqual(result.rect, CGRect(x: 30, y: 40, width: 300, height: 200))
        XCTAssertFalse(result.isClipped)
    }

    func testSelectedWindowUsesCursorWhenFocusedIDMissing() {
        let windows = [
            ScreenshotWindowCandidate(
                windowID: 10,
                bundleID: "com.example.app",
                isOnScreen: true,
                frame: CGRect(x: 0, y: 0, width: 400, height: 300)
            ),
            ScreenshotWindowCandidate(
                windowID: 20,
                bundleID: "com.example.app",
                isOnScreen: true,
                frame: CGRect(x: 500, y: 0, width: 400, height: 300)
            )
        ]

        let selected = ScreenshotCaptureSelection.selectedWindowID(
            activeBundleId: "com.example.app",
            activeWindowID: nil,
            cursorLocation: NSPoint(x: 100, y: 100),
            windowCandidates: windows
        )

        XCTAssertEqual(selected, 10)
    }

    func testSelectedWindowUsesFocusedWindowID() {
        let windows = [
            ScreenshotWindowCandidate(
                windowID: 10,
                bundleID: "com.example.app",
                isOnScreen: true,
                frame: nil
            ),
            ScreenshotWindowCandidate(
                windowID: 20,
                bundleID: "com.example.app",
                isOnScreen: true,
                frame: nil
            )
        ]

        let selected = ScreenshotCaptureSelection.selectedWindowID(
            activeBundleId: "com.example.app",
            activeWindowID: 20,
            windowCandidates: windows
        )

        XCTAssertEqual(selected, 20)
    }

    func testSelectedWindowFailsClosedForAmbiguousAppWindows() {
        let windows = [
            ScreenshotWindowCandidate(
                windowID: 10,
                bundleID: "com.example.app",
                isOnScreen: true,
                frame: nil
            ),
            ScreenshotWindowCandidate(
                windowID: 20,
                bundleID: "com.example.app",
                isOnScreen: true,
                frame: nil
            )
        ]

        let selected = ScreenshotCaptureSelection.selectedWindowID(
            activeBundleId: "com.example.app",
            activeWindowID: nil,
            windowCandidates: windows
        )

        XCTAssertNil(selected)
    }

    func testSelectedWindowAllowsSingleMatchingAppWindowWithoutFocusedID() {
        let windows = [
            ScreenshotWindowCandidate(
                windowID: 10,
                bundleID: "com.example.app",
                isOnScreen: true,
                frame: nil
            ),
            ScreenshotWindowCandidate(
                windowID: 20,
                bundleID: "com.other.app",
                isOnScreen: true,
                frame: nil
            )
        ]

        let selected = ScreenshotCaptureSelection.selectedWindowID(
            activeBundleId: "com.example.app",
            activeWindowID: nil,
            windowCandidates: windows
        )

        XCTAssertEqual(selected, 10)
    }
}

private extension NSView {
    func containsSubview<T: NSView>(ofType type: T.Type) -> Bool {
        if self is T {
            return true
        }
        return subviews.contains { $0.containsSubview(ofType: type) }
    }

    func containsButton(titled title: String) -> Bool {
        if let button = self as? NSButton, button.title == title {
            return true
        }
        return subviews.contains { $0.containsButton(titled: title) }
    }
}
