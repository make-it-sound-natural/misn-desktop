import XCTest
@testable import Make_It_Sound_Natural

class MockShortcutActionHandler: ShortcutActionHandler {
    var correctionCallCount = 0
    /// Captured `replace` arguments in call order.
    var captureContextCalls: [Bool] = []

    func performCorrection() {
        correctionCallCount += 1
    }

    func captureContext(replace: Bool) {
        captureContextCalls.append(replace)
    }
}

class ShortcutDispatchTests: XCTestCase {
    var dispatcher: ShortcutDispatcher!
    var mockHandler: MockShortcutActionHandler!

    override func setUp() {
        super.setUp()
        dispatcher = ShortcutDispatcher()
        mockHandler = MockShortcutActionHandler()
        dispatcher.actionHandler = mockHandler
    }

    func testCorrectionShortcutTriggersCorrection() {
        dispatcher.dispatch(shortcutID: ShortcutID.correction.rawValue)

        XCTAssertEqual(mockHandler.correctionCallCount, 1)
        XCTAssertTrue(mockHandler.captureContextCalls.isEmpty)
    }

    func testReplaceContextShortcutTriggersReplaceContext() {
        dispatcher.dispatch(shortcutID: ShortcutID.replaceContext.rawValue)

        XCTAssertEqual(mockHandler.correctionCallCount, 0)
        XCTAssertEqual(mockHandler.captureContextCalls.count, 1)
        XCTAssertTrue(mockHandler.captureContextCalls[0])
    }

    func testAppendContextShortcutTriggersAppendContext() {
        dispatcher.dispatch(shortcutID: ShortcutID.appendContext.rawValue)

        XCTAssertEqual(mockHandler.correctionCallCount, 0)
        XCTAssertEqual(mockHandler.captureContextCalls.count, 1)
        XCTAssertFalse(mockHandler.captureContextCalls[0])
    }

    func testUnknownShortcutIDDoesNothing() {
        dispatcher.dispatch(shortcutID: 999)

        XCTAssertEqual(mockHandler.correctionCallCount, 0)
        XCTAssertTrue(mockHandler.captureContextCalls.isEmpty)
    }
}
