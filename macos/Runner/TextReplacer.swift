import Cocoa
import Carbon
import os.log

/// Handles text replacement in the original application
class TextReplacer {
    private let logger = OSLog(
        subsystem: "com.makeitsoundnatural.macos",
        category: "TextReplacer"
    )

    /// Confirms our paste is still at the caret in [app].
    ///
    /// Injectable so the guard around Cmd+Z can be tested without a second
    /// application on screen: a wrong `true` here destroys the user's text.
    typealias PasteVerifier = (String, NSRunningApplication) -> Bool

    /// Performs the undo-and-paste keystrokes.
    typealias Replacer = (String) -> Void

    private let verifyPaste: PasteVerifier
    private let performReplacementImpl: Replacer?

    /// - Parameters:
    ///   - verifyPaste: defaults to the real Accessibility check.
    ///   - performReplacement: defaults to the real keystroke simulation.
    init(
        verifyPaste: @escaping PasteVerifier = {
            AccessibilityHelper.focusedTextEndsWith($0, for: $1)
        },
        performReplacement: Replacer? = nil
    ) {
        self.verifyPaste = verifyPaste
        self.performReplacementImpl = performReplacement
    }

    /// Replaces this app's own previous paste in the app it came from.
    ///
    /// The undo keystroke is only safe while the text we pasted is still the
    /// last thing before the caret. If the user has typed, deleted, or moved
    /// focus since, the undo would destroy their work, so the replacement is
    /// abandoned instead and the caller falls back to the clipboard.
    /// - Returns: whether the replacement was performed, via [completion].
    func replaceTextInOriginalApp(
        _ text: String,
        lastActiveAppBundleId: String?,
        previouslyPastedText: String?,
        completion: @escaping (Bool) -> Void
    ) {
        // Every exit reports on the main queue: this completion is wired to a
        // `FlutterResult`, which must be invoked on the platform thread, and
        // the caller records the outcome in state owned by that queue.
        let finish: (Bool, String) -> Void = { [self] replaced, reason in
            log(reason)
            DispatchQueue.main.async { completion(replaced) }
        }

        log("replaceTextInOriginalApp triggered")
        guard let bundleId = lastActiveAppBundleId else {
            finish(false, "Skipped: no previous app tracked")
            return
        }
        guard let pasted = previouslyPastedText, !pasted.isEmpty else {
            finish(false, "Skipped: this app has not pasted into \(bundleId)")
            return
        }

        DispatchQueue.main.async {
            guard let app = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleId
            ).first else {
                finish(false, "Skipped: original app is no longer running")
                return
            }

            self.log("Activating app: \(bundleId)")
            app.activate(options: .activateIgnoringOtherApps)

            // The verification makes blocking AX calls into another process,
            // which can stall for as long as that process is busy. Keep it
            // off the main thread — that is the same thread servicing the
            // method channel this call is replying to.
            DispatchQueue.global(qos: .userInitiated)
                .asyncAfter(deadline: .now() + 0.1) {
                    guard self.verifyPaste(pasted, app) else {
                        finish(
                            false,
                            "Skipped: our paste is no longer at the caret in "
                                + bundleId
                        )
                        return
                    }

                    self.performReplacement(text)
                    finish(true, "Replacement performed")
                }
        }
    }

    private func performReplacement(_ text: String) {
        if let override = performReplacementImpl {
            override(text)
            return
        }
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
