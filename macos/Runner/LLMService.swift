import Foundation
import os.log

/// Service for communicating with LLM APIs (OpenAI, OpenRouter, etc.)
class LLMService {
    struct ScreenshotAttachment {
        let mimeType: String
        let base64Data: String

        var dataURL: String {
            "data:\(mimeType);base64,\(base64Data)"
        }
    }

    struct Configuration {
        let provider: String
        let apiKey: String
        let openRouterApiKey: String
        var anthropicApiKey: String = AppDefaults.apiKey
        let customProviderApiKey: String
        let customProviderBaseUrl: String?
        let model: String
        let customPrompt: String?
        let context: String?
        let targetProfileInstruction: String?
        let screenshotAttachment: ScreenshotAttachment?
        let accessibilityContext: AccessibilityContext?
        var reasoningEffort: ReasoningEffort = AppDefaults.reasoningEffort
        /// Why the Accessibility read could not serve as context. Only
        /// reported in debug logs; it never reaches the prompt.
        var accessibilityFallbackReason: AccessibilityContext.UnusableReason?

        /// The key for `provider`: built-in providers have their own keys,
        /// every other provider uses the custom provider key.
        var activeApiKey: String {
            if provider == AppDefaults.openRouterProvider {
                return openRouterApiKey
            }
            if provider == AppDefaults.openAiProvider {
                return apiKey
            }
            if provider == AppDefaults.anthropicProvider {
                return anthropicApiKey
            }
            return customProviderApiKey
        }
    }

    private let logger = OSLog(
        subsystem: "com.makeitsoundnatural.macos",
        category: "LLMService"
    )
    let environment: [String: String]

    private let session: URLSession

    weak var delegate: LLMServiceDelegate?

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        session: URLSession = .shared
    ) {
        self.environment = environment
        self.session = session
    }

    func processText(
        _ text: String,
        config: Configuration,
        completion: @escaping (String?, String?) -> Void
    ) {
        let provider = config.provider
        let model = config.model
        log("Using provider: \(provider), model: \(model)")
        log(
            "Target profile instruction: " +
            targetProfileLogValue(config.targetProfileInstruction)
        )

        if let configurationError = configurationError(for: config) {
            delegate?.llmService(
                self,
                didFailWithError: configurationError,
                isAuthenticationFailure: false,
                provider: provider
            )
            completion(nil, configurationError)
            return
        }

        #if DEBUG
        debugLog("═══════════════ LLM REQUEST ═══════════════")
        debugLog("Original message length: \(text.count)")
        debugLog("───────────────────────────────────────────")
        debugLog("Model: \(model)")
        debugLog("Provider: \(provider)")
        debugLog("───────────────────────────────────────────")
        for line in debugRequestContextLines(config: config) {
            debugLog(line)
        }
        debugLog("═══════════════════════════════════════════")
        #endif

        let finalInstructions = buildFinalSystemInstructions(
            text: text,
            config: config
        )

        #if DEBUG
        debugLog("System prompt length: \(finalInstructions.count)")
        debugLog("═══════════════════════════════════════════")
        #endif

        executeRequest(
            text: text,
            config: config,
            systemInstructions: finalInstructions,
            format: LLMWireFormatFactory.forProvider(provider),
            completion: completion
        )
    }

    /// The editable prompt and fixed rules, then the manual `Context:`, the
    /// `<app_context>` section and the screenshot note, in that order.
    func buildFinalSystemInstructions(
        text: String,
        config: Configuration
    ) -> String {
        let systemInstructions = buildSystemPrompt(
            customPrompt: config.customPrompt,
            targetProfileInstruction: config.targetProfileInstruction
        )
        let withContext = appendContextIfNeeded(
            systemInstructions: systemInstructions,
            userText: text,
            context: config.context ?? "",
            model: config.model
        )
        let withAppContext = appendAppContextIfNeeded(
            systemInstructions: withContext,
            context: config.accessibilityContext
        )
        return appendScreenshotInstructionIfNeeded(
            systemInstructions: withAppContext,
            hasScreenshot: config.screenshotAttachment != nil
        )
    }

    func buildSystemPrompt(
        customPrompt: String?,
        targetProfileInstruction: String?
    ) -> String {
        let editablePrompt: String
        if let custom = customPrompt, !custom.isEmpty {
            log("Using custom prompt (length: \(custom.count))")
            editablePrompt = custom
        } else {
            log("Using default prompt")
            editablePrompt = PromptTemplates.defaultCustomizablePrompt
        }

        return editablePrompt
            + PromptTemplates.targetProfileSection(
                instruction: targetProfileInstruction
            )
            + PromptTemplates.fixedPromptSection
    }

    private func targetProfileLogValue(_ instruction: String?) -> String {
        guard let instruction = instruction?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !instruction.isEmpty else {
            return "(none; PromptTemplates fallback will use American English)"
        }

        return "configured (length: \(instruction.count))"
    }

    private func appendContextIfNeeded(
        systemInstructions: String,
        userText: String,
        context: String,
        model: String
    ) -> String {
        guard !context.isEmpty else { return systemInstructions }

        let truncatedContext = TokenCounter.truncateContextIfNeeded(
            systemInstructions: systemInstructions,
            userText: userText,
            context: context,
            model: model,
            logger: { [weak self] message in self?.log(message) }
        )

        guard !truncatedContext.isEmpty else { return systemInstructions }

        return systemInstructions + "\n\nContext:\n\(truncatedContext)"
    }
}

extension LLMService {
    private func configurationError(for config: Configuration) -> String? {
        if config.activeApiKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty {
            return "Add an API key for the selected provider in Settings."
        }

        if config.model
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty {
            return "Add a model for the selected provider in Settings."
        }

        return nil
    }

    func appendScreenshotInstructionIfNeededForTesting(
        systemInstructions: String,
        hasScreenshot: Bool
    ) -> String {
        appendScreenshotInstructionIfNeeded(
            systemInstructions: systemInstructions,
            hasScreenshot: hasScreenshot
        )
    }

    private func appendAppContextIfNeeded(
        systemInstructions: String,
        context: AccessibilityContext?
    ) -> String {
        guard let context = context,
              let section = PromptTemplates.appContextSection(context) else {
            return systemInstructions
        }
        return systemInstructions + "\n\n" + section
    }

    private func appendScreenshotInstructionIfNeeded(
        systemInstructions: String,
        hasScreenshot: Bool
    ) -> String {
        guard hasScreenshot else { return systemInstructions }
        return systemInstructions + """


Screenshot context:
The screenshot is context only: the app window, or the part of it around the
field the user is typing in. Use it to see who wrote what and what the
conversation, document, or product state is. Rewrite only the selected text.
Do not describe the screenshot. Do not add new facts from the screenshot unless
they are needed to preserve the selected text's intended meaning. When
app_context is also present, it is the exact text; if the two disagree, trust
app_context.
"""
    }

    private func executeRequest(
        text: String,
        config: Configuration,
        systemInstructions: String,
        format: LLMWireFormat,
        completion: @escaping (String?, String?) -> Void
    ) {
        let provider = config.provider
        let model = config.model
        guard let request = format.makeRequest(
            text: text,
            config: config,
            systemInstructions: systemInstructions
        ) else {
            reportErrorResponse(
                .init(message: "Failed to encode payload", isAuthenticationFailure: false),
                provider: provider,
                completion: completion
            )
            return
        }
        let startTime = Date()

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            let elapsed = Date().timeIntervalSince(startTime)
            self.log("Network request finished in \(String(format: "%.3f", elapsed))s")

            if let error = error {
                self.handleNetworkError(
                    error,
                    provider: provider,
                    completion: completion
                )
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self.log("Error: Invalid response type")
                self.delegate?.llmService(
                    self,
                    didFailWithError: "Invalid response",
                    isAuthenticationFailure: false,
                    provider: provider
                )
                completion(nil, nil)
                return
            }

            self.log("HTTP Status Code: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                let errorInfo = self.parseErrorInfo(
                    from: data,
                    statusCode: httpResponse.statusCode
                )
                if !errorInfo.isAuthenticationFailure,
                   let retryFormat = format.retrying(
                       afterErrorData: data,
                       statusCode: httpResponse.statusCode
                   ) {
                    self.executeRequest(
                        text: text,
                        config: config,
                        systemInstructions: systemInstructions,
                        format: retryFormat,
                        completion: completion
                    )
                    return
                }

                self.reportErrorResponse(
                    errorInfo,
                    provider: provider,
                    completion: completion
                )
                return
            }

            guard let data = data else {
                self.log("Error: No data received")
                self.delegate?.llmService(
                    self,
                    didFailWithError: "No response data from AI service.",
                    isAuthenticationFailure: false,
                    provider: provider
                )
                completion(nil, nil)
                return
            }

            self.handleSuccessResponse(
                data: data,
                format: format,
                elapsedNetwork: elapsed,
                provider: provider,
                model: model,
                completion: completion
            )
        }
        task.resume()
    }

    private func handleNetworkError(
        _ error: Error,
        provider: String,
        completion: @escaping (String?, String?) -> Void
    ) {
        let message = "Network error: \(error.localizedDescription)"
        log("Error: \(message)")
        delegate?.llmService(
            self,
            didFailWithError: message,
            isAuthenticationFailure: false,
            provider: provider
        )
        completion(nil, message)
    }

    private func reportErrorResponse(
        _ errorInfo: LLMErrorMessageParser.ErrorInfo,
        provider: String,
        completion: @escaping (String?, String?) -> Void
    ) {
        delegate?.llmService(
            self,
            didFailWithError: errorInfo.message,
            isAuthenticationFailure: errorInfo.isAuthenticationFailure,
            provider: provider
        )
        completion(nil, errorInfo.message)
    }

    private func parseErrorInfo(
        from data: Data?,
        statusCode: Int
    ) -> LLMErrorMessageParser.ErrorInfo {
        guard let data = data, !data.isEmpty else {
            log("Error: HTTP Error: \(statusCode)")
            return LLMErrorMessageParser.errorInfo(from: nil, statusCode: statusCode)
        }

        if let errorBody = String(data: data, encoding: .utf8) {
            log("Error: API Error Body: \(errorBody)")
        }

        return LLMErrorMessageParser.errorInfo(from: data, statusCode: statusCode)
    }

    private func handleSuccessResponse(
        data: Data,
        format: LLMWireFormat,
        elapsedNetwork: TimeInterval,
        provider: String,
        model: String,
        completion: @escaping (String?, String?) -> Void
    ) {
        let content: String
        switch format.variantsContent(from: data) {
        case .success(let variantsContent):
            content = variantsContent
        case .failure(let failure):
            log("Error: \(failure.message)")
            delegate?.llmService(
                self,
                didFailWithError: failure.message,
                isAuthenticationFailure: false,
                provider: provider
            )
            completion(nil, failure.message)
            return
        }

        log("Successfully parsed content. Length: \(content.count)")

        delegate?.llmService(self, didReceiveTimingData: (model, elapsedNetwork))

        let fullContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let bestVariant = extractVariant(from: fullContent)

        #if DEBUG
        debugLog("═══════════════ LLM RESPONSE ══════════════")
        debugLog("Full content:\n\(fullContent)")
        debugLog("───────────────────────────────────────────")
        debugLog("Selected variant:\n\(bestVariant)")
        debugLog("═══════════════════════════════════════════")
        #endif

        completion(fullContent, bestVariant)
    }

    private func log(_ message: String) {
        os_log("%{private}@", log: logger, type: .debug, message)
        #if DEBUG
        let timestamp = Date().timeIntervalSince1970
        print("⏱️ [\(String(format: "%.3f", timestamp))] \(message)")
        #endif
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("🔍 [DEBUG] \(message)")
        #endif
    }
}
protocol LLMServiceDelegate: AnyObject {
    func llmService(
        _ service: LLMService,
        didFailWithError error: String,
        isAuthenticationFailure: Bool,
        provider: String
    )
    func llmService(_ service: LLMService, didReceiveTimingData: (String, TimeInterval))
}

extension LLMService {
    func extractVariant(
        from content: String,
        variant: String = AppDefaults.variant
    ) -> String {
        log("Extracting variant: \(variant)")
        let markers = [
            "Balanced": ("---BALANCED---", "---CASUAL---"),
            "Casual": ("---CASUAL---", "---FORMAL---"),
            "Formal": ("---FORMAL---", "---CONCISE---"),
            "Concise": ("---CONCISE---", nil)
        ]
        guard let (startMarker, endMarker) = markers[variant] else {
            return extractVariant(from: content, variant: "Balanced")
        }
        guard let range = content.range(of: startMarker) else { return content }
        let startIndex = range.upperBound
        if let endMarker = endMarker,
           let endRange = content.range(of: endMarker, range: startIndex..<content.endIndex) {
            let extracted = String(content[startIndex..<endRange.lowerBound])
            return extracted.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return String(content[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// The variant to paste, or nil when the model left it blank: structured
    /// output guarantees the keys, not that their values hold any text.
    func pasteableVariant(from content: String, variant: String) -> String? {
        let extracted = extractVariant(from: content, variant: variant)
        return extracted.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ? nil : extracted
    }
}
