import XCTest
@testable import Make_It_Sound_Natural

/// Returns a fixed capture; with a gate, blocks until the test opens it.
private final class FakeAccessibilityContextCapturer:
    AccessibilityContextCapturing {
    private let result: AccessibilityContextCapture
    private let gate: DispatchSemaphore?
    private let lock = NSLock()
    private var recordedRequests: [AccessibilityContextRequest] = []
    private var recordedMainThread: [Bool] = []
    let started = XCTestExpectation(description: "AX capture started")

    init(result: AccessibilityContextCapture, gate: DispatchSemaphore? = nil) {
        self.result = result
        self.gate = gate
    }

    var requests: [AccessibilityContextRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    var ranOnMainThread: [Bool] {
        lock.lock()
        defer { lock.unlock() }
        return recordedMainThread
    }

    func capture(
        _ request: AccessibilityContextRequest
    ) -> AccessibilityContextCapture {
        lock.lock()
        recordedRequests.append(request)
        recordedMainThread.append(Thread.isMainThread)
        lock.unlock()
        started.fulfill()
        gate?.wait()
        return result
    }
}

private final class FakeScreenshotCapturer: ScreenshotCapturing {
    private(set) var modes: [ScreenshotContextMode] = []
    let attachment = LLMService.ScreenshotAttachment(
        mimeType: "image/jpeg",
        base64Data: "c2NyZWVu"
    )

    func capture(
        mode: ScreenshotContextMode,
        activeBundleId: String?,
        activeWindowID: CGWindowID?,
        cursorLocation: NSPoint?
    ) async -> ScreenshotCaptureResult {
        modes.append(mode)
        return ScreenshotCaptureResult(attachment: attachment, warning: nil)
    }
}

final class ContextSourceCollectorTests: XCTestCase {
    private let copiedText = "the draft is ready."
    private let target = ScreenshotTarget(
        bundleId: "com.apple.mail",
        windowID: 42,
        cursorLocation: NSPoint(x: 10, y: 20)
    )
    private var gates: [DispatchSemaphore] = []

    override func tearDown() {
        // Release captures still parked on the serial queue.
        for gate in gates {
            gate.signal()
        }
        gates = []
        super.tearDown()
    }

    private func request(
        _ mode: AccessibilityContextMode
    ) -> AccessibilityContextRequest {
        AccessibilityContextRequest(
            mode: mode,
            processID: 123,
            appName: "Mail",
            bundleId: "com.apple.mail"
        )
    }

    private func fieldCapture(
        mode: AccessibilityContextMode,
        nearbyText: String = ""
    ) -> AccessibilityContextCapture {
        var context = AccessibilityContext(
            mode: mode,
            appName: "Mail",
            bundleId: "com.apple.mail"
        )
        context.nearbyText = nearbyText
        let excerpt = AccessibilityFieldExcerpt(
            text: "Hi Anna, the draft is ready. Thanks",
            selection: NSRange(location: 9, length: 19),
            startsAtFieldStart: true,
            endsAtFieldEnd: true
        )
        return AccessibilityContextCapture(
            context: context,
            field: .excerpt(excerpt)
        )
    }

    private func makeCollector(
        accessibility: FakeAccessibilityContextCapturer,
        screenshot: FakeScreenshotCapturer,
        captureDeadline: TimeInterval = 5
    ) -> ContextSourceCollector {
        ContextSourceCollector(
            accessibilityCapturer: accessibility,
            screenshotCapturer: screenshot,
            accessibilityDebugSaver: AccessibilityContextDebugSaver(
                environment: [:]
            ),
            screenshotDebugSaver: ScreenshotDebugSaver(environment: [:]),
            captureDeadline: captureDeadline
        )
    }

    private func collect(
        _ collector: ContextSourceCollector,
        mode: AccessibilityContextMode,
        screenshotMode: ScreenshotContextMode
    ) async -> CollectedContext {
        let pending = collector.startAccessibilityCapture(request(mode))
        return await collector.collect(
            accessibility: pending,
            copiedText: copiedText,
            screenshotMode: screenshotMode,
            screenshotTarget: target
        )
    }

    func testNearbyTextSkipsTheScreenshot() async {
        let accessibility = FakeAccessibilityContextCapturer(
            result: fieldCapture(
                mode: .fieldAndNearby,
                nearbyText: "Anna: is the draft ready?"
            )
        )
        let screenshot = FakeScreenshotCapturer()
        let collector = makeCollector(
            accessibility: accessibility,
            screenshot: screenshot
        )

        let collected = await collect(
            collector,
            mode: .fieldAndNearby,
            screenshotMode: .activeApplication
        )

        XCTAssertEqual(screenshot.modes, [])
        XCTAssertNil(collected.screenshot.attachment)
        XCTAssertEqual(
            collected.accessibilityContext?.nearbyText,
            "Anna: is the draft ready?"
        )
        XCTAssertEqual(
            collected.accessibilityContext?.textBeforeSelection,
            "Hi Anna, "
        )
        XCTAssertNil(collected.accessibilityFallbackReason)
    }

    func testFieldExcerptWithoutNearbyTextAlsoTakesTheScreenshot() async {
        let accessibility = FakeAccessibilityContextCapturer(
            result: fieldCapture(mode: .field)
        )
        let screenshot = FakeScreenshotCapturer()
        let collector = makeCollector(
            accessibility: accessibility,
            screenshot: screenshot
        )

        let collected = await collect(
            collector,
            mode: .field,
            screenshotMode: .fullScreen
        )

        XCTAssertEqual(screenshot.modes, [.fullScreen])
        XCTAssertEqual(
            collected.screenshot.attachment?.base64Data,
            screenshot.attachment.base64Data
        )
        XCTAssertEqual(
            collected.accessibilityContext?.textAfterSelection,
            " Thanks"
        )
    }

    func testUnusableReadFallsBackToTheScreenshot() async {
        let accessibility = FakeAccessibilityContextCapturer(
            result: fieldCapture(mode: .field)
        )
        let screenshot = FakeScreenshotCapturer()
        let collector = makeCollector(
            accessibility: accessibility,
            screenshot: screenshot
        )
        let pending = collector.startAccessibilityCapture(request(.field))

        let collected = await collector.collect(
            accessibility: pending,
            copiedText: "text that is not in the field",
            screenshotMode: .activeApplication,
            screenshotTarget: target
        )

        XCTAssertEqual(screenshot.modes, [.activeApplication])
        XCTAssertNotNil(collected.screenshot.attachment)
        XCTAssertNil(collected.accessibilityContext)
        XCTAssertEqual(collected.accessibilityFallbackReason, .selectionMismatch)
    }

    func testScreenshotOffNeverTakesTheScreenshot() async {
        let accessibility = FakeAccessibilityContextCapturer(
            result: AccessibilityContextCapture(
                context: AccessibilityContext(
                    mode: .field,
                    appName: "Mail",
                    bundleId: "com.apple.mail"
                ),
                field: .unusable(.rangeUnavailable)
            )
        )
        let screenshot = FakeScreenshotCapturer()
        let collector = makeCollector(
            accessibility: accessibility,
            screenshot: screenshot
        )

        let collected = await collect(
            collector,
            mode: .field,
            screenshotMode: .off
        )

        XCTAssertEqual(screenshot.modes, [])
        XCTAssertNil(collected.screenshot.attachment)
        XCTAssertEqual(collected.accessibilityFallbackReason, .rangeUnavailable)
    }

    func testAccessibilityOffReadsNothing() async {
        let accessibility = FakeAccessibilityContextCapturer(
            result: fieldCapture(mode: .field)
        )
        let screenshot = FakeScreenshotCapturer()
        let collector = makeCollector(
            accessibility: accessibility,
            screenshot: screenshot
        )

        let pending = collector.startAccessibilityCapture(request(.off))
        let collected = await collector.collect(
            accessibility: pending,
            copiedText: copiedText,
            screenshotMode: .activeApplication,
            screenshotTarget: target
        )

        XCTAssertNil(pending)
        XCTAssertEqual(accessibility.requests.count, 0)
        XCTAssertNil(collected.accessibilityContext)
        XCTAssertNil(collected.accessibilityFallbackReason)
        XCTAssertEqual(screenshot.modes, [.activeApplication])
    }

    func testCaptureRunsInBackgroundBeforeTheCopyArrives() async {
        let gate = DispatchSemaphore(value: 0)
        gates.append(gate)
        let accessibility = FakeAccessibilityContextCapturer(
            result: fieldCapture(mode: .field),
            gate: gate
        )
        let collector = makeCollector(
            accessibility: accessibility,
            screenshot: FakeScreenshotCapturer()
        )

        // Returns while the read is still blocked, as it would be during Cmd+C.
        let pending = collector.startAccessibilityCapture(request(.field))
        await fulfillment(of: [accessibility.started], timeout: 1)
        gate.signal()
        let collected = await collector.collect(
            accessibility: pending,
            copiedText: copiedText,
            screenshotMode: .off,
            screenshotTarget: target
        )

        XCTAssertEqual(accessibility.ranOnMainThread, [false])
        XCTAssertEqual(accessibility.requests.first?.processID, 123)
        XCTAssertNotNil(collected.accessibilityContext)
    }

    func testSlowReadTimesOutAndFallsBackToTheScreenshot() async {
        let gate = DispatchSemaphore(value: 0)
        gates.append(gate)
        let accessibility = FakeAccessibilityContextCapturer(
            result: fieldCapture(mode: .field),
            gate: gate
        )
        let screenshot = FakeScreenshotCapturer()
        let collector = makeCollector(
            accessibility: accessibility,
            screenshot: screenshot,
            captureDeadline: 0.05
        )

        let collected = await collect(
            collector,
            mode: .field,
            screenshotMode: .activeApplication
        )

        XCTAssertEqual(collected.accessibilityFallbackReason, .timeout)
        XCTAssertNil(collected.accessibilityContext)
        XCTAssertEqual(screenshot.modes, [.activeApplication])
    }
}
