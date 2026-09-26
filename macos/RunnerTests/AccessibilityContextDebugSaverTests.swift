import XCTest
@testable import Make_It_Sound_Natural

final class AccessibilityContextDebugSaverTests: XCTestCase {
    private let enabled = ["MISN_SAVE_ACCESSIBILITY_CONTEXT": "1"]
    private var directories: [URL] = []

    override func tearDown() {
        for directory in directories {
            try? FileManager.default.removeItem(at: directory)
        }
        directories = []
        super.tearDown()
    }

    private func makeDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        directories.append(directory)
        return directory
    }

    private func usableContext() -> AccessibilityContext {
        var context = AccessibilityContext(
            mode: .fieldAndNearby,
            appName: "Slack",
            bundleId: "com.tinyspeck.slackmacgap"
        )
        context.role = "AXTextArea"
        context.subrole = "AXContentList"
        context.windowTitle = "#design - AdGuard"
        context.fieldLabel = "Message #design"
        context.textBeforeSelection = "Hi team, "
        context.textAfterSelection = " Thanks!"
        context.nearbyText = "Anna: is the draft ready?"
        context.nearbyWalk = NearbyTextWalk(nodesVisited: 12, cutoff: nil)
        context.timings = AccessibilityContext.Timings(
            focusedElement: 1.5,
            metadata: 2.5,
            excerpt: 3.5,
            nearby: 4.5,
            total: 12.5
        )
        return context
    }

    private func json(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }

    func testDisabledSaverDoesNotWriteFile() {
        let directory = makeDirectory()
        let saver = AccessibilityContextDebugSaver(
            environment: [:],
            outputDirectory: directory
        )

        let savedURL = saver.saveIfEnabled(
            result: .usable(usableContext()),
            screenshotTaken: false,
            screenshotReason: "ax_nearby_text"
        )

        XCTAssertNil(savedURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testEnabledSaverWritesUsableRunAsJSON() throws {
        let directory = makeDirectory()
        let saver = AccessibilityContextDebugSaver(
            environment: enabled,
            outputDirectory: directory
        )
        let context = usableContext()

        let savedURL = saver.saveIfEnabled(
            result: .usable(context),
            screenshotTaken: false,
            screenshotReason: "ax_nearby_text"
        )

        let url = try XCTUnwrap(savedURL)
        XCTAssertTrue(url.lastPathComponent.hasSuffix("-fieldAndNearby.json"))
        let entry = try json(at: url)
        XCTAssertEqual(entry["app"] as? String, "Slack")
        XCTAssertEqual(
            entry["bundleId"] as? String,
            "com.tinyspeck.slackmacgap"
        )
        XCTAssertEqual(entry["role"] as? String, "AXTextArea")
        XCTAssertEqual(entry["subrole"] as? String, "AXContentList")
        XCTAssertEqual(entry["mode"] as? String, "fieldAndNearby")
        XCTAssertEqual(entry["usable"] as? Bool, true)
        XCTAssertNil(entry["unusableReason"])
        XCTAssertEqual(
            entry["timingsMs"] as? [String: Double],
            [
                "focusedElement": 1.5,
                "metadata": 2.5,
                "excerpt": 3.5,
                "nearby": 4.5,
                "total": 12.5
            ]
        )
        let nearby = try XCTUnwrap(entry["nearby"] as? [String: Any])
        XCTAssertEqual(nearby["textLength"] as? Int, 25)
        XCTAssertEqual(nearby["nodesVisited"] as? Int, 12)
        XCTAssertNil(nearby["cutoff"])
        XCTAssertEqual(entry["requestedManualAccessibility"] as? Bool, false)
        let screenshot = try XCTUnwrap(entry["screenshot"] as? [String: Any])
        XCTAssertEqual(screenshot["taken"] as? Bool, false)
        XCTAssertEqual(screenshot["reason"] as? String, "ax_nearby_text")
        let parts = try XCTUnwrap(entry["parts"] as? [String: String])
        XCTAssertEqual(parts["windowTitle"], "#design - AdGuard")
        XCTAssertEqual(parts["fieldLabel"], "Message #design")
        XCTAssertEqual(parts["textBeforeSelection"], "Hi team, ")
        XCTAssertEqual(parts["textAfterSelection"], " Thanks!")
        XCTAssertEqual(parts["nearbyText"], "Anna: is the draft ready?")
        let block = try XCTUnwrap(PromptTemplates.appContextSection(context))
        XCTAssertEqual(entry["appContext"] as? String, block)
    }

    func testEnabledSaverWritesUnusableRunWithReasonAndNoBlock() throws {
        var partial = AccessibilityContext(
            mode: .field,
            appName: "Visual Studio Code",
            bundleId: "com.microsoft.VSCode"
        )
        partial.role = "AXWindow"
        partial.requestedManualAccessibility = true
        let saver = AccessibilityContextDebugSaver(
            environment: enabled,
            outputDirectory: makeDirectory()
        )

        let savedURL = saver.saveIfEnabled(
            result: .unusable(.codeEditor, partial: partial),
            screenshotTaken: true,
            screenshotReason: "ax_unusable"
        )

        let entry = try json(at: XCTUnwrap(savedURL))
        XCTAssertEqual(entry["usable"] as? Bool, false)
        XCTAssertEqual(entry["unusableReason"] as? String, "codeEditor")
        XCTAssertEqual(entry["mode"] as? String, "field")
        XCTAssertEqual(entry["role"] as? String, "AXWindow")
        XCTAssertNil(entry["subrole"])
        XCTAssertNil(entry["appContext"])
        XCTAssertNil(entry["nearby"])
        XCTAssertEqual(entry["requestedManualAccessibility"] as? Bool, true)
        let screenshot = try XCTUnwrap(entry["screenshot"] as? [String: Any])
        XCTAssertEqual(screenshot["taken"] as? Bool, true)
        XCTAssertEqual(screenshot["reason"] as? String, "ax_unusable")
    }

    func testSaverKeepsLatestFilesOnly() throws {
        let directory = makeDirectory()
        var clock = Date(timeIntervalSince1970: 1_700_000_000)
        let saver = AccessibilityContextDebugSaver(
            environment: enabled,
            outputDirectory: directory,
            maxFiles: 2,
            now: {
                clock.addTimeInterval(1)
                return clock
            }
        )

        let urls = try (0..<3).map { _ in
            try XCTUnwrap(
                saver.saveIfEnabled(
                    result: .usable(usableContext()),
                    screenshotTaken: false,
                    screenshotReason: "ax_nearby_text"
                )
            )
        }

        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(files.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: urls[0].path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: urls[1].path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: urls[2].path))
    }

    func testDirectoryEnvironmentVariableOverridesDefaultLocation() throws {
        let directory = makeDirectory()
        let saver = AccessibilityContextDebugSaver(
            environment: enabled.merging(
                ["MISN_ACCESSIBILITY_CONTEXT_DIR": directory.path]
            ) { $1 }
        )

        let savedURL = saver.saveIfEnabled(
            result: .usable(usableContext()),
            screenshotTaken: false,
            screenshotReason: "ax_nearby_text"
        )

        let url = try XCTUnwrap(savedURL)
        XCTAssertEqual(
            url.deletingLastPathComponent().resolvingSymlinksInPath(),
            directory.resolvingSymlinksInPath()
        )
    }
}
