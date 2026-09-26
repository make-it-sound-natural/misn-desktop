import ApplicationServices
import XCTest
@testable import Make_It_Sound_Natural

final class ElectronAccessibilityEnablerTests: XCTestCase {
    private static let slack = URL(fileURLWithPath: "/Applications/Slack.app")
    private let mail = URL(fileURLWithPath: "/System/Applications/Mail.app")
    private var reader: FakeAXReader!
    private var capturer: AccessibilityContextCapturer<FakeAXReader>!
    private var directories: [URL] = []

    override func setUp() {
        super.setUp()
        reader = FakeAXReader()
        let slack = Self.slack
        capturer = AccessibilityContextCapturer(
            reader: reader,
            isElectronApp: { $0 == slack }
        )
    }

    override func tearDown() {
        for directory in directories {
            try? FileManager.default.removeItem(at: directory)
        }
        directories = []
        reader = nil
        capturer = nil
        super.tearDown()
    }

    func testUnusableReadInElectronAppSetsManualAccessibilityOncePerPid() {
        let first = capturer.capture(request(processID: 42))
        let second = capturer.capture(request(processID: 42))
        let relaunched = capturer.capture(request(processID: 43))

        XCTAssertTrue(first.context.requestedManualAccessibility)
        XCTAssertFalse(second.context.requestedManualAccessibility)
        XCTAssertTrue(relaunched.context.requestedManualAccessibility)
        XCTAssertEqual(reader.writes.count, 2)
        XCTAssertTrue(reader.writes.allSatisfy {
            $0 == ("app", "AXManualAccessibility", true)
        })
        XCTAssertEqual(reader.timeouts["app"], AccessibilityContextLimits.messagingTimeout)
        // This run still falls back to the screenshot.
        XCTAssertEqual(first.field, .unusable(.noFocusedElement))
    }

    func testTreeShapedReasonsTriggerEnablement() {
        reader.app.elements[kAXFocusedUIElementAttribute] =
            FakeAXNode("window", role: kAXWindowRole)
        XCTAssertTrue(
            capturer.capture(request(processID: 1)).context
                .requestedManualAccessibility
        )

        reader.app.elements[kAXFocusedUIElementAttribute] =
            FakeAXNode("group", role: kAXGroupRole)
        let capture = capturer.capture(request(processID: 2))
        XCTAssertEqual(capture.field, .unusable(.rangeUnavailable))
        XCTAssertTrue(capture.context.requestedManualAccessibility)
    }

    func testFailedWriteIsNotRetriedForTheSamePid() {
        reader.writeError = .unavailable

        let first = capturer.capture(request(processID: 42))
        _ = capturer.capture(request(processID: 42))

        XCTAssertFalse(first.context.requestedManualAccessibility)
        XCTAssertEqual(reader.writes.count, 1)
    }

    func testNonElectronAppIsNeverEnabled() {
        _ = capturer.capture(request(processID: 42, bundleURL: mail))
        _ = capturer.capture(request(processID: 42, bundleURL: nil))

        XCTAssertTrue(reader.writes.isEmpty)
    }

    func testUsableReadIsNotEnabled() {
        let field = FakeAXNode.textArea(
            "Hi team, see you",
            selection: NSRange(location: 3, length: 4)
        )
        reader.app.elements[kAXFocusedUIElementAttribute] = field

        let capture = capturer.capture(request(processID: 42))

        guard case .usable = capture.resolve(copiedText: "team") else {
            return XCTFail("Expected a usable read")
        }
        XCTAssertTrue(reader.writes.isEmpty)
    }

    func testGuardsAndHungAppDoNotEnable() {
        _ = capturer.capture(request(processID: 1, mode: .off))

        reader.trusted = false
        _ = capturer.capture(request(processID: 2))
        reader.trusted = true

        reader.secureInput = true
        _ = capturer.capture(request(processID: 3))
        reader.secureInput = false

        _ = capturer.capture(
            request(processID: 4, bundleId: "com.microsoft.VSCode")
        )

        reader.app.errors[kAXFocusedUIElementAttribute] = .timeout
        _ = capturer.capture(request(processID: 5))

        XCTAssertTrue(reader.writes.isEmpty)
    }

    func testDetectorLooksForElectronFrameworkInBundle() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        directories.append(root)
        let electron = root.appendingPathComponent("Slack.app")
        let native = root.appendingPathComponent("Notes.app")
        try FileManager.default.createDirectory(
            at: electron.appendingPathComponent(
                "Contents/Frameworks/Electron Framework.framework"
            ),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: native.appendingPathComponent("Contents/Frameworks"),
            withIntermediateDirectories: true
        )

        XCTAssertTrue(ElectronAppDetector.isElectronApp(electron))
        XCTAssertFalse(ElectronAppDetector.isElectronApp(native))
    }

    private func request(
        processID: pid_t,
        mode: AccessibilityContextMode = .field,
        bundleId: String = "com.tinyspeck.slackmacgap",
        bundleURL: URL? = ElectronAccessibilityEnablerTests.slack
    ) -> AccessibilityContextRequest {
        AccessibilityContextRequest(
            mode: mode,
            processID: processID,
            appName: "Slack",
            bundleId: bundleId,
            bundleURL: bundleURL
        )
    }
}
