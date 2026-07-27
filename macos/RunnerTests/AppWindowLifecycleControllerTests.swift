import Cocoa
import XCTest
@testable import Make_It_Sound_Natural

private final class CountingStatusItemFactory: StatusItemFactory {
    private(set) var creationCount = 0
    private(set) var createdItems: [NSStatusItem] = []

    func makeStatusItem() -> NSStatusItem {
        creationCount += 1
        let item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        createdItems.append(item)
        return item
    }
}

final class AppWindowLifecycleControllerTests: XCTestCase {
    private var windowsToClose: [NSWindow] = []
    private var statusItemFactories: [CountingStatusItemFactory] = []

    override func setUp() {
        super.setUp()
        NSWindow.removeFrame(usingName: MainWindowGeometry.autosaveName)
    }

    override func tearDown() {
        for window in windowsToClose {
            window.delegate = nil
            window.close()
        }
        windowsToClose.removeAll()
        for factory in statusItemFactories {
            for item in factory.createdItems {
                NSStatusBar.system.removeStatusItem(item)
            }
        }
        statusItemFactories.removeAll()
        NSWindow.removeFrame(usingName: MainWindowGeometry.autosaveName)
        super.tearDown()
    }

    func testGeometryDefaultFrameUsesTwoPanelWidthWhenSpaceAllows() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)

        let frame = MainWindowGeometry.defaultFrame(
            visibleFrames: [visibleFrame]
        )

        XCTAssertEqual(
            frame.width,
            MainWindowGeometry.defaultFrameSize.width,
            accuracy: 0.1
        )
        XCTAssertEqual(
            frame.height,
            MainWindowGeometry.defaultFrameSize.height,
            accuracy: 0.1
        )
        XCTAssertEqual(frame.midX, visibleFrame.midX, accuracy: 0.1)
        XCTAssertEqual(frame.midY, visibleFrame.midY, accuracy: 0.1)
    }

    func testGeometryKeepsValidCompactSavedFrame() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        // Narrower than the default but still at or above the minimum, so it
        // must be preserved rather than grown.
        let compactFrame = NSRect(x: 120, y: 120, width: 1000, height: 620)

        let repaired = MainWindowGeometry.repairedFrame(
            compactFrame,
            visibleFrames: [visibleFrame]
        )

        XCTAssertTrue(repaired.equalTo(compactFrame))
    }

    func testGeometryExpandsTooSmallSavedFrameToAbsoluteMinimum() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let tooSmallFrame = NSRect(x: 120, y: 120, width: 420, height: 320)

        let repaired = MainWindowGeometry.repairedFrame(
            tooSmallFrame,
            visibleFrames: [visibleFrame]
        )

        XCTAssertEqual(
            repaired.width,
            MainWindowGeometry.minimumFrameSize.width,
            accuracy: 0.1
        )
        XCTAssertEqual(
            repaired.height,
            MainWindowGeometry.minimumFrameSize.height,
            accuracy: 0.1
        )
    }

    func testGeometryMovesOffscreenFrameIntoVisibleFrame() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let offscreenFrame = NSRect(x: 2_000, y: 2_000, width: 820, height: 620)

        let repaired = MainWindowGeometry.repairedFrame(
            offscreenFrame,
            visibleFrames: [visibleFrame]
        )
        let usableFrame = visibleFrame.insetBy(
            dx: MainWindowGeometry.screenInset,
            dy: MainWindowGeometry.screenInset
        )

        XCTAssertTrue(usableFrame.contains(repaired))
    }

    func testConfigureSetsWindowMinimumSizeAndAutosaveName() {
        let controller = AppWindowLifecycleController(
            statusItemFactory: makeStatusItemFactory()
        )
        let window = makeWindow()

        controller.configure(window: window)

        XCTAssertEqual(window.minSize, MainWindowGeometry.minimumFrameSize)
        XCTAssertEqual(window.frameAutosaveName, MainWindowGeometry.autosaveName)
        XCTAssertGreaterThanOrEqual(
            window.frame.width,
            MainWindowGeometry.minimumFrameSize.width
        )
        XCTAssertGreaterThanOrEqual(
            window.frame.height,
            MainWindowGeometry.minimumFrameSize.height
        )
    }

    func testWindowShouldCloseHidesWindowAndKeepsItAlive() {
        let factory = makeStatusItemFactory()
        let controller = AppWindowLifecycleController(
            statusItemFactory: factory
        )
        let window = makeWindow()
        controller.configure(window: window)
        window.makeKeyAndOrderFront(nil)

        let shouldClose = controller.windowShouldClose(window)

        XCTAssertFalse(shouldClose)
        XCTAssertFalse(window.isVisible)
        XCTAssertFalse(window.isReleasedWhenClosed)
        XCTAssertTrue(window.delegate === controller)
    }

    func testShowWindowRestoresHiddenWindow() {
        let factory = makeStatusItemFactory()
        let controller = AppWindowLifecycleController(
            statusItemFactory: factory
        )
        let window = makeWindow()
        controller.configure(window: window)
        window.orderOut(nil)

        controller.showWindow()

        XCTAssertTrue(window.isVisible)
    }

    func testShouldNotTerminateAfterLastWindowClosed() {
        let controller = AppWindowLifecycleController(
            statusItemFactory: makeStatusItemFactory()
        )

        XCTAssertFalse(controller.shouldTerminateAfterLastWindowClosed())
    }

    func testHandleReopenShowsHiddenWindow() {
        let controller = AppWindowLifecycleController(
            statusItemFactory: makeStatusItemFactory()
        )
        let window = makeWindow()
        controller.configure(window: window)
        window.orderOut(nil)

        let handled = controller.handleReopen(hasVisibleWindows: false)

        XCTAssertTrue(handled)
        XCTAssertTrue(window.isVisible)
    }

    func testHandleReopenFocusesExistingVisibleWindow() {
        let controller = AppWindowLifecycleController(
            statusItemFactory: makeStatusItemFactory()
        )
        let window = makeWindow()
        controller.configure(window: window)
        window.makeKeyAndOrderFront(nil)

        let handled = controller.handleReopen(hasVisibleWindows: true)

        XCTAssertTrue(handled)
        XCTAssertTrue(window.isVisible)
    }

    func testMenuBarStringsResolveToUserFacingLabels() {
        XCTAssertEqual(MenuBarStrings.openTitle, "Open")
        XCTAssertEqual(MenuBarStrings.quitTitle, "Quit")
        XCTAssertNotEqual(MenuBarStrings.openTitle, "MenuBar.Open")
        XCTAssertNotEqual(MenuBarStrings.quitTitle, "MenuBar.Quit")
    }

    func testEnglishMenuBarStringsAreBundledWithApp() {
        let bundle = Bundle(for: AppWindowLifecycleController.self)
        let stringsPath = bundle.path(
            forResource: "Localizable",
            ofType: "strings",
            inDirectory: nil,
            forLocalization: "en"
        )

        XCTAssertNotNil(stringsPath)
    }

    func testStatusItemInstallsOnceWithOpenAndQuitMenuItems() throws {
        let factory = makeStatusItemFactory()
        let controller = AppWindowLifecycleController(
            statusItemFactory: factory
        )
        let window = makeWindow()

        controller.configure(window: window)
        controller.configure(window: window)

        XCTAssertEqual(factory.creationCount, 1)
        let item = try XCTUnwrap(factory.createdItems.first)
        let menu = try XCTUnwrap(item.menu)
        XCTAssertEqual(menu.items.map(\.title), [
            "Open",
            "",
            "Quit",
        ])
        XCTAssertEqual(
            menu.items[0].action,
            #selector(AppWindowLifecycleController.openFromStatusItem(_:))
        )
        XCTAssertTrue(menu.items[0].target === controller)
        XCTAssertEqual(
            menu.items[2].action,
            #selector(AppWindowLifecycleController.quitFromStatusItem(_:))
        )
        XCTAssertTrue(menu.items[2].target === controller)
    }

    func testStatusItemConfiguresVisibleButton() throws {
        let factory = makeStatusItemFactory()
        let controller = AppWindowLifecycleController(
            statusItemFactory: factory
        )

        controller.configure(window: makeWindow())

        let item = try XCTUnwrap(factory.createdItems.first)
        let button = try XCTUnwrap(item.button)
        XCTAssertNotNil(button.image)
        XCTAssertTrue(button.image?.isTemplate ?? false)
        XCTAssertEqual(button.title, "")
        XCTAssertEqual(button.imagePosition, .imageOnly)
        XCTAssertEqual(button.imageScaling, .scaleProportionallyDown)
        XCTAssertEqual(button.toolTip, AppDefaults.appName)
    }

    func testMenuBarIconFallbackIsTemplateSizedImage() {
        let image = MenuBarIcon.makeImage()

        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(image.isTemplate)
    }

    private func makeStatusItemFactory() -> CountingStatusItemFactory {
        let factory = CountingStatusItemFactory()
        statusItemFactories.append(factory)
        return factory
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        windowsToClose.append(window)
        return window
    }
}
