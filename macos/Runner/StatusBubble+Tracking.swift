import Cocoa

/// Mouse tracking, cursor tracking, and positioning for StatusBubble
extension StatusBubble {

    /// Updates bubble position to follow the cursor
    /// - Parameter position: The cursor position in screen coordinates
    func updatePosition(to position: NSPoint) {
        let frame = NSRect(
            x: position.x + cursorOffset,
            y: position.y - bubbleSize - cursorOffset,
            width: bubbleSize,
            height: bubbleSize
        )

        // Ensure bubble stays on screen
        let adjustedFrame = adjustFrameToScreen(frame)
        setFrame(adjustedFrame, display: true)
    }

    /// Starts tracking mouse movement to follow cursor
    func startMouseTracking() {
        stopMouseTracking()

        mouseTrackingMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .mouseMoved
        ) { [weak self] _ in
            guard let self = self, self.currentState == .processing else { return }

            DispatchQueue.main.async {
                let mouseLocation = NSEvent.mouseLocation
                self.updatePosition(to: mouseLocation)
            }
        }
    }

    /// Stops tracking mouse movement
    func stopMouseTracking() {
        if let monitor = mouseTrackingMonitor {
            NSEvent.removeMonitor(monitor)
            mouseTrackingMonitor = nil
        }
    }

    /// Adjusts frame to keep bubble within screen bounds
    /// - Parameters:
    ///   - frame: The desired frame
    ///   - width: Optional width (defaults to bubbleSize)
    ///   - height: Optional height (defaults to bubbleSize)
    /// - Returns: Adjusted frame that fits within screen bounds
    func adjustFrameToScreen(
        _ frame: NSRect,
        width: CGFloat? = nil,
        height: CGFloat? = nil
    ) -> NSRect {
        guard let screen = NSScreen.main else { return frame }

        var adjusted = frame
        let screenFrame = screen.visibleFrame
        let bubbleWidth = width ?? bubbleSize
        let bubbleHeight = height ?? bubbleSize

        // Keep bubble within screen bounds
        if adjusted.maxX > screenFrame.maxX {
            adjusted.origin.x = screenFrame.maxX - bubbleWidth - 10
        }
        if adjusted.minX < screenFrame.minX {
            adjusted.origin.x = screenFrame.minX + 10
        }
        if adjusted.minY < screenFrame.minY {
            adjusted.origin.y = screenFrame.minY + 10
        }
        if adjusted.maxY > screenFrame.maxY {
            adjusted.origin.y = screenFrame.maxY - bubbleHeight - 10
        }

        return adjusted
    }
}
