import Cocoa
import FlutterMacOS
import Sparkle

@main
class AppDelegate: FlutterAppDelegate {
  /// True when the app only hosts the XCTest bundle. No test needs the
  /// Flutter engine, and one left rendering crashed the host when XCTest
  /// called `exit()` while the raster thread was still drawing.
  static let isTestHost =
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

  private let windowLifecycleController = AppWindowLifecycleController()

  func configureWindowLifecycle(window: NSWindow?) {
    windowLifecycleController.configure(window: window)
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if Self.isTestHost {
      // Keep the empty window off screen and leave focus where it is.
      mainFlutterWindow?.orderOut(nil)
      return
    }

    // Initialize Sparkle auto-updater
    SparkleUpdater.shared.initialize()

    // Activate app ourselves before Flutter tries (suppresses
    // "Failed to foreground app" warning)
    NSApp.activate(ignoringOtherApps: true)

    // Method channel and shortcut handler are initialized in
    // MainFlutterWindow.awakeFromNib() to ensure they are ready before
    // the Dart isolate starts calling methods.

    super.applicationDidFinishLaunching(notification)
    configureWindowLifecycle(window: mainFlutterWindow)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(
    _ sender: NSApplication
  ) -> Bool {
    windowLifecycleController.shouldTerminateAfterLastWindowClosed()
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    windowLifecycleController.handleReopen(hasVisibleWindows: flag)
  }

  /// Backs the standard Preferences… menu item.
  ///
  /// The item shipped with its Cmd+, key equivalent but no action connection,
  /// so AppKit rendered it permanently disabled and the shortcut did nothing.
  @IBAction func openPreferences(_ sender: Any?) {
    guard let window = mainFlutterWindow as? MainFlutterWindow else { return }
    NSApp.activate(ignoringOtherApps: true)
    window.requestSettings()
  }

  override func applicationSupportsSecureRestorableState(
    _ app: NSApplication
  ) -> Bool {
    true
  }
}
