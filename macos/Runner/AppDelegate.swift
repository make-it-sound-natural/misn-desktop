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

  override func applicationSupportsSecureRestorableState(
    _ app: NSApplication
  ) -> Bool {
    true
  }
}
