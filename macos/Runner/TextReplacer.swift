import Cocoa
import Carbon
import os.log

/// Handles text replacement in the original application
class TextReplacer {
    private let logger = OSLog(
        subsystem: "com.makeitsoundnatural.macos",
        category: "TextReplacer"
    )

    func replaceTextInOriginalApp(_ text: String, lastActiveAppBundleId: String?) {
        log("replaceTextInOriginalApp triggered")
        guard let bundleId = lastActiveAppBundleId else {
            log("Error: No previous app tracked")
            return
        }

        DispatchQueue.main.async {
            guard let app = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleId
            ).first else {
                self.log("Error: Could not find original app")
                return
            }

            self.log("Activating app: \(bundleId)")
            app.activate(options: .activateIgnoringOtherApps)

            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) {
                self.performReplacement(text)
            }
        }
    }

    private func performReplacement(_ text: String) {
        log("Starting replacement sequence")

        log("Simulating Cmd+Z (Undo)")
        simulateKeyPress(keyCode: CGKeyCode(kVK_ANSI_Z), flags: .maskCommand)

        usleep(50000)

        ClipboardService.setContent(text)
        log("Clipboard updated with new text")

        log("Simulating Cmd+V (Paste)")
        simulateKeyPress(keyCode: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
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
