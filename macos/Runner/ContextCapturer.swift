import Cocoa
import Carbon
import os.log

/// Handles capturing text for context storage
class ContextCapturer {
    private let logger = OSLog(
        subsystem: "com.makeitsoundnatural.macos",
        category: "ContextCapturer"
    )

    weak var delegate: ContextCapturerDelegate?

    func captureAndStoreContext(replace: Bool) {
        log("captureAndStoreContext triggered (replace: \(replace))")

        guard AccessibilityHelper.checkPermissions() else {
            delegate?.contextCapturer(self, didFailWithError: "Accessibility permissions missing")
            return
        }

        let editabilityResult = AccessibilityHelper.checkFocusedElementIsEditable()
        guard editabilityResult.isEditable else {
            log("Focused element is not editable: \(editabilityResult.reason ?? "unknown")")
            delegate?.contextCapturer(
                self,
                didFailWithNotEditable: editabilityResult.reason ?? "Focus on a text field"
            )
            return
        }

        showProcessingBubble()
        performCapture(replace: replace)
    }

    private func showProcessingBubble() {
        DispatchQueue.main.async {
            let cursorPosition = NSEvent.mouseLocation
            StatusBubble.shared.show(at: cursorPosition, state: .processing)
        }
    }

    private func performCapture(replace: Bool) {
        ClipboardService.captureSelectedText(
            simulateKeyPress: { [weak self] in
                self?.simulateKeyPress(keyCode: CGKeyCode(kVK_ANSI_C), flags: .maskCommand)
            },
            completion: { [weak self] captureResult in
                guard let self = self else { return }

                if let old = captureResult.previousContent {
                    ClipboardService.restore(old)
                }

                guard let selectedText = captureResult.text, !selectedText.isEmpty else {
                    self.delegate?.contextCapturer(self, didFailWithError: "No text selected or copy failed")
                    StatusBubble.shared.hide()
                    return
                }

                self.delegate?.contextCapturer(self, didCaptureText: selectedText, replace: replace)
                StatusBubble.shared.updateState(.success)
            }
        )
    }

    private func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = flags
        keyUp?.flags = flags

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func log(_ message: String) {
        os_log("%{private}@", log: logger, type: .debug, message)
        #if DEBUG
        let timestamp = Date().timeIntervalSince1970
        print("⏱️ [\(String(format: "%.3f", timestamp))] \(message)")
        #endif
    }
}

protocol ContextCapturerDelegate: AnyObject {
    func contextCapturer(_ capturer: ContextCapturer, didCaptureText text: String, replace: Bool)
    func contextCapturer(_ capturer: ContextCapturer, didFailWithError error: String)
    func contextCapturer(_ capturer: ContextCapturer, didFailWithNotEditable reason: String)
}
