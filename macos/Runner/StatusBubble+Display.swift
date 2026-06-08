import Cocoa

/// State display and visual updates for StatusBubble
extension StatusBubble {

    /// Shows the processing state with spinner animation
    func showProcessing() {
        spinnerView.isHidden = false
        spinnerView.startAnimation(nil)
        iconLabel.isHidden = true

        containerView.layer?.borderWidth = 0
    }

    /// Shows the success state with checkmark icon
    func showSuccess() {
        spinnerView.stopAnimation(nil)
        spinnerView.isHidden = true

        iconLabel.stringValue = "✓"
        iconLabel.textColor = NSColor.systemGreen
        iconLabel.isHidden = false

        // Add subtle green border
        containerView.layer?.borderWidth = 2
        containerView.layer?.borderColor = NSColor.systemGreen
            .withAlphaComponent(0.5).cgColor
    }

    /// Shows the cancelled state with X icon
    func showCancelled() {
        spinnerView.stopAnimation(nil)
        spinnerView.isHidden = true

        iconLabel.stringValue = "✗"
        iconLabel.textColor = NSColor.systemOrange
        iconLabel.isHidden = false

        // Add subtle orange border
        containerView.layer?.borderWidth = 2
        containerView.layer?.borderColor = NSColor.systemOrange
            .withAlphaComponent(0.5).cgColor
    }

    /// Shows the error state with a compact “!” indicator (no provider text).
    /// - Parameter message: Retained for logging; not shown in the bubble.
    func showError(message: String) {
        #if DEBUG
        print("🔴 StatusBubble: showError() with message: \(message)")
        #endif
        spinnerView.stopAnimation(nil)
        spinnerView.isHidden = true

        iconLabel.stringValue = "!"
        iconLabel.textColor = NSColor.systemRed
        iconLabel.frame = NSRect(
            x: 0,
            y: (bubbleSize - 28) / 2,
            width: bubbleSize,
            height: 28
        )
        iconLabel.isHidden = false

        // Purple border (matching app theme)
        containerView.layer?.borderWidth = 2
        containerView.layer?.borderColor = primaryColor
            .withAlphaComponent(0.6).cgColor

        orderFrontRegardless()
    }

    /// Resets the bubble to its compact circular size
    func resetToCompactSize() {
        containerView.frame = NSRect(
            x: 0,
            y: 0,
            width: bubbleSize,
            height: bubbleSize
        )
        containerView.layer?.cornerRadius = bubbleSize / 2
        NSCursor.arrow.set()
    }

    /// Schedules automatic dismissal after the standard delay (success, cancelled, error).
    /// Uses `.common` run-loop mode so the timer still fires during event tracking.
    func scheduleDismiss() {
        dismissTimer?.invalidate()
        let timer = Timer(timeInterval: dismissDelay, repeats: false) { [weak self] _ in
            self?.hide()
        }
        RunLoop.main.add(timer, forMode: .common)
        dismissTimer = timer
    }
}
