import Cocoa
import FlutterMacOS
import Sparkle

@main
class AppDelegate: FlutterAppDelegate {
  private let windowLifecycleController = AppWindowLifecycleController()

  func configureWindowLifecycle(window: NSWindow?) {
    windowLifecycleController.configure(window: window)
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
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
