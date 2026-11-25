import FlutterMacOS

extension MethodChannelHandler {
    func handleAcknowledgeKeyEvents(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        keyboardDiagnostics?.acknowledgeKeyEvents()
        result(nil)
    }

    func handleReportTextInputStall(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let arguments = call.arguments as? [String: Any],
              let keyPresses = arguments["keyPresses"] as? Int,
              let lifecycleState = arguments["lifecycleState"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "Unexpected text input stall report: " +
                    String(describing: call.arguments),
                details: nil
            ))
            return
        }
        keyboardDiagnostics?.reportTextInputStall(
            keyPresses: keyPresses,
            lifecycleState: lifecycleState
        )
        result(nil)
    }
}
