import Cocoa

protocol StatusItemFactory {
    func makeStatusItem() -> NSStatusItem
}

final class SystemStatusItemFactory: StatusItemFactory {
    func makeStatusItem() -> NSStatusItem {
        NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    }
}

enum MenuBarIcon {
    static let assetName = "MenuBarIcon"

    static func makeImage() -> NSImage {
        let image = NSImage(named: assetName) ?? makeFallbackImage()
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }

    private static func makeFallbackImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 24, height: 24))
        image.lockFocus()
        defer {
            image.unlockFocus()
        }

        guard let context = NSGraphicsContext.current?.cgContext else {
            return image
        }

        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.setLineWidth(1.8)
        context.strokeEllipse(in: CGRect(x: 2.8, y: 2.8, width: 18.4, height: 18.4))

        let wavePath = CGMutablePath()
        wavePath.move(to: CGPoint(x: 5.04, y: 12))
        wavePath.addCurve(
            to: CGPoint(x: 12, y: 12),
            control1: CGPoint(x: 7.34, y: 6.35),
            control2: CGPoint(x: 9.97, y: 6.35)
        )
        wavePath.addCurve(
            to: CGPoint(x: 18.96, y: 12),
            control1: CGPoint(x: 14.03, y: 17.65),
            control2: CGPoint(x: 16.66, y: 17.65)
        )

        context.setLineWidth(1.65)
        context.addPath(wavePath)
        context.strokePath()

        return image
    }
}

enum MenuBarStrings {
    static var openTitle: String {
        localizedTitle(
            key: "MenuBar.Open",
            fallback: "Open"
        )
    }

    static var quitTitle: String {
        localizedTitle(
            key: "MenuBar.Quit",
            fallback: "Quit"
        )
    }

    private static func localizedTitle(
        key: String,
        fallback: String
    ) -> String {
        Bundle.main.localizedString(
            forKey: key,
            value: fallback,
            table: nil
        )
    }
}

enum MainWindowGeometry {
    static let autosaveName: NSWindow.FrameAutosaveName = "MainWindowFrame"
    static let defaultFrameSize = NSSize(width: 1_180, height: 700)
    static let minimumFrameSize = NSSize(width: 980, height: 600)
    static let screenInset: CGFloat = 20

    static func visibleFrames() -> [NSRect] {
        NSScreen.screens.map(\.visibleFrame)
    }

    static func defaultFrame(visibleFrames: [NSRect]) -> NSRect {
        guard let visibleFrame = visibleFrames.first else {
            return NSRect(origin: .zero, size: defaultFrameSize)
        }

        let maxWidth = max(1, visibleFrame.width - screenInset * 2)
        let maxHeight = max(1, visibleFrame.height - screenInset * 2)
        let width = min(defaultFrameSize.width, maxWidth)
        let height = min(defaultFrameSize.height, maxHeight)

        return NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
    }

    static func repairedFrame(
        _ frame: NSRect,
        visibleFrames: [NSRect]
    ) -> NSRect {
        guard !visibleFrames.isEmpty else {
            return NSRect(
                origin: frame.origin,
                size: NSSize(
                    width: max(frame.width, minimumFrameSize.width),
                    height: max(frame.height, minimumFrameSize.height)
                )
            )
        }

        let visibleFrame = bestVisibleFrame(
            for: frame,
            visibleFrames: visibleFrames
        )
        let minX = visibleFrame.minX + screenInset
        let minY = visibleFrame.minY + screenInset
        let maxX = visibleFrame.maxX - screenInset
        let maxY = visibleFrame.maxY - screenInset
        let maxWidth = max(1, visibleFrame.width - screenInset * 2)
        let maxHeight = max(1, visibleFrame.height - screenInset * 2)
        let width = min(max(frame.width, minimumFrameSize.width), maxWidth)
        let height = min(max(frame.height, minimumFrameSize.height), maxHeight)
        let maxOriginX = max(minX, maxX - width)
        let maxOriginY = max(minY, maxY - height)

        return NSRect(
            x: min(max(frame.origin.x, minX), maxOriginX),
            y: min(max(frame.origin.y, minY), maxOriginY),
            width: width,
            height: height
        )
    }

    private static func bestVisibleFrame(
        for frame: NSRect,
        visibleFrames: [NSRect]
    ) -> NSRect {
        visibleFrames.max { lhs, rhs in
            intersectionArea(lhs, with: frame)
                < intersectionArea(rhs, with: frame)
        } ?? visibleFrames[0]
    }

    private static func intersectionArea(
        _ visibleFrame: NSRect,
        with frame: NSRect
    ) -> CGFloat {
        let intersection = visibleFrame.intersection(frame)
        guard !intersection.isNull else {
            return 0
        }
        return intersection.width * intersection.height
    }
}

final class AppWindowLifecycleController: NSObject, NSWindowDelegate {
    private weak var window: NSWindow?
    private let application: NSApplication
    private let statusItemFactory: StatusItemFactory
    private var statusItem: NSStatusItem?

    init(
        application: NSApplication = .shared,
        statusItemFactory: StatusItemFactory = SystemStatusItemFactory()
    ) {
        self.application = application
        self.statusItemFactory = statusItemFactory
    }

    func configure(window: NSWindow?) {
        if let window {
            self.window = window
            window.isReleasedWhenClosed = false
            window.delegate = self
            configureGeometry(for: window)
        }

        installStatusItemIfNeeded()
    }

    private func configureGeometry(for window: NSWindow) {
        window.minSize = MainWindowGeometry.minimumFrameSize
        _ = window.setFrameAutosaveName(MainWindowGeometry.autosaveName)

        let restored = window.setFrameUsingName(MainWindowGeometry.autosaveName)
        let visibleFrames = MainWindowGeometry.visibleFrames()
        let targetFrame = restored
            ? MainWindowGeometry.repairedFrame(
                window.frame,
                visibleFrames: visibleFrames
            )
            : MainWindowGeometry.defaultFrame(visibleFrames: visibleFrames)

        if !targetFrame.equalTo(window.frame) {
            window.setFrame(targetFrame, display: false)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Keep the Flutter engine, method channel, and shortcut handlers alive.
        sender.orderOut(nil)
        return false
    }

    func shouldTerminateAfterLastWindowClosed() -> Bool {
        false
    }

    func handleReopen(hasVisibleWindows _: Bool) -> Bool {
        showWindow()
        return true
    }

    func showWindow() {
        let targetWindow = window ?? application.windows.first {
            $0 is MainFlutterWindow
        }
        guard let targetWindow else {
            return
        }

        if targetWindow.isMiniaturized {
            targetWindow.deminiaturize(nil)
        }

        application.activate(ignoringOtherApps: true)
        targetWindow.makeKeyAndOrderFront(nil)
    }

    @objc func openFromStatusItem(_ sender: Any?) {
        showWindow()
    }

    @objc func quitFromStatusItem(_ sender: Any?) {
        application.terminate(sender)
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else {
            return
        }

        let item = statusItemFactory.makeStatusItem()
        if let button = item.button {
            button.image = MenuBarIcon.makeImage()
            button.title = ""
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = AppDefaults.appName
        }
        item.menu = makeStatusMenu()
        statusItem = item
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: MenuBarStrings.openTitle,
            action: #selector(openFromStatusItem(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: MenuBarStrings.quitTitle,
            action: #selector(quitFromStatusItem(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }
}
