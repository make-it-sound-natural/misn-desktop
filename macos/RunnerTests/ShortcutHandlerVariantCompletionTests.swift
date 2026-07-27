import XCTest
@testable import Make_It_Sound_Natural

/// Records calls for `StatusBubbleControlling` without a real `NSPanel`.
final class MockStatusBubble: StatusBubbleControlling {
    var hideCallCount = 0
    var showCallCount = 0
    var updateStateCallCount = 0

    func show(at position: NSPoint, state: StatusBubble.State) {
        showCallCount += 1
    }

    func hide() {
        hideCallCount += 1
    }

    func updateState(_ state: StatusBubble.State) {
        updateStateCallCount += 1
    }
}

final class ShortcutHandlerVariantCompletionTests: XCTestCase {

    /// Regression: success completion must not call `hide()`; the bubble already
    /// moved to `.success` via `VariantHandler` → `updateState`, which schedules
    /// auto-dismiss. A redundant `hide()` here raced the timer and dismissed too
    /// early.
    func testDidCompleteSuccessfullyTrueDoesNotHideBubble() {
        let bubble = MockStatusBubble()
        let handler = ShortcutHandler(
            methodChannelHandler: nil,
            statusBubble: bubble
        )

        handler.variantHandler(
            VariantHandler(),
            didCompleteSuccessfully: true,
            pastedText: "hello",
            inApp: "com.example.editor"
        )

        XCTAssertEqual(
            bubble.hideCallCount,
            0,
            "Success completion must not hide the bubble"
        )
    }

    func testDidCompleteSuccessfullyFalseDoesNotHideBubble() {
        let bubble = MockStatusBubble()
        let handler = ShortcutHandler(
            methodChannelHandler: nil,
            statusBubble: bubble
        )

        handler.variantHandler(
            VariantHandler(),
            didCompleteSuccessfully: false,
            pastedText: nil,
            inApp: nil
        )

        XCTAssertEqual(bubble.hideCallCount, 0)
    }
}
