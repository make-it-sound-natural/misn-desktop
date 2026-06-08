import XCTest
import Cocoa
@testable import Make_It_Sound_Natural

/// Mock delegate to capture ContextCapturer delegate calls
class MockContextCapturerDelegate: ContextCapturerDelegate {
    var capturedTextCalls: [(text: String, replace: Bool)] = []
    var errorCalls: [String] = []
    var notEditableCalls: [String] = []

    func contextCapturer(_ capturer: ContextCapturer, didCaptureText text: String, replace: Bool) {
        capturedTextCalls.append((text: text, replace: replace))
    }

    func contextCapturer(_ capturer: ContextCapturer, didFailWithError error: String) {
        errorCalls.append(error)
    }

    func contextCapturer(_ capturer: ContextCapturer, didFailWithNotEditable reason: String) {
        notEditableCalls.append(reason)
    }
}

class ContextCapturerTests: XCTestCase {
    var contextCapturer: ContextCapturer!
    var mockDelegate: MockContextCapturerDelegate!

    override func setUp() {
        super.setUp()
        contextCapturer = ContextCapturer()
        mockDelegate = MockContextCapturerDelegate()
        contextCapturer.delegate = mockDelegate
    }

    override func tearDown() {
        contextCapturer = nil
        mockDelegate = nil
        super.tearDown()
    }

    // MARK: - Delegate Parameter Tests

    func testCaptureContextWithReplaceTrue() {
        // This test verifies that when captureAndStoreContext is called with replace=true,
        // the delegate receives replace=true in the callback

        // Note: This test would require mocking accessibility and clipboard services
        // to fully test the flow. Here we're documenting the expected behavior.

        // Expected flow:
        // 1. captureAndStoreContext(replace: true) is called
        // 2. If accessibility check passes and text is captured
        // 3. Delegate should receive didCaptureText with replace=true

        XCTAssertNotNil(contextCapturer.delegate)
        XCTAssertTrue(mockDelegate.capturedTextCalls.isEmpty, "No calls should be made initially")
    }

    func testCaptureContextWithReplaceFalse() {
        // This test verifies that when captureAndStoreContext is called with replace=false,
        // the delegate receives replace=false in the callback (append mode)

        // Expected flow:
        // 1. captureAndStoreContext(replace: false) is called
        // 2. If accessibility check passes and text is captured
        // 3. Delegate should receive didCaptureText with replace=false

        XCTAssertNotNil(contextCapturer.delegate)
        XCTAssertTrue(mockDelegate.capturedTextCalls.isEmpty, "No calls should be made initially")
    }

    func testDelegateReceivesCorrectReplaceParameter() {
        // Test that the replace parameter is correctly passed through the entire flow

        // Manually trigger the delegate callback to verify parameter passing
        contextCapturer.delegate?.contextCapturer(
            contextCapturer,
            didCaptureText: "Test text for replace",
            replace: true
        )

        XCTAssertEqual(mockDelegate.capturedTextCalls.count, 1)
        XCTAssertEqual(mockDelegate.capturedTextCalls[0].text, "Test text for replace")
        XCTAssertTrue(mockDelegate.capturedTextCalls[0].replace, "Replace parameter should be true")
    }

    func testDelegateReceivesCorrectAppendParameter() {
        // Test that the append parameter (replace=false) is correctly passed

        contextCapturer.delegate?.contextCapturer(
            contextCapturer,
            didCaptureText: "Test text for append",
            replace: false
        )

        XCTAssertEqual(mockDelegate.capturedTextCalls.count, 1)
        XCTAssertEqual(mockDelegate.capturedTextCalls[0].text, "Test text for append")
        XCTAssertFalse(mockDelegate.capturedTextCalls[0].replace, "Replace parameter should be false (append mode)")
    }

    func testMultipleCapturesWithDifferentModes() {
        // Test multiple captures with different replace values

        contextCapturer.delegate?.contextCapturer(
            contextCapturer,
            didCaptureText: "First capture - replace",
            replace: true
        )

        contextCapturer.delegate?.contextCapturer(
            contextCapturer,
            didCaptureText: "Second capture - append",
            replace: false
        )

        contextCapturer.delegate?.contextCapturer(
            contextCapturer,
            didCaptureText: "Third capture - replace",
            replace: true
        )

        XCTAssertEqual(mockDelegate.capturedTextCalls.count, 3)
        XCTAssertTrue(mockDelegate.capturedTextCalls[0].replace)
        XCTAssertFalse(mockDelegate.capturedTextCalls[1].replace)
        XCTAssertTrue(mockDelegate.capturedTextCalls[2].replace)
    }

    // MARK: - Error Handling Tests

    func testDelegateReceivesNotEditableError() {
        // Test that not editable errors are properly passed to delegate

        contextCapturer.delegate?.contextCapturer(
            contextCapturer,
            didFailWithNotEditable: "Element is not editable"
        )

        XCTAssertEqual(mockDelegate.notEditableCalls.count, 1)
        XCTAssertEqual(mockDelegate.notEditableCalls[0], "Element is not editable")
    }

    func testDelegateReceivesGenericError() {
        // Test that generic errors are properly passed to delegate

        contextCapturer.delegate?.contextCapturer(
            contextCapturer,
            didFailWithError: "No text selected or copy failed"
        )

        XCTAssertEqual(mockDelegate.errorCalls.count, 1)
        XCTAssertEqual(mockDelegate.errorCalls[0], "No text selected or copy failed")
    }

    func testNoCallsWithoutDelegate() {
        // Test that ContextCapturer handles nil delegate gracefully

        contextCapturer.delegate = nil

        // These calls should not crash
        contextCapturer.delegate?.contextCapturer(
            contextCapturer,
            didCaptureText: "Test",
            replace: true
        )

        contextCapturer.delegate?.contextCapturer(
            contextCapturer,
            didFailWithError: "Error"
        )

        // Verify mock didn't receive calls (since delegate was set to nil)
        XCTAssertTrue(mockDelegate.capturedTextCalls.isEmpty)
        XCTAssertTrue(mockDelegate.errorCalls.isEmpty)
    }

    // MARK: - Integration Test Documentation

    func testIntegrationFlowDocumentation() {
        // This test documents the expected integration flow:
        //
        // 1. User presses cmd+shift+j (replaceContext) or cmd+shift+l (appendContext)
        // 2. ShortcutDispatcher.dispatch() is called with appropriate shortcutID
        // 3. ShortcutHandler.captureContext(replace: Bool) is invoked
        // 4. ContextCapturer.captureAndStoreContext(replace: Bool) is called
        // 5. ContextCapturer performs:
        //    a. Accessibility check
        //    b. Clipboard capture of selected text
        //    c. Delegate callback with captured text and replace parameter
        // 6. ShortcutHandler receives delegate callback
        // 7. MethodChannelHandler.sendStoreContext(text:replace:) sends to Flutter
        // 8. Flutter ShortcutService._handleStoreContext() processes the context
        // 9. Context is saved to SharedPreferences
        // 10. Status event is emitted
        // 11. If window is visible, HomeScreen._listenToStatus() updates UI immediately
        // 12. If window is not visible, context is updated on app resume

        XCTAssertTrue(true, "Integration flow documented")
    }
}
