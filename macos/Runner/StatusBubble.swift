import Cocoa

/// A floating status bubble that appears near the cursor to show processing status.
/// Shows different states: processing (spinner), success (checkmark), or cancelled (X).
class StatusBubble: NSPanel {

    enum State: Equatable {
        case processing
        case success
        case cancelled
        case error(message: String)
    }

    // MARK: - Singleton

    static let shared = StatusBubble()

    // MARK: - UI Components

    let containerView = NSView()
    let spinnerView = NSProgressIndicator()
    let iconLabel = NSTextField(labelWithString: "")

    // App theme colors
    let primaryColor = NSColor(
        red: 0x8E/255.0,
        green: 0x24/255.0,
        blue: 0xAA/255.0,
        alpha: 1.0
    )
    // MARK: - Constants

    let bubbleSize: CGFloat = 44
    let dismissDelay: TimeInterval = 1.5
    let cursorOffset: CGFloat = 15

    // MARK: - State

    var dismissTimer: Timer?
    private(set) var currentState: State = .processing
    var mouseTrackingMonitor: Any?

    /// Incremented at the start of every `show` and `hide`. A `hide` animation
    /// completion only calls `orderOut` if this value still matches the session
    /// captured when that `hide` began—so a newer `show` invalidates stale
    /// completions (fixes panel staying hidden after dismiss then new error).
    private var surfaceLifecycleGeneration: UInt64 = 0

    // MARK: - Initialization

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 44, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        setupPanel()
        setupUI()
    }

    // MARK: - Public Methods

    /// Shows the bubble at the specified screen position with the given state.
    /// - Parameters:
    ///   - position: The screen position (typically mouse location)
    ///   - state: The initial state to display
    func show(at position: NSPoint, state: State = .processing) {
        #if DEBUG
        print("🟢 StatusBubble: show() called with state: \(state)")
        #endif
        surfaceLifecycleGeneration += 1
        dismissTimer?.invalidate()
        dismissTimer = nil

        // Position bubble near cursor
        updatePosition(to: position)

        updateState(state)

        // Show with fade-in animation
        alphaValue = 0
        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 1
        }

        // Start following mouse if processing
        if state == .processing {
            startMouseTracking()
        }
    }

    /// Updates the bubble state and schedules auto-dismiss for terminal states.
    /// - Parameter state: The new state to display
    func updateState(_ state: State) {
        #if DEBUG
        print("🟡 StatusBubble: updateState() to: \(state)")
        #endif
        currentState = state

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.updateBackgroundColor()

            switch state {
            case .processing:
                self.showProcessing()
                self.startMouseTracking()

            case .success:
                self.stopMouseTracking()
                self.showSuccess()
                self.scheduleDismiss()

            case .cancelled:
                self.stopMouseTracking()
                self.showCancelled()
                self.scheduleDismiss()

            case .error(let message):
                self.stopMouseTracking()
                self.showError(message: message)
                self.scheduleDismiss()
            }
        }
    }

    /// Returns true if currently showing an error state
    var isShowingError: Bool {
        if case .error = currentState {
            return true
        }
        return false
    }

    /// Hides the bubble immediately.
    func hide() {
        #if DEBUG
        print("🔵 StatusBubble: hide() called, currentState: \(currentState)")
        #endif
        surfaceLifecycleGeneration += 1
        let hideSessionGeneration = surfaceLifecycleGeneration
        dismissTimer?.invalidate()
        dismissTimer = nil
        stopMouseTracking()

        // Reset to compact size
        resetToCompactSize()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            self.animator().alphaValue = 0
        }, completionHandler: {
            guard hideSessionGeneration == self.surfaceLifecycleGeneration else {
                return
            }
            self.orderOut(nil)
        })
    }
}
