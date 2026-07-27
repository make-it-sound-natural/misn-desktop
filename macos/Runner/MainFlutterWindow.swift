import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var methodChannelHandler: MethodChannelHandler?
  private var shortcutHandler: ShortcutHandler?

  /// Asks the Flutter side to show Settings.
  ///
  /// Used by the Preferences menu item, which owns the standard Cmd+, key
  /// equivalent every Mac user reaches for first.
  func requestSettings() {
    methodChannelHandler?.sendOpenSettings()
  }

  override func awakeFromNib() {
    isReleasedWhenClosed = false
    (NSApp.delegate as? AppDelegate)?.configureWindowLifecycle(window: self)

    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Set up method channel handler BEFORE registering plugins and before
    // the Dart isolate starts calling methods. With Flutter's merged
    // UI/platform thread mode, Dart code can execute earlier than
    // applicationDidFinishLaunching, so the handler must be ready here.
    let messenger = flutterViewController.engine.binaryMessenger
    let methodHandler = MethodChannelHandler(binaryMessenger: messenger)
    self.methodChannelHandler = methodHandler

    let shortcut = ShortcutHandler(methodChannelHandler: methodHandler)
    self.shortcutHandler = shortcut

    methodHandler.onRegisterShortcut = { [weak shortcut] in
      shortcut?.registerShortcut()
    }

    methodHandler.onReplaceText = { [weak shortcut] text, completion in
      // The completion is wired to a FlutterResult, so every path must reply
      // or the awaiting Dart future never settles.
      guard let shortcut = shortcut else {
        completion(false)
        return
      }
      shortcut.replaceTextInOriginalApp(text, completion: completion)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
