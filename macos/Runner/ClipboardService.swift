import Cocoa
import os.log

/// Service for capturing and managing clipboard operations
class ClipboardService {
    struct CaptureResult {
        let text: String?
        let previousContent: String?
        let previousChangeCount: Int
    }

    private static let logger = OSLog(
        subsystem: "com.makeitsoundnatural.macos",
        category: "ClipboardService"
    )

    /// Captures currently selected text by simulating Cmd+C
    /// - Parameters:
    ///   - timeout: Maximum number of attempts to wait for clipboard update (default: 20)
    ///   - simulateKeyPress: Function to simulate the Cmd+C key press
    ///   - completion: Callback with the capture result (called on main thread)
    /// - Note: All NSPasteboard operations are performed on the main thread to avoid
    ///         thread-safety issues that can cause crashes when Flutter accesses the
    ///         clipboard simultaneously.
    static func captureSelectedText(
        timeout: Int = 20,
        simulateKeyPress: @escaping () -> Void,
        completion: @escaping (CaptureResult) -> Void
    ) {
        // NSPasteboard is NOT thread-safe. All access must be on main thread.
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            let oldString = pasteboard.string(forType: .string)
            let oldChangeCount = pasteboard.changeCount

            log("Simulating Cmd+C")
            simulateKeyPress()

            // Poll for clipboard changes on a background thread to avoid blocking main thread
            DispatchQueue.global(qos: .userInitiated).async {
                var attempts = 0
                var newContent: String?
                let startTime = Date()

                while attempts < timeout {
                    usleep(50000)

                    // Check clipboard on main thread
                    var currentChangeCount: Int = 0
                    var currentContent: String?
                    let semaphore = DispatchSemaphore(value: 0)

                    DispatchQueue.main.async {
                        let pasteboard = NSPasteboard.general
                        currentChangeCount = pasteboard.changeCount
                        if currentChangeCount != oldChangeCount {
                            currentContent = pasteboard.string(forType: .string)
                        }
                        semaphore.signal()
                    }

                    semaphore.wait()

                    if currentChangeCount != oldChangeCount {
                        newContent = currentContent
                        let elapsed = Date().timeIntervalSince(startTime)
                        DispatchQueue.main.async {
                            log("Clipboard updated after \(String(format: "%.3f", elapsed))s")
                        }
                        break
                    }
                    attempts += 1
                }

                if newContent == nil {
                    DispatchQueue.main.async {
                        log("Clipboard timeout after \(timeout) attempts")
                    }
                }

                let result = CaptureResult(
                    text: newContent,
                    previousContent: oldString,
                    previousChangeCount: oldChangeCount
                )

                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
    }

    /// Restores text to the clipboard
    /// - Parameter text: The text to restore to the clipboard
    /// - Note: Dispatches to main thread if not already on it for thread safety
    static func restore(_ text: String) {
        if Thread.isMainThread {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        } else {
            DispatchQueue.main.async {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            }
        }
    }

    /// Sets content in the clipboard
    /// - Parameter text: The text to set in the clipboard
    /// - Note: Dispatches to main thread if not already on it for thread safety
    static func setContent(_ text: String) {
        if Thread.isMainThread {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        } else {
            DispatchQueue.main.async {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            }
        }
    }

    private static func log(_ message: String) {
        os_log("%{private}@", log: logger, type: .debug, message)
        #if DEBUG
        let timestamp = Date().timeIntervalSince1970
        print("⏱️ [\(String(format: "%.3f", timestamp))] \(message)")
        #endif
    }
}
