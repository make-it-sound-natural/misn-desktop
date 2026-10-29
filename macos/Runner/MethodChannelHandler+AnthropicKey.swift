import FlutterMacOS

// The Anthropic key gets its own Keychain account so it never collides with
// a custom provider named "Anthropic", whose account is derived from its id.
extension MethodChannelHandler {
    static let anthropicKeychainAccount = "anthropic_api_key"

    func handleSetAnthropicApiKey(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let key = call.arguments as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "Anthropic API Key must be a string",
                details: nil
            ))
            return
        }
        anthropicApiKey = key
        result(nil)
    }

    func handleStoreAnthropicApiKey(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        storeKeychainValue(
            call,
            result: result,
            account: Self.anthropicKeychainAccount,
            invalidMessage: "Anthropic API Key must be a string"
        ) { [weak self] value in
            self?.anthropicApiKey = value
        }
    }

    func handleGetStoredAnthropicApiKey(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        readKeychainValue(result: result, account: Self.anthropicKeychainAccount)
    }

    func getAnthropicApiKey() -> String { anthropicApiKey }
}
