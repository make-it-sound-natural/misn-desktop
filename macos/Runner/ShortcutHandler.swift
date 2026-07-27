import Cocoa
import Carbon
import os.log

class ShortcutHandler: ShortcutManagerDelegate, LLMServiceDelegate,
                       ContextCapturerDelegate, VariantHandlerDelegate {
    private var methodChannelHandler: MethodChannelHandler?
    private var shortcutManager: ShortcutManager?
    private var textReplacer: TextReplacer?
    private var llmService: LLMService
    private var contextCapturer: ContextCapturer
    private var variantHandler: VariantHandler
    private var dispatcher = ShortcutDispatcher()

    private let statusBubble: StatusBubbleControlling
    private let screenshotCapturer: ScreenshotCapturing
    private let screenshotDebugSaver: ScreenshotDebugSaver

    private var lastActiveAppBundleId: String?

    /// The exact text this app last pasted into another application, together
    /// with where it went.
    ///
    /// Cleared whenever a run starts or its paste is skipped, so a stale value
    /// can never authorise an undo in an app we did not just write to. Text
    /// and destination live in one value because they are only ever true as a
    /// pair — recording them separately let a second run pair the text of one
    /// run with the destination of the next.
    ///
    /// Owned by the main queue. The completion arrives on a `URLSession`
    /// thread and `TextReplacer` reports from a background queue, so an
    /// unsynchronised pair would be a data race, and the undo decision would
    /// be read while another thread was halfway through rewriting it.
    private var lastPaste: (text: String, bundleId: String)?
    private var lastActiveWindowID: CGWindowID?
    private var lastCursorPosition: NSPoint?

    /// True only during global-shortcut `processText` (not Flutter `generateVariants`).
    private var shortcutLlmInvocationActive = false
    /// Last error from `LLMServiceDelegate` for the active shortcut LLM call.
    private var lastShortcutLlmError: String?

    private let logger = OSLog(
        subsystem: "com.makeitsoundnatural.macos",
        category: "ShortcutHandler"
    )

    static var defaultCustomizablePrompt: String {
        PromptTemplates.defaultCustomizablePrompt
    }

    /// - Parameters:
    ///   - methodChannelHandler: Flutter bridge; `nil` only for unit tests.
    ///   - statusBubble: Injected bubble; default is `StatusBubble.shared`.
    init(
        methodChannelHandler: MethodChannelHandler? = nil,
        statusBubble: StatusBubbleControlling = StatusBubble.shared,
        screenshotCapturer: ScreenshotCapturing = ScreenshotCapturer(),
        screenshotDebugSaver: ScreenshotDebugSaver = ScreenshotDebugSaver()
    ) {
        self.methodChannelHandler = methodChannelHandler
        self.statusBubble = statusBubble
        self.screenshotCapturer = screenshotCapturer
        self.screenshotDebugSaver = screenshotDebugSaver
        self.llmService = LLMService()
        self.contextCapturer = ContextCapturer()
        self.variantHandler = VariantHandler()

        self.shortcutManager = ShortcutManager(delegate: self)
        self.textReplacer = TextReplacer()

        self.llmService.delegate = self
        self.contextCapturer.delegate = self
        self.variantHandler.delegate = self
        self.dispatcher.actionHandler = self

        setupMethodChannelCallbacks()
    }

    private func setupMethodChannelCallbacks() {
        self.methodChannelHandler?.onGenerateVariants = { [weak self] text, completion in
            guard let self = self,
                  let apiKey = self.methodChannelHandler?.getApiKey(),
                  let model = self.methodChannelHandler?.getModel() else {
                completion(nil, "Configuration error")
                return
            }

            if self.methodChannelHandler?.requiresTargetProfileSelection() == true {
                let message = "Choose a target language before rewriting."
                self.methodChannelHandler?.sendError(message)
                self.methodChannelHandler?.sendOpenSettings()
                completion(nil, message)
                return
            }

            let config = LLMService.Configuration(
                provider: self.methodChannelHandler?.getProvider()
                    ?? AppDefaults.apiProvider,
                apiKey: apiKey,
                openRouterApiKey: self.methodChannelHandler?
                    .getOpenRouterApiKey() ?? AppDefaults.apiKey,
                customProviderApiKey: self.methodChannelHandler?
                    .getCustomProviderApiKey(
                        provider: self.methodChannelHandler?.getProvider()
                            ?? AppDefaults.apiProvider
                    ) ?? AppDefaults.apiKey,
                customProviderBaseUrl: self.methodChannelHandler?
                    .getCustomProviderBaseUrl(),
                model: model,
                customPrompt: self.methodChannelHandler?.getCustomPrompt(),
                context: self.methodChannelHandler?.getContext(),
                targetProfileInstruction: self.methodChannelHandler?.getTargetProfileInstruction(),
                screenshotAttachment: nil
            )

            // Surface the failure instead of reporting an empty success:
            // the Dart side turns an error into the auth-failure banner, and
            // a nil body with no error reads as "the model returned nothing".
            self.llmService.processText(text, config: config) { fullContent, error in
                if fullContent == nil {
                    completion(nil, error ?? "Request failed. Try again.")
                } else {
                    completion(fullContent, nil)
                }
            }
        }

        self.methodChannelHandler?.onUpdateCorrectionShortcut = { [weak self] shortcut in
            self?.shortcutManager?.updateCorrectionShortcut(shortcut)
        }

        self.methodChannelHandler?.onUpdateReplaceShortcut = { [weak self] shortcut in
            self?.shortcutManager?.updateReplaceShortcut(shortcut)
        }

        self.methodChannelHandler?.onUpdateAppendShortcut = { [weak self] shortcut in
            self?.shortcutManager?.updateAppendShortcut(shortcut)
        }

        self.methodChannelHandler?.onValidateShortcut = { [weak self] (shortcut, completion) in
            self?.shortcutManager?.validateShortcut(shortcut, completion: completion)
        }

        self.methodChannelHandler?.onDisableShortcuts = { [weak self] in
            self?.shortcutManager?.disableShortcuts()
        }

        self.methodChannelHandler?.onEnableShortcuts = { [weak self] in
            self?.shortcutManager?.enableShortcuts()
        }
    }

    private func log(_ message: String) {
        os_log("%{private}@", log: logger, type: .debug, message)
        #if DEBUG
        let timestamp = Date().timeIntervalSince1970
        print("⏱️ [\(String(format: "%.3f", timestamp))] \(message)")
        #endif
    }

    func registerShortcut() {
        shortcutManager?.registerShortcut()
    }

    func replaceTextInOriginalApp(
        _ text: String,
        completion: @escaping (Bool) -> Void
    ) {
        // The paste record is owned by the main queue, so read it there.
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let textReplacer = self.textReplacer else {
                completion(false)
                return
            }

            let target = self.lastActiveAppBundleId
            let pasted = self.lastPaste.flatMap {
                $0.bundleId == target ? $0.text : nil
            }

            textReplacer.replaceTextInOriginalApp(
                text,
                lastActiveAppBundleId: target,
                previouslyPastedText: pasted
            ) { [weak self] replaced in
                // TextReplacer reports on the main queue.
                if let self = self {
                    // Track what now sits in the field so a second swap can
                    // undo it; a skipped swap leaves nothing to undo.
                    if replaced, let target = target {
                        self.lastPaste = (text: text, bundleId: target)
                    } else {
                        self.lastPaste = nil
                    }
                }
                completion(replaced)
            }
        }
    }

    private func captureAndProcessText() {
        guard validateEditability() else { return }
        trackActiveApplication()
        performTextCaptureAndProcess()
    }

    private func validateEditability() -> Bool {
        let editabilityResult = AccessibilityHelper.checkFocusedElementIsEditable()
        if !editabilityResult.isEditable {
            log("Focused element is not editable: \(editabilityResult.reason ?? "unknown reason")")
            methodChannelHandler?.sendNotEditable(
                editabilityResult.reason ?? "Focus on a text field to use this shortcut"
            )
            return false
        }
        return true
    }

    private func trackActiveApplication() {
        DispatchQueue.main.async {
            // A new run invalidates any earlier paste we might have undone.
            // Cleared on the same queue that owns the record, and in the same
            // block that records the new front app, so the two can never be
            // observed out of step.
            self.lastPaste = nil
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                self.lastActiveAppBundleId = frontApp.bundleIdentifier
                self.lastActiveWindowID = AccessibilityHelper.focusedWindowID(
                    for: frontApp
                )
                self.log("Active app captured: \(self.lastActiveAppBundleId ?? "unknown")")
                let windowID = self.lastActiveWindowID.map(String.init)
                    ?? "unknown"
                self.log("Active window id captured: \(windowID)")
            }

            self.lastCursorPosition = NSEvent.mouseLocation
            if let cursorPos = self.lastCursorPosition {
                self.log("Cursor position captured: \(cursorPos)")
                self.statusBubble.show(at: cursorPos, state: .processing)
            }
        }
    }

    private func performTextCaptureAndProcess() {
        log("Starting text capture sequence")

        ClipboardService.captureSelectedText(
            simulateKeyPress: { [weak self] in
                self?.simulateKeyPress(keyCode: CGKeyCode(kVK_ANSI_C), flags: .maskCommand)
            },
            completion: { [weak self] captureResult in
                guard let self = self else { return }

                guard let selectedText = captureResult.text, !selectedText.isEmpty else {
                    self.handleCaptureFailure(captureResult.previousContent)
                    return
                }

                self.log("Text captured (length: \(selectedText.count)). Sending to UI.")
                self.methodChannelHandler?.sendTextCaptured(selectedText)

                self.log("Calling OpenAI API...")
                guard let apiKey = self.methodChannelHandler?.getApiKey(),
                      let model = self.methodChannelHandler?.getModel() else {
                    self.handleCaptureFailure(captureResult.previousContent)
                    return
                }

                if self.methodChannelHandler?.requiresTargetProfileSelection() == true {
                    let message = "Choose a target language before rewriting."
                    self.methodChannelHandler?.sendError(message)
                    self.methodChannelHandler?.sendOpenSettings()
                    self.handleLlmFailure(
                        previousClipboard: captureResult.previousContent,
                        message: message
                    )
                    return
                }

                Task { [weak self] in
                    guard let self = self else { return }
                    let screenshotMode = self.methodChannelHandler?
                        .getScreenshotContextMode() ?? .off
                    self.log("Screenshot context mode: \(screenshotMode.rawValue)")
                    let screenshotResult: ScreenshotCaptureResult
                    if screenshotMode == .off {
                        screenshotResult = ScreenshotCaptureResult(
                            attachment: nil,
                            warning: nil
                        )
                    } else {
                        screenshotResult = await self.screenshotCapturer.capture(
                            mode: screenshotMode,
                            activeBundleId: self.lastActiveAppBundleId,
                            activeWindowID: self.lastActiveWindowID,
                            cursorLocation: self.lastCursorPosition
                        )
                        let captured = screenshotResult.attachment == nil
                            ? "no"
                            : "yes"
                        self.log("Screenshot context captured: \(captured)")
                    }

                    if let warning = screenshotResult.warning {
                        self.log("Screenshot context warning: \(warning)")
                        self.methodChannelHandler?.sendError(warning)
                    }

                    if let attachment = screenshotResult.attachment {
                        _ = self.screenshotDebugSaver.saveIfEnabled(
                            attachment: attachment,
                            mode: screenshotMode
                        )
                    }

                    let provider = self.methodChannelHandler?
                        .getProvider() ?? AppDefaults.apiProvider
                    let screenshotAttachment = screenshotResult.attachment

                    let defaultVariant = self.methodChannelHandler?
                        .getDefaultVariant() ?? AppDefaults.variant
                    let config = LLMService.Configuration(
                        provider: provider,
                        apiKey: apiKey,
                        openRouterApiKey: self.methodChannelHandler?
                            .getOpenRouterApiKey() ?? AppDefaults.apiKey,
                        customProviderApiKey: self.methodChannelHandler?
                            .getCustomProviderApiKey(provider: provider)
                            ?? AppDefaults.apiKey,
                        customProviderBaseUrl: self.methodChannelHandler?
                            .getCustomProviderBaseUrl(),
                        model: model,
                        customPrompt: self.methodChannelHandler?.getCustomPrompt(),
                        context: self.methodChannelHandler?.getContext(),
                        targetProfileInstruction: self.methodChannelHandler?.getTargetProfileInstruction(),
                        screenshotAttachment: screenshotAttachment
                    )

                    self.startLlmProcessing(
                        selectedText: selectedText,
                        defaultVariant: defaultVariant,
                        config: config,
                        previousClipboard: captureResult.previousContent
                    )
                }
            }
        )
    }

    private func startLlmProcessing(
        selectedText: String,
        defaultVariant: String,
        config: LLMService.Configuration,
        previousClipboard: String?
    ) {
        shortcutLlmInvocationActive = true
        lastShortcutLlmError = nil
        llmService.processText(selectedText, config: config) { fullContent, _ in
            let savedError = self.lastShortcutLlmError
            self.shortcutLlmInvocationActive = false
            self.lastShortcutLlmError = nil

            guard let fullContent = fullContent else {
                let message = savedError ?? "Request failed. Try again."
                self.handleLlmFailure(
                    previousClipboard: previousClipboard,
                    message: message
                )
                return
            }

            let variant = self.llmService.extractVariant(
                from: fullContent,
                variant: defaultVariant
            )

            let processingContext = VariantHandler.ProcessingContext(
                fullContent: fullContent,
                correctedText: variant,
                previousClipboard: previousClipboard,
                lastActiveAppBundleId: self.lastActiveAppBundleId,
                simulateKeyPress: self.simulateKeyPress,
                log: self.log
            )

            self.variantHandler.handleProcessingResult(processingContext)
        }
    }

    private func handleCaptureFailure(_ previousClipboard: String?) {
        log("Error: No text selected or copy failed")
        methodChannelHandler?.sendError("No text selected or copy failed")
        DispatchQueue.main.async {
            self.statusBubble.hide()
        }
        if let old = previousClipboard {
            ClipboardService.restore(old)
        }
    }

    /// LLM or network failure after text was captured (not a capture failure).
    /// `sendError` was already sent from `LLMServiceDelegate`.
    private func handleLlmFailure(previousClipboard: String?, message: String) {
        log("LLM request failed: \(message)")
        DispatchQueue.main.async {
            self.statusBubble.updateState(.error(message: message))
        }
        if let old = previousClipboard {
            ClipboardService.restore(old)
        }
    }

    private func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = flags
        keyUp?.flags = flags

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - ShortcutManagerDelegate

    func shortcutManager(_ manager: ShortcutManager, didTriggerHotKeyWithID id: UInt32) {
        log("Shortcut triggered with ID: \(id)")
        dispatcher.dispatch(shortcutID: id)
    }

    // MARK: - LLMServiceDelegate

    func llmService(
        _ service: LLMService,
        didFailWithError error: String,
        isAuthenticationFailure: Bool,
        provider: String
    ) {
        log("LLM Service Error: \(error)")
        if shortcutLlmInvocationActive {
            lastShortcutLlmError = error
        }
        methodChannelHandler?.sendError(error)
        if isAuthenticationFailure {
            methodChannelHandler?.sendProviderAuthFailure(
                provider: provider,
                message: error
            )
        }
    }

    func llmService(_ service: LLMService, didReceiveTimingData: (String, TimeInterval)) {
        let (model, duration) = didReceiveTimingData
        log("LLM timing - Model: \(model), Duration: \(duration)s")
        methodChannelHandler?.sendTimingData(model: model, seconds: duration)
    }

    // MARK: - ContextCapturerDelegate

    func contextCapturer(_ capturer: ContextCapturer, didCaptureText text: String, replace: Bool) {
        log("Context captured (length: \(text.count), replace: \(replace))")
        methodChannelHandler?.sendStoreContext(text: text, replace: replace)
    }

    func contextCapturer(_ capturer: ContextCapturer, didFailWithError error: String) {
        log("Context capture error: \(error)")
        methodChannelHandler?.sendError(error)
    }

    func contextCapturer(_ capturer: ContextCapturer, didFailWithNotEditable reason: String) {
        log("Not editable: \(reason)")
        methodChannelHandler?.sendNotEditable(reason)
    }

    // MARK: - VariantHandlerDelegate

    func variantHandler(_ handler: VariantHandler, didGenerateVariants content: String) {
        log("Variants generated (length: \(content.count))")
        methodChannelHandler?.sendVariantsGenerated(content)
    }

    func variantHandler(_ handler: VariantHandler, didFailWithError error: String) {
        log("Variant handler error: \(error)")
        methodChannelHandler?.sendError(error)
    }

    func variantHandler(_ handler: VariantHandler, didChangeWindow: Bool) {
        if didChangeWindow {
            log("Window changed during processing")
            methodChannelHandler?.sendStatus("window_changed")
        }
    }

    func variantHandler(
        _ handler: VariantHandler,
        didCompleteSuccessfully: Bool,
        pastedText: String?,
        inApp bundleId: String?
    ) {
        guard didCompleteSuccessfully else { return }
        log("Processing completed successfully")

        // Only this branch actually pastes, so only it may authorise a later
        // undo. Arrives on the URLSession callback thread; hop to the queue
        // that owns the record.
        if let pastedText = pastedText, let bundleId = bundleId {
            DispatchQueue.main.async {
                self.lastPaste = (text: pastedText, bundleId: bundleId)
            }
        }
        methodChannelHandler?.sendSuccess()
        // `updateState(.success)` already schedules auto-dismiss; do not hide here.
    }
}

// MARK: - ShortcutActionHandler

extension ShortcutHandler: ShortcutActionHandler {
    func performCorrection() {
        captureAndProcessText()
    }

    func captureContext(replace: Bool) {
        contextCapturer.captureAndStoreContext(replace: replace)
    }
}
