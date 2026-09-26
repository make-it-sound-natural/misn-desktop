import FlutterMacOS

// The App context mode is synchronized from persisted Flutter settings on
// launch; until then it stays off, like the screenshot mode.
extension MethodChannelHandler {
    func handleSetAccessibilityContextMode(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let value = call.arguments as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "App context mode must be a string",
                details: nil
            ))
            return
        }
        accessibilityContextMode = AccessibilityContextMode.parse(value)
        result(nil)
    }

    func getAccessibilityContextMode() -> AccessibilityContextMode {
        accessibilityContextMode
    }
}
