import FlutterMacOS

// The App context mode is synchronized from persisted Flutter settings on
// launch; until then it stays off, like the screenshot mode.
extension MethodChannelHandler {
    func handleSetAccessibilityContextMode(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        // Only our Dart side sends this, so a value it does not know is a
        // bug to surface, not a reason to turn App context off.
        guard let value = call.arguments as? String,
              let mode = AccessibilityContextMode(rawValue: value) else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "Unknown App context mode: " +
                    String(describing: call.arguments),
                details: nil
            ))
            return
        }
        accessibilityContextMode = mode
        result(nil)
    }

    func getAccessibilityContextMode() -> AccessibilityContextMode {
        accessibilityContextMode
    }
}
