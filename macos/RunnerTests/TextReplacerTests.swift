import Cocoa
import XCTest

@testable import Make_It_Sound_Natural

/// Covers the contract around the Cmd+Z path.
///
/// Two rules matter: `completion` fires exactly once on every route, and no
/// route that reports `false` may reach the keystroke simulation — a stray
/// undo lands in a document this app did not write.
final class TextReplacerTests: XCTestCase {

    /// The test host is itself a running application, so its own bundle id is
    /// the one value guaranteed to resolve to an `NSRunningApplication`.
    private var ownBundleId: String {
        Bundle.main.bundleIdentifier ?? "com.apple.dt.xctest.tool"
    }

    private func run(
        bundleId: String?,
        previouslyPasted: String?,
        verifierResult: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (replaced: Bool, replacementCalls: [String]) {
        var replacementCalls: [String] = []
        let replacer = TextReplacer(
            verifyPaste: { _, _ in verifierResult },
            performReplacement: { replacementCalls.append($0) }
        )

        var results: [Bool] = []
        let done = expectation(description: "completion")
        done.expectedFulfillmentCount = 1
        // A second call would over-fulfil and fail the test.
        done.assertForOverFulfill = true

        replacer.replaceTextInOriginalApp(
            "replacement",
            lastActiveAppBundleId: bundleId,
            previouslyPastedText: previouslyPasted
        ) { replaced in
            results.append(replaced)
            done.fulfill()
        }

        wait(for: [done], timeout: 5)
        XCTAssertEqual(results.count, 1, "completion must fire once", file: file, line: line)
        return (results.first ?? false, replacementCalls)
    }

    func testNoTrackedAppSkipsAndReports() {
        let outcome = run(bundleId: nil, previouslyPasted: "hello")

        XCTAssertFalse(outcome.replaced)
        XCTAssertTrue(outcome.replacementCalls.isEmpty, "must not send Cmd+Z")
    }

    func testNothingPastedByUsSkipsAndReports() {
        let outcome = run(bundleId: ownBundleId, previouslyPasted: nil)

        XCTAssertFalse(outcome.replaced)
        XCTAssertTrue(outcome.replacementCalls.isEmpty)
    }

    func testEmptyPreviousPasteSkipsAndReports() {
        let outcome = run(bundleId: ownBundleId, previouslyPasted: "")

        XCTAssertFalse(outcome.replaced)
        XCTAssertTrue(outcome.replacementCalls.isEmpty)
    }

    func testAppNoLongerRunningSkipsAndReports() {
        let outcome = run(
            bundleId: "com.example.definitely.not.running",
            previouslyPasted: "hello"
        )

        XCTAssertFalse(outcome.replaced)
        XCTAssertTrue(outcome.replacementCalls.isEmpty)
    }

    func testFailedVerificationSkipsAndReports() {
        // The user typed since our paste: undoing would eat their edit.
        let outcome = run(
            bundleId: ownBundleId,
            previouslyPasted: "hello",
            verifierResult: false
        )

        XCTAssertFalse(outcome.replaced)
        XCTAssertTrue(outcome.replacementCalls.isEmpty)
    }

    func testVerifiedPasteIsReplacedOnce() {
        let outcome = run(
            bundleId: ownBundleId,
            previouslyPasted: "hello",
            verifierResult: true
        )

        XCTAssertTrue(outcome.replaced)
        XCTAssertEqual(outcome.replacementCalls, ["replacement"])
    }
}
