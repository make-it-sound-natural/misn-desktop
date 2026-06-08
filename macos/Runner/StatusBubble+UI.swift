import Cocoa

/// UI setup and appearance management for StatusBubble
extension StatusBubble {

    /// Configures the panel properties for floating bubble behavior
    func setupPanel() {
        // Panel configuration for floating bubble
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false

        // Allow mouse events - critical for button clicks
        ignoresMouseEvents = false

        // Prevent the panel from becoming key or main window
        becomesKeyOnlyIfNeeded = true
    }

    /// Sets up all UI components within the bubble
    func setupUI() {
        guard let contentView = self.contentView else { return }

        // Container with rounded background
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = bubbleSize / 2
        containerView.layer?.masksToBounds = true
        containerView.frame = NSRect(x: 0, y: 0, width: bubbleSize, height: bubbleSize)

        // Set background color based on appearance
        updateBackgroundColor()

        contentView.addSubview(containerView)

        // Spinner for processing state
        spinnerView.style = .spinning
        spinnerView.controlSize = .small
        spinnerView.isIndeterminate = true
        spinnerView.frame = NSRect(
            x: (bubbleSize - 20) / 2,
            y: (bubbleSize - 20) / 2,
            width: 20,
            height: 20
        )
        containerView.addSubview(spinnerView)

        // Icon label for success/cancelled states
        iconLabel.font = NSFont.systemFont(ofSize: 22, weight: .medium)
        iconLabel.alignment = .center
        iconLabel.frame = NSRect(x: 0, y: (bubbleSize - 28) / 2, width: bubbleSize, height: 28)
        iconLabel.isHidden = true
        containerView.addSubview(iconLabel)
    }

    /// Updates the background color based on current system appearance
    func updateBackgroundColor() {
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(
            from: [.darkAqua, .aqua]
        ) == .darkAqua
        containerView.layer?.backgroundColor = isDarkMode
            ? NSColor(white: 0.2, alpha: 0.95).cgColor
            : NSColor(white: 0.95, alpha: 0.95).cgColor
    }
}
