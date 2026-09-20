import FlutterMacOS

// Model preferences are synchronized from persisted Flutter settings.
extension MethodChannelHandler {
    func handleSetReasoningEffort(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let value = call.arguments as? String,
              let effort = ReasoningEffort(rawValue: value) else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "Unknown reasoning effort",
                details: nil
            ))
            return
        }
        reasoningEffort = effort
        result(nil)
    }

    func handleSetModel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let mdl = call.arguments as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Model must be a string", details: nil))
            return
        }
        #if DEBUG
        print("MethodChannelHandler: setModel called with: \(mdl)")
        #endif
        model = mdl
        result(nil)
    }

    func getReasoningEffort() -> ReasoningEffort { reasoningEffort }
    func getModel() -> String {
        #if DEBUG
        print("MethodChannelHandler: getModel returning: \(model)")
        #endif
        return model
    }
}
