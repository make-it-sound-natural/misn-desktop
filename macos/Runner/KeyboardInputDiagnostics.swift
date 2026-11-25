import Carbon
import Cocoa
import os.log

/// Records where key presses get lost when typing stops working.
///
/// A focused text field that ignores the keyboard leaves no trace by itself,
/// and restarting the app clears the state. This writes one line to the
/// unified log when it happens, at a level macOS keeps on disk:
///
/// ```sh
/// log show --last 1h --predicate \
///   'subsystem == "com.makeitsoundnatural.macos" AND category == "Keyboard"'
/// ```
///
/// Key codes and characters are never recorded: the fields this watches
/// include API keys.
final class KeyboardInputDiagnostics {
    private let logger = OSLog(
        subsystem: AppDefaults.logSubsystem,
        category: "Keyboard"
    )
    private let launchedAt = Date()
    private weak var flutterWindow: NSWindow?
    private var deliveryMonitor = KeyDeliveryMonitor()
    private var eventMonitor: Any?
    private var stallCheckTimer: Timer?

    init(flutterWindow: NSWindow) {
        self.flutterWindow = flutterWindow
        // Every window is watched, not just the Flutter one: key presses that
        // land in another window are one of the failures to tell apart.
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            self?.recordKeyDown()
            return event
        }
    }

    deinit {
        stallCheckTimer?.invalidate()
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    /// Dart received the key presses sent so far.
    func acknowledgeKeyEvents() {
        deliveryMonitor.recordAcknowledgement()
    }

    /// Dart receives key presses, but the focused field's text stays as is.
    func reportTextInputStall(keyPresses: Int, lifecycleState: String) {
        log(
            "Text is not reaching the focused field: \(keyPresses) " +
                "printable key presses changed nothing. " +
                "lifecycle=\(lifecycleState)"
        )
    }

    private func recordKeyDown() {
        // Closing the window only orders it out and leaves the app active, so
        // key presses still arrive here. There is no field for them to miss.
        guard flutterWindow?.isVisible == true else {
            return
        }
        deliveryMonitor.recordKeyDown(at: Date())
        checkForStall()
    }

    private func checkForStall() {
        let now = Date()
        if let stall = deliveryMonitor.takeStall(at: now) {
            log(
                "Key presses are not reaching Flutter: " +
                    "\(stall.keyPresses) unacknowledged " +
                    "in \(Int(stall.duration))s."
            )
            return
        }
        // Someone who types a word and stops sends no further key-down to
        // check on, so the deadline needs a timer.
        guard stallCheckTimer == nil,
              let deadline = deliveryMonitor.stallDeadline,
              deadline > now else {
            return
        }
        stallCheckTimer = Timer.scheduledTimer(
            withTimeInterval: deadline.timeIntervalSince(now),
            repeats: false
        ) { [weak self] _ in
            self?.stallCheckTimer = nil
            self?.checkForStall()
        }
    }

    private func log(_ message: String) {
        os_log(
            "%{public}@ %{public}@",
            log: logger,
            type: .default,
            message,
            stateDescription()
        )
    }

    private func stateDescription() -> String {
        let keyWindow = NSApp.keyWindow
        let inputContextClient = NSTextInputContext.current.map {
            typeName($0.client)
        }
        return [
            "appActive=\(NSApp.isActive)",
            "keyWindow=\(typeName(keyWindow))",
            "flutterWindowIsKey=\(flutterWindow?.isKeyWindow ?? false)",
            "flutterWindowVisible=\(flutterWindow?.isVisible ?? false)",
            "firstResponder=\(typeName(keyWindow?.firstResponder))",
            "inputContextClient=\(inputContextClient ?? "none")",
            "inputSource=\(currentInputSourceID() ?? "unknown")",
            "secureInput=\(IsSecureEventInputEnabled())",
            "uptime=\(Int(Date().timeIntervalSince(launchedAt)))s"
        ].joined(separator: " ")
    }

    private func typeName(_ value: Any?) -> String {
        value.map { String(describing: type(of: $0)) } ?? "none"
    }

    private func currentInputSourceID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?
            .takeRetainedValue(),
            let property = TISGetInputSourceProperty(
                source,
                kTISPropertyInputSourceID
            ) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(property)
            .takeUnretainedValue() as String
    }
}
