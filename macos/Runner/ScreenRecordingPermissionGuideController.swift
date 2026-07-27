import AppKit

struct ScreenRecordingPermissionGuidePresentation {
    let manualAddRequired: Bool

    var showsDragInstructions: Bool {
        manualAddRequired
    }

    var showsRevealInFinder: Bool {
        manualAddRequired
    }
}

struct ScreenRecordingPermissionGuideText {
    let title: String
    let message: String
    let dragInstruction: String
    let openSettings: String
    let revealInFinder: String
    let checkAgain: String
    let cancel: String
    let stillMissing: String
    let debugHint: String
    let manualAddRequired: Bool
    let openSettingsOnAppear: Bool

    var presentation: ScreenRecordingPermissionGuidePresentation {
        ScreenRecordingPermissionGuidePresentation(
            manualAddRequired: manualAddRequired
        )
    }

    init(arguments: Any?) {
        let data = arguments as? [String: Any] ?? [:]
        title = data["title"] as? String ?? """
        Screen Recording permission required
        """
        message = data["message"] as? String ?? """
        Add this app to Screen Recording, then enable it.
        """
        dragInstruction = data["dragInstruction"] as? String ?? """
        Drag this app into the Screen Recording list, then enable it.
        """
        openSettings = data["openSettings"] as? String ?? "Open System Settings"
        revealInFinder = data["revealInFinder"] as? String ?? "Reveal in Finder"
        checkAgain = data["checkAgain"] as? String ?? "Check Again"
        cancel = data["cancel"] as? String ?? "Cancel"
        stillMissing = data["stillMissing"] as? String ?? """
        Screen Recording is still not granted.
        """
        debugHint = data["debugHint"] as? String ?? """
        If macOS asked for Terminal or iTerm, grant that launcher or open the
        built .app directly.
        """
        manualAddRequired = data["manualAddRequired"] as? Bool ?? true
        openSettingsOnAppear = data["openSettingsOnAppear"] as? Bool ?? false
    }
}

final class ScreenRecordingPermissionGuideController: NSObject, NSWindowDelegate {
    private let text: ScreenRecordingPermissionGuideText
    private let appURL: URL
    private var panel: NSPanel?
    private var statusLabel: NSTextField?

    init(
        text: ScreenRecordingPermissionGuideText,
        appURL: URL = Bundle.main.bundleURL
    ) {
        self.text = text
        self.appURL = appURL
    }

    func presentModal() -> Bool {
        let panel = makePanel()
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        if text.openSettingsOnAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.openSettings()
            }
        }
        let response = NSApp.runModal(for: panel)
        panel.close()
        self.panel = nil
        return response == .OK
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = text.title
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.center()
        panel.contentView = makeContentView()
        return panel
    }

    func makeContentViewForTesting() -> NSView {
        makeContentView()
    }

    private func makeContentView() -> NSView {
        let root = NSView()
        root.wantsLayer = true
        // Follows the system appearance so the guide is readable in dark mode.
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        let header = makeHeader()
        stack.addArrangedSubview(header)

        let message = label(text.message, font: .systemFont(ofSize: 14))
        message.textColor = .labelColor
        stack.addArrangedSubview(message)

        if text.presentation.showsDragInstructions {
            let dragView = DraggableAppPermissionView(
                appURL: appURL,
                title: appURL.deletingPathExtension().lastPathComponent,
                subtitle: text.dragInstruction
            )
            dragView.translatesAutoresizingMaskIntoConstraints = false
            dragView.heightAnchor.constraint(equalToConstant: 104).isActive = true
            stack.addArrangedSubview(dragView)
        }

        #if DEBUG
        let debug = label(text.debugHint, font: .systemFont(ofSize: 12))
        debug.textColor = .secondaryLabelColor
        stack.addArrangedSubview(debug)
        #endif

        let status = label("", font: .systemFont(ofSize: 12))
        status.textColor = .systemOrange
        status.isHidden = true
        statusLabel = status
        stack.addArrangedSubview(status)

        stack.addArrangedSubview(makeButtonRow())

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -24)
        ])
        return root
    }

    private func makeHeader() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let icon = NSImageView()
        icon.image = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 40).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 40).isActive = true
        row.addArrangedSubview(icon)

        let title = label(text.title, font: .boldSystemFont(ofSize: 18))
        title.maximumNumberOfLines = 1
        row.addArrangedSubview(title)
        return row
    }

    private func makeButtonRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        row.addArrangedSubview(button(text.openSettings, action: #selector(openSettings)))
        if text.presentation.showsRevealInFinder {
            row.addArrangedSubview(
                button(text.revealInFinder, action: #selector(revealInFinder))
            )
        }
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(button(text.cancel, action: #selector(cancel)))
        let check = button(text.checkAgain, action: #selector(checkAgain))
        check.keyEquivalent = "\r"
        row.addArrangedSubview(check)
        return row
    }

    private func label(_ value: String, font: NSFont) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: value)
        field.font = font
        field.textColor = .labelColor
        field.maximumNumberOfLines = 0
        return field
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        return button
    }

    @objc private func openSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([appURL])
    }

    @objc private func checkAgain() {
        if ScreenRecordingPermission.hasAccess() {
            NSApp.stopModal(withCode: .OK)
        } else {
            statusLabel?.stringValue = text.stillMissing
            statusLabel?.isHidden = false
        }
    }

    @objc private func cancel() {
        NSApp.stopModal(withCode: .cancel)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.stopModal(withCode: .cancel)
    }
}

final class DraggableAppPermissionView: NSView, NSDraggingSource {
    static let preferredHeight: CGFloat = 104
    static let iconFrame = NSRect(x: 18, y: 28, width: 48, height: 48)
    static let titleFrame = NSRect(x: 82, y: 62, width: 420, height: 22)
    static let subtitleFrame = NSRect(x: 82, y: 26, width: 420, height: 28)

    let appURL: URL
    private let title: String
    private let subtitle: String

    init(appURL: URL, title: String, subtitle: String) {
        self.appURL = appURL
        self.title = title
        self.subtitle = subtitle
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    func pasteboardItem() -> NSPasteboardItem {
        let item = NSPasteboardItem()
        item.setString(appURL.absoluteString, forType: .fileURL)
        return item
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 48, height: 48)
        icon.draw(in: Self.iconFrame)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 15),
            .foregroundColor: NSColor.labelColor
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        title.draw(
            in: Self.titleFrame,
            withAttributes: titleAttributes
        )
        subtitle.draw(
            in: Self.subtitleFrame,
            withAttributes: subtitleAttributes
        )
    }

    override func mouseDown(with event: NSEvent) {
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem())
        draggingItem.setDraggingFrame(bounds, contents: dragImage())
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }

    private func dragImage() -> NSImage {
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        draw(bounds)
        image.unlockFocus()
        return image
    }
}
