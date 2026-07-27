import Cocoa

/// Indeterminate ring spinner used inside the status bubble.
///
/// AppKit's `NSProgressIndicator(.spinning)` draws the classic pinwheel of
/// spokes. The design calls for a ring with one tinted arc rotating around
/// it, so this draws that directly: a full-circle track plus a quarter-arc
/// head, rotated by a single layer animation.
final class StatusBubbleSpinnerView: NSView {

    /// Diameter of the ring, matching the design spec.
    static let diameter: CGFloat = 20

    private static let lineWidth: CGFloat = 2
    private static let rotationDuration: CFTimeInterval = 0.8
    private static let rotationKey = "statusBubbleSpinnerRotation"

    private let trackLayer = CAShapeLayer()
    private let headLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    /// Applies the track and arc colors for the current appearance.
    func applyColors(track: NSColor, head: NSColor) {
        trackLayer.strokeColor = track.cgColor
        headLayer.strokeColor = head.cgColor
    }

    /// Starts the rotation, unless it is already running.
    func startAnimating() {
        guard headLayer.animation(forKey: Self.rotationKey) == nil else {
            return
        }
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = -Double.pi * 2
        rotation.duration = Self.rotationDuration
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        headLayer.add(rotation, forKey: Self.rotationKey)
    }

    /// Stops the rotation and clears the animation.
    func stopAnimating() {
        headLayer.removeAnimation(forKey: Self.rotationKey)
    }

    private func setupLayers() {
        wantsLayer = true

        let inset = Self.lineWidth / 2
        let box = NSRect(
            x: inset,
            y: inset,
            width: Self.diameter - Self.lineWidth,
            height: Self.diameter - Self.lineWidth
        )
        let circle = CGPath(ellipseIn: box, transform: nil)
        let center = CGPoint(x: Self.diameter / 2, y: Self.diameter / 2)

        for shape in [trackLayer, headLayer] {
            shape.path = circle
            shape.fillColor = NSColor.clear.cgColor
            shape.lineWidth = Self.lineWidth
            shape.lineCap = .round
            shape.frame = NSRect(
                x: 0,
                y: 0,
                width: Self.diameter,
                height: Self.diameter
            )
            // Rotate about the ring's centre rather than the layer origin.
            shape.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            shape.position = center
            layer?.addSublayer(shape)
        }

        // A quarter of the circle, mirroring the mockup's single tinted edge.
        headLayer.strokeStart = 0
        headLayer.strokeEnd = 0.25
    }
}
