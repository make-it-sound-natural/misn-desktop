import Cocoa

/// Test seam for the floating status bubble; production uses `StatusBubble.shared`.
protocol StatusBubbleControlling: AnyObject {
    func show(at position: NSPoint, state: StatusBubble.State)
    func hide()
    func updateState(_ state: StatusBubble.State)
}

extension StatusBubble: StatusBubbleControlling {}
