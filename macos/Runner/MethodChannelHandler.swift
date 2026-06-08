import Cocoa
import FlutterMacOS

struct AccessibilityPermissionProbe {
    static func status(
        prompt: Bool,
        isTrusted: (Bool) -> Bool = AccessibilityPermissionProbe.liveStatus
    ) -> Bool {
        isTrusted(prompt)
    }

    private static func liveStatus(prompt: Bool) -> Bool {
        if !prompt {
            return AXIsProcessTrusted()
        }

        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

class MethodChannelHandler {
    private var channel: FlutterMethodChannel
    private var messageSender: FlutterMessageSender
    private var provider: String = AppDefaults.apiProvider
    private var apiKey: String = AppDefaults.apiKey
    private var openRouterApiKey: String = AppDefaults.apiKey
    private var context: String = AppDefaults.context
    private var model: String = AppDefaults.model
    private var defaultVariant: String = AppDefaults.variant
    private var customPrompt: String = ""
    private var targetProfileId: String = "americanEnglish"
    private var targetProfileName: String = "American English"
    private var targetProfileInstruction: String = "Rewrite in natural American English."
    private var targetProfileSelectionRequired: Bool = true
    private var screenshotContextMode: ScreenshotContextMode = .off
    private let keychain = KeychainService.shared

    // Delegate or callback to ShortcutHandler
    var onRegisterShortcut: (() -> Void)?
    var onReplaceText: ((String) -> Void)?
    var onGenerateVariants: ((String, @escaping (String?, String?) -> Void) -> Void)?
    var onUpdateCorrectionShortcut: ((String) -> Void)?
    var onUpdateReplaceShortcut: ((String) -> Void)?
    var onUpdateAppendShortcut: ((String) -> Void)?
    var onValidateShortcut: ((String, @escaping (Bool, String?) -> Void) -> Void)?
    var onDisableShortcuts: (() -> Void)?
    var onEnableShortcuts: (() -> Void)?

    init(binaryMessenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.makeitsoundnatural/shortcut",
            binaryMessenger: binaryMessenger
        )
        messageSender = FlutterMessageSender(channel: channel)
        setupMethodCallHandler()
    }

    private lazy var methodHandlers: [String: (FlutterMethodCall, @escaping FlutterResult) -> Void] = [
        "registerShortcut": handleRegisterShortcut,
        "replaceTextInOriginalApp": handleReplaceText,
        "generateVariants": handleGenerateVariants,
        "checkAccessibilityPermissions": handleCheckAccessibilityPermissions,
        "requestAccessibilityPermission": handleRequestAccessibilityPermission,
        "setProvider": handleSetProvider,
        "setApiKey": handleSetApiKey,
        "storeApiKey": handleStoreApiKey,
        "getStoredApiKey": handleGetStoredApiKey,
        "setOpenRouterApiKey": handleSetOpenRouterApiKey,
        "storeOpenRouterApiKey": handleStoreOpenRouterApiKey,
        "getStoredOpenRouterApiKey": handleGetStoredOpenRouterApiKey,
        "setContext": handleSetContext,
        "setModel": handleSetModel,
        "setDefaultVariant": handleSetDefaultVariant,
        "setCustomPrompt": handleSetCustomPrompt,
        "setTargetProfile": handleSetTargetProfile,
        "setScreenshotContextMode": handleSetScreenshotContextMode,
        "checkScreenRecordingPermission":
            handleCheckScreenRecordingPermission,
        "requestScreenRecordingPermission":
            handleRequestScreenRecordingPermission,
        "presentScreenRecordingPermissionGuide":
            handlePresentScreenRecordingPermissionGuide,
        "bringToForeground": handleBringToForeground,
        "updateShortcut": handleUpdateShortcut,
        "updateReplaceShortcut": handleUpdateReplaceShortcut,
        "updateAppendShortcut": handleUpdateAppendShortcut,
        "validateShortcut": handleValidateShortcut,
        "disableShortcuts": handleDisableShortcuts,
        "enableShortcuts": handleEnableShortcuts,
        "getDefaultPrompt": handleGetDefaultPrompt,
        // Update-related methods
        "checkForUpdates": handleCheckForUpdates,
        "getAppVersion": handleGetAppVersion,
        "getLastUpdateCheck": handleGetLastUpdateCheck,
        "getAutomaticUpdateChecks": handleGetAutomaticUpdateChecks,
        "setAutomaticUpdateChecks": handleSetAutomaticUpdateChecks
    ]

    private func setupMethodCallHandler() {
        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }

            if let handler = self.methodHandlers[call.method] {
                handler(call, result)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func handleRegisterShortcut(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        onRegisterShortcut?()
        result(nil)
    }

    private func handleReplaceText(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let text = call.arguments as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Text must be a string", details: nil))
            return
        }
        onReplaceText?(text)
        result(nil)
    }

    private func handleGenerateVariants(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let text = call.arguments as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Text must be a string", details: nil))
            return
        }
        onGenerateVariants?(text) { fullContent, error in
            if let err = error {
                result(FlutterError(code: "API_ERROR", message: err, details: nil))
            } else {
                result(fullContent)
            }
        }
    }

    private func handleCheckAccessibilityPermissions(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        result(AccessibilityPermissionProbe.status(prompt: false))
    }

    private func handleRequestAccessibilityPermission(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        result(AccessibilityPermissionProbe.status(prompt: true))
    }

    private func handleSetProvider(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let prov = call.arguments as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Provider must be a string", details: nil))
            return
        }
        #if DEBUG
        print("MethodChannelHandler: setProvider called with: \(prov)")
        #endif
        provider = prov
        result(nil)
    }

    private func handleSetApiKey(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let key = call.arguments as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "API Key must be a string", details: nil))
            return
        }
        apiKey = key
        result(nil)
    }

    private func handleStoreApiKey(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        storeKeychainValue(
            call,
            result: result,
            account: "openai_api_key",
            invalidMessage: "API Key must be a string"
        ) { [weak self] value in
            self?.apiKey = value
        }
    }

    private func handleGetStoredApiKey(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        readKeychainValue(result: result, account: "openai_api_key")
    }

    private func handleSetOpenRouterApiKey(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let key = call.arguments as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "OpenRouter API Key must be a string",
                details: nil))
            return
        }
        openRouterApiKey = key
        result(nil)
    }

    private func handleStoreOpenRouterApiKey(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        storeKeychainValue(
            call,
            result: result,
            account: "openrouter_api_key",
            invalidMessage: "OpenRouter API Key must be a string"
        ) { [weak self] value in
            self?.openRouterApiKey = value
        }
    }

    private func handleGetStoredOpenRouterApiKey(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        readKeychainValue(result: result, account: "openrouter_api_key")
    }

    private func handleSetContext(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let ctx = call.arguments as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Context must be a string", details: nil))
            return
        }
        context = ctx
        result(nil)
    }

    private func handleSetModel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
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

    private func handleSetDefaultVariant(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let variant = call.arguments as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Variant must be a string", details: nil))
            return
        }
        #if DEBUG
        print("MethodChannelHandler: setDefaultVariant called with: \(variant)")
        #endif
        defaultVariant = variant
        result(nil)
    }

    private func handleSetCustomPrompt(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let prompt = call.arguments as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Prompt must be a string", details: nil))
            return
        }
        #if DEBUG
        print("MethodChannelHandler: setCustomPrompt called (length: \(prompt.count))")
        #endif
        customPrompt = prompt
        result(nil)
    }

    private func handleSetTargetProfile(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let data = call.arguments as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "Target profile must be a map",
                details: nil
            ))
            return
        }

        targetProfileSelectionRequired = data["selectionRequired"] as? Bool ?? true
        targetProfileId = data["id"] as? String ?? "(none)"
        targetProfileName = data["name"] as? String ?? "(none)"

        if let instruction = data["instruction"] as? String,
           !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            targetProfileInstruction = instruction
        }

        #if DEBUG
        print(
            "MethodChannelHandler: setTargetProfile id=\(targetProfileId), " +
            "name=\(targetProfileName), " +
            "selectionRequired=\(targetProfileSelectionRequired)"
        )
        #endif

        result(nil)
    }

    private func handleSetScreenshotContextMode(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let value = call.arguments as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "Screenshot context mode must be a string",
                details: nil
            ))
            return
        }
        screenshotContextMode = ScreenshotContextMode.parse(value)
        result(nil)
    }

    private func handleCheckScreenRecordingPermission(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let value = call.arguments as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "Screenshot context mode must be a string",
                details: nil
            ))
            return
        }
        let mode = ScreenshotContextMode.parse(value)
        let status = ScreenRecordingPermission.check(for: mode)
        result(status.channelResponse)
    }

    private func handleRequestScreenRecordingPermission(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let value = call.arguments as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "Screenshot context mode must be a string",
                details: nil
            ))
            return
        }
        let mode = ScreenshotContextMode.parse(value)
        let status = ScreenRecordingPermission.request(for: mode)
        result(status.channelResponse)
    }

    private func handlePresentScreenRecordingPermissionGuide(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        DispatchQueue.main.async {
            let guide = ScreenRecordingPermissionGuideController(
                text: ScreenRecordingPermissionGuideText(
                    arguments: call.arguments
                )
            )
            result(guide.presentModal())
        }
    }

    private func handleBringToForeground(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        #if DEBUG
        print("🔵 MethodChannelHandler: bringToForeground called")
        #endif
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.mainWindow {
                window.makeKeyAndOrderFront(nil)
                #if DEBUG
                print("🔵 MethodChannelHandler: Window brought to front")
                #endif
            } else if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                #if DEBUG
                print("🔵 MethodChannelHandler: First window brought to front")
                #endif
            } else {
                #if DEBUG
                print("🔵 MethodChannelHandler: No window found")
                #endif
            }
        }
        result(nil)
    }

    private func handleUpdateShortcut(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let shortcut = call.arguments as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Shortcut must be a string", details: nil))
            return
        }
        onUpdateCorrectionShortcut?(shortcut)
        result(nil)
    }

    private func handleUpdateReplaceShortcut(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let shortcut = call.arguments as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Shortcut must be a string", details: nil))
            return
        }
        onUpdateReplaceShortcut?(shortcut)
        result(nil)
    }

    private func handleUpdateAppendShortcut(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let shortcut = call.arguments as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Shortcut must be a string", details: nil))
            return
        }
        onUpdateAppendShortcut?(shortcut)
        result(nil)
    }

    private func handleValidateShortcut(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let shortcut = call.arguments as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Shortcut must be a string", details: nil))
            return
        }
        onValidateShortcut?(shortcut) { isValid, conflict in
            let resultData: [String: Any] = [
                "isValid": isValid,
                "conflictName": conflict ?? NSNull()
            ]
            result(resultData)
        }
    }

    private func handleDisableShortcuts(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        onDisableShortcuts?()
        result(nil)
    }

    private func handleEnableShortcuts(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        onEnableShortcuts?()
        result(nil)
    }

    private func handleGetDefaultPrompt(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(ShortcutHandler.defaultCustomizablePrompt)
    }
}

private extension MethodChannelHandler {
    func storeKeychainValue(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult,
        account: String,
        invalidMessage: String,
        updateMemory: (String) -> Void
    ) {
        guard let value = call.arguments as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: invalidMessage, details: nil))
            return
        }

        #if DEBUG
        UserDefaults.standard.set(value, forKey: devSecretKey(account: account))
        updateMemory(value)
        result(nil)
        #else
        do {
            try keychain.write(value, account: account)
            updateMemory(value)
            result(nil)
        } catch {
            result(FlutterError(
                code: "KEYCHAIN_ERROR",
                message: "Failed to store secret",
                details: "\(error)"
            ))
        }
        #endif
    }

    func readKeychainValue(result: @escaping FlutterResult, account: String) {
        #if DEBUG
        result(UserDefaults.standard.string(forKey: devSecretKey(account: account)) ?? "")
        #else
        if ProcessInfo.processInfo.environment[
            "XCTestConfigurationFilePath"
        ] != nil {
            result("")
            return
        }

        do {
            result(try keychain.read(account: account))
        } catch {
            result(FlutterError(
                code: "KEYCHAIN_ERROR",
                message: "Failed to read secret",
                details: "\(error)"
            ))
        }
        #endif
    }

    func devSecretKey(account: String) -> String {
        "dev_only_\(account)"
    }
}

extension MethodChannelHandler {
    func getProvider() -> String {
        #if DEBUG
        print("MethodChannelHandler: getProvider returning: \(provider)")
        #endif
        return provider
    }
    func getApiKey() -> String { apiKey }
    func getOpenRouterApiKey() -> String { openRouterApiKey }
    func getContext() -> String { context }
    func getModel() -> String {
        #if DEBUG
        print("MethodChannelHandler: getModel returning: \(model)")
        #endif
        return model
    }
    func getDefaultVariant() -> String {
        #if DEBUG
        print("MethodChannelHandler: getDefaultVariant returning: \(defaultVariant)")
        #endif
        return defaultVariant
    }
    func getCustomPrompt() -> String { customPrompt }
    func getTargetProfileInstruction() -> String {
        #if DEBUG
        print(
            "MethodChannelHandler: getTargetProfileInstruction " +
            "returning id=\(targetProfileId), name=\(targetProfileName)"
        )
        #endif
        return targetProfileInstruction
    }
    func requiresTargetProfileSelection() -> Bool {
        #if DEBUG
        print(
            "MethodChannelHandler: requiresTargetProfileSelection " +
            "returning: \(targetProfileSelectionRequired)"
        )
        #endif
        return targetProfileSelectionRequired
    }

    func getScreenshotContextMode() -> ScreenshotContextMode {
        screenshotContextMode
    }
}

extension MethodChannelHandler {
    func sendStatus(_ status: String) { messageSender.sendStatus(status) }
    func sendTextCaptured(_ text: String) { messageSender.sendTextCaptured(text) }
    func sendVariantsGenerated(_ content: String) { messageSender.sendVariantsGenerated(content) }
    func sendStoreContext(text: String, replace: Bool) { messageSender.sendStoreContext(text: text, replace: replace) }
    func sendSuccess() { messageSender.sendSuccess() }
    func sendError(_ error: String) { messageSender.sendError(error) }
    func sendProviderAuthFailure(provider: String, message: String) {
        messageSender.sendProviderAuthFailure(provider: provider, message: message)
    }
    func sendNotEditable(_ reason: String) { messageSender.sendNotEditable(reason) }
    func sendOpenSettings() { messageSender.sendOpenSettings() }
    func sendTimingData(model: String, seconds: Double) { messageSender.sendTimingData(model: model, seconds: seconds) }
}

// MARK: - Update Method Handlers
extension MethodChannelHandler {
    func handleCheckForUpdates(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        #if DEBUG
        print("MethodChannelHandler: checkForUpdates called")
        #endif

        // Set up the callback to receive the result
        SparkleUpdater.shared.onUpdateCheckComplete = { success, error in
            DispatchQueue.main.async {
                if success {
                    result(["success": true, "error": NSNull()])
                } else {
                    result(["success": false, "error": error ?? "Unknown error"])
                }
            }
            // Clear the callback after use
            SparkleUpdater.shared.onUpdateCheckComplete = nil
        }

        // Trigger the update check
        SparkleUpdater.shared.checkForUpdates()
    }

    func handleGetAppVersion(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = info?["CFBundleVersion"] as? String ?? "Unknown"
        let bundleId = Bundle.main.bundleIdentifier ?? ""

        let releaseChannel: String
        if bundleId.hasSuffix(".nightly") {
            releaseChannel = "nightly"
        } else if bundleId.hasSuffix(".beta") {
            releaseChannel = "beta"
        } else {
            releaseChannel = "stable"
        }

        result([
            "version": version,
            "build": build,
            "releaseChannel": releaseChannel
        ])
    }

    func handleGetLastUpdateCheck(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let lastCheck = SparkleUpdater.shared.lastUpdateCheckDate {
            // Return ISO 8601 formatted date string
            let formatter = ISO8601DateFormatter()
            result(formatter.string(from: lastCheck))
        } else {
            result(nil)
        }
    }

    func handleGetAutomaticUpdateChecks(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(SparkleUpdater.shared.automaticallyChecksForUpdates)
    }

    func handleSetAutomaticUpdateChecks(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let enabled = call.arguments as? Bool else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "Argument must be a boolean",
                details: nil
            ))
            return
        }
        #if DEBUG
        print("MethodChannelHandler: setAutomaticUpdateChecks called with: \(enabled)")
        #endif
        SparkleUpdater.shared.automaticallyChecksForUpdates = enabled
        result(nil)
    }
}
