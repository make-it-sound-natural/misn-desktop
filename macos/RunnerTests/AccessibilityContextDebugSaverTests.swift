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

    private func save(
        _ saver: AccessibilityContextDebugSaver,
        _ result: AccessibilityContextResult,
        screenshotMode: ScreenshotContextMode
    ) -> URL? {
        saver.saveIfEnabled(
            result: result,
            decision: ContextSourcePolicy.decide(
                accessibility: result,
                screenshotMode: screenshotMode
            ),
            screenshotTaken: screenshotMode != .off
        )
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

        let savedURL = save(
            saver,
            .usable(usableContext()),
            screenshotMode: .off
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

        let savedURL = save(
            saver,
            .usable(context),
            screenshotMode: .off
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
        XCTAssertEqual(screenshot["reason"] as? String, "screenshotOff")
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

        let savedURL = save(
            saver,
            .unusable(.windowOrApplicationRole, partial: partial),
            screenshotMode: .activeApplication
        )

        let entry = try json(at: XCTUnwrap(savedURL))
        XCTAssertEqual(entry["usable"] as? Bool, false)
        XCTAssertEqual(entry["unusableReason"] as? String, "windowOrApplicationRole")
        XCTAssertEqual(entry["mode"] as? String, "field")
        XCTAssertEqual(entry["role"] as? String, "AXWindow")
        XCTAssertNil(entry["subrole"])
        XCTAssertNil(entry["appContext"])
        XCTAssertNil(entry["nearby"])
        XCTAssertEqual(entry["requestedManualAccessibility"] as? Bool, true)
        let screenshot = try XCTUnwrap(entry["screenshot"] as? [String: Any])
        XCTAssertEqual(screenshot["taken"] as? Bool, true)
        XCTAssertEqual(screenshot["reason"] as? String, "accessibilityUnusable")
    }

    func testResponseIsAddedToTheSavedRun() throws {
        let saver = AccessibilityContextDebugSaver(
            environment: enabled,
            outputDirectory: makeDirectory()
        )
        var context = usableContext()
        context.fieldCharacterCount = 42
        context.fieldSelection = NSRange(location: 9, length: 6)
        context.fieldFrame = CGRect(x: 10, y: 700, width: 800, height: 40)
        let url = try XCTUnwrap(save(saver, .usable(context), screenshotMode: .off))

        saver.addResponse(
            .init(
                selectedText: "review",
                model: "gpt-5-mini",
                fullContent: "{\"balanced\":\"check\"}",
                selectedVariant: "check",
                error: nil
            ),
            to: url
        )

        let entry = try json(at: url)
        let field = try XCTUnwrap(entry["field"] as? [String: Any])
        XCTAssertEqual(field["characterCount"] as? Int, 42)
        XCTAssertEqual(field["selectedRange"] as? [Int], [9, 6])
        XCTAssertEqual(field["readWhole"] as? Bool, false)
        XCTAssertEqual(field["frame"] as? [Double], [10, 700, 800, 40])
        let response = try XCTUnwrap(entry["response"] as? [String: Any])
        XCTAssertEqual(response["selectedText"] as? String, "review")
        XCTAssertEqual(response["model"] as? String, "gpt-5-mini")
        XCTAssertEqual(response["selectedVariant"] as? String, "check")
        XCTAssertNil(response["error"])
        XCTAssertNotNil(entry["appContext"])
    }

    func testResponseForAnOlderRunIsDropped() throws {
        var clock = Date(timeIntervalSince1970: 1_700_000_000)
        let saver = AccessibilityContextDebugSaver(
            environment: enabled,
            outputDirectory: makeDirectory(),
            now: {
                clock.addTimeInterval(1)
                return clock
            }
        )
        let first = try XCTUnwrap(
            save(saver, .usable(usableContext()), screenshotMode: .off)
        )
        _ = save(saver, .usable(usableContext()), screenshotMode: .off)

        saver.addResponse(
            .init(
                selectedText: "review",
                model: "gpt-5-mini",
                fullContent: nil,
                selectedVariant: nil,
                error: "timeout"
            ),
            to: first
        )

        XCTAssertNil(try json(at: first)["response"])
    }

    /// The whole message selected: no field text, but the source is sent.
    func testUnusableRunThatKeepsItsSourceRecordsTheSentBlock() throws {
        var partial = AccessibilityContext(
            mode: .field,
            appName: "Slack",
            bundleId: "com.tinyspeck.slackmacgap"
        )
        partial.fieldLabel = "Message #design"
        let saver = AccessibilityContextDebugSaver(
            environment: enabled,
            outputDirectory: makeDirectory()
        )

        let savedURL = save(
            saver,
            .unusable(.noSurroundingText, partial: partial),
            screenshotMode: .off
        )

        let entry = try json(at: XCTUnwrap(savedURL))
        XCTAssertEqual(entry["usable"] as? Bool, false)
        XCTAssertEqual(entry["unusableReason"] as? String, "noSurroundingText")
        let block = try XCTUnwrap(PromptTemplates.appContextSection(partial))
        XCTAssertEqual(entry["appContext"] as? String, block)
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
                save(
                    saver,
                    .usable(usableContext()),
                    screenshotMode: .off
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

        let savedURL = save(
            saver,
            .usable(usableContext()),
            screenshotMode: .off
        )

        let url = try XCTUnwrap(savedURL)
        XCTAssertEqual(
            url.deletingLastPathComponent().resolvingSymlinksInPath(),
            directory.resolvingSymlinksInPath()
        )
    }
}
