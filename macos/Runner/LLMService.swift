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
        let customProviderApiKey: String
        let customProviderBaseUrl: String?
        let model: String
        let customPrompt: String?
        let context: String?
        let targetProfileInstruction: String?
        let screenshotAttachment: ScreenshotAttachment?
    }

    private let logger = OSLog(
        subsystem: "com.makeitsoundnatural.macos",
        category: "LLMService"
    )
    let environment: [String: String]

    weak var delegate: LLMServiceDelegate?

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
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

        let systemInstructions = buildSystemPrompt(
            customPrompt: config.customPrompt,
            targetProfileInstruction: config.targetProfileInstruction
        )
        let finalInstructions = appendContextIfNeeded(
            systemInstructions: systemInstructions,
            userText: text,
            context: config.context ?? "",
            model: model
        )
        let finalInstructionsWithScreenshot = appendScreenshotInstructionIfNeeded(
            systemInstructions: finalInstructions,
            hasScreenshot: config.screenshotAttachment != nil
        )

        #if DEBUG
        debugLog("System prompt length: \(finalInstructionsWithScreenshot.count)")
        debugLog("═══════════════════════════════════════════")
        #endif

        guard let request = buildRequest(
            text: text,
            config: config,
            systemInstructions: finalInstructionsWithScreenshot,
            includeResponseFormat: true
        ) else {
            delegate?.llmService(
                self,
                didFailWithError: "Failed to encode payload",
                isAuthenticationFailure: false,
                provider: provider
            )
            completion(nil, nil)
            return
        }

        let fallbackRequest = responseFormatFallbackRequest(
            text: text,
            config: config,
            systemInstructions: finalInstructionsWithScreenshot
        )

        executeRequest(
            request,
            provider: provider,
            model: model,
            fallbackRequest: fallbackRequest,
            completion: completion
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

    private func buildRequest(
        text: String,
        config: Configuration,
        systemInstructions: String,
        includeResponseFormat: Bool
    ) -> URLRequest? {
        guard let url = requestUrl(for: config) else {
            log("Error: Invalid URL for provider \(config.provider)")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        configureRequestHeaders(&request, config: config)

        let payload = buildPayload(
            text: text,
            config: config,
            systemInstructions: systemInstructions,
            includeResponseFormat: includeResponseFormat
        )

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            return request
        } catch {
            log("Error: Failed to encode payload: \(error.localizedDescription)")
            return nil
        }
    }

    private func requestUrl(for config: Configuration) -> URL? {
        let rawUrl: String
        if config.provider == AppDefaults.openRouterProvider {
            rawUrl = "https://openrouter.ai/api/v1/chat/completions"
        } else if config.provider == "openai" {
            rawUrl = "https://api.openai.com/v1/chat/completions"
        } else {
            rawUrl = normalizeChatCompletionsUrl(
                config.customProviderBaseUrl ?? ""
            )
        }
        return URL(string: rawUrl)
    }

    private func normalizeChatCompletionsUrl(_ rawUrl: String) -> String {
        let trimmed = rawUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasSuffix("/chat/completions") {
            return trimmed
        }
        return "\(trimmed)/chat/completions"
    }

    private func configureRequestHeaders(_ request: inout URLRequest, config: Configuration) {
        let activeApiKey = activeApiKey(config: config)
        request.setValue("Bearer \(activeApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if config.provider == AppDefaults.openRouterProvider {
            request.setValue(AppDefaults.appName, forHTTPHeaderField: "X-Title")
        }
    }

    private func activeApiKey(config: Configuration) -> String {
        if config.provider == AppDefaults.openRouterProvider {
            return config.openRouterApiKey
        }
        if config.provider == "openai" {
            return config.apiKey
        }
        return config.customProviderApiKey
    }
}

extension LLMService {
    private func configurationError(for config: Configuration) -> String? {
        if activeApiKey(config: config)
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

    private func isBuiltInProvider(_ provider: String) -> Bool {
        provider == AppDefaults.openRouterProvider || provider == "openai"
    }

    private func responseFormatFallbackRequest(
        text: String,
        config: Configuration,
        systemInstructions: String
    ) -> URLRequest? {
        guard !isBuiltInProvider(config.provider) else { return nil }

        return buildRequest(
            text: text,
            config: config,
            systemInstructions: fallbackJsonInstructions(systemInstructions),
            includeResponseFormat: false
        )
    }

    private func fallbackJsonInstructions(_ systemInstructions: String) -> String {
        systemInstructions + """


<provider_compatibility_output_format>
The provider does not support the response_format request parameter. Return
ONLY a valid JSON object with exactly these string keys: balanced, casual,
formal, concise. Do not wrap it in markdown. Do not add commentary.
</provider_compatibility_output_format>
"""
    }

    func buildRequestForTesting(
        text: String,
        config: Configuration,
        systemInstructions: String
    ) -> URLRequest? {
        buildRequest(
            text: text,
            config: config,
            systemInstructions: systemInstructions,
            includeResponseFormat: true
        )
    }

    func buildPayloadForTesting(
        text: String,
        config: Configuration,
        systemInstructions: String,
        includeResponseFormat: Bool
    ) -> [String: Any] {
        buildPayload(
            text: text,
            config: config,
            systemInstructions: systemInstructions,
            includeResponseFormat: includeResponseFormat
        )
    }

    func buildPayloadForTesting(
        text: String,
        config: Configuration,
        systemInstructions: String
    ) -> [String: Any] {
        buildPayload(
            text: text,
            config: config,
            systemInstructions: systemInstructions,
            includeResponseFormat: true
        )
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

    private func buildPayload(
        text: String,
        config: Configuration,
        systemInstructions: String,
        includeResponseFormat: Bool
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": systemInstructions],
                [
                    "role": "user",
                    "content": userMessageContent(
                        text: text,
                        screenshotAttachment: config.screenshotAttachment
                    )
                ]
            ]
        ]
        if includeResponseFormat {
            payload["response_format"] = [
                "type": "json_schema",
                "json_schema": [
                    "name": "correction_variants",
                    "strict": true,
                    "schema": [
                        "type": "object",
                        "properties": [
                            "balanced": ["type": "string"],
                            "casual": ["type": "string"],
                            "formal": ["type": "string"],
                            "concise": ["type": "string"]
                        ],
                        "required": ["balanced", "casual", "formal", "concise"],
                        "additionalProperties": false
                    ]
                ]
            ]
        }
        if config.provider == "openai" {
            payload["service_tier"] = "priority"
        }
        return payload
    }

    private func userMessageContent(
        text: String,
        screenshotAttachment: ScreenshotAttachment?
    ) -> Any {
        guard let screenshotAttachment = screenshotAttachment else {
            return text
        }

        return [
            ["type": "text", "text": text],
            [
                "type": "image_url",
                "image_url": [
                    "url": screenshotAttachment.dataURL,
                    "detail": "low"
                ]
            ]
        ]
    }

    private func appendScreenshotInstructionIfNeeded(
        systemInstructions: String,
        hasScreenshot: Bool
    ) -> String {
        guard hasScreenshot else { return systemInstructions }
        return systemInstructions + """


Screenshot context:
The screenshot is context only. Use it to understand surrounding UI,
conversation, document, or product state. Rewrite only the selected text.
Do not describe the screenshot. Do not add new facts from the screenshot unless
they are needed to preserve the selected text's intended meaning.
"""
    }

    private func executeRequest(
        _ request: URLRequest,
        provider: String,
        model: String,
        fallbackRequest: URLRequest? = nil,
        completion: @escaping (String?, String?) -> Void
    ) {
        let startTime = Date()

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
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
                if let fallbackRequest = fallbackRequest,
                   self.shouldRetryWithoutResponseFormat(errorInfo.message) {
                    self.log(
                        "Retrying custom provider request without " +
                        "response_format."
                    )
                    self.executeRequest(
                        fallbackRequest,
                        provider: provider,
                        model: model,
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
        log("Error: Network error: \(error.localizedDescription)")
        delegate?.llmService(
            self,
            didFailWithError: "Network error: \(error.localizedDescription)",
            isAuthenticationFailure: false,
            provider: provider
        )
        completion(nil, nil)
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

    private func shouldRetryWithoutResponseFormat(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("response_format") &&
            (lowercased.contains("unavailable") ||
             lowercased.contains("unsupported") ||
             lowercased.contains("not support"))
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
        elapsedNetwork: TimeInterval,
        provider: String,
        model: String,
        completion: @escaping (String?, String?) -> Void
    ) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data)
                    as? [String: Any] else {
                log("Error: Invalid JSON structure")
                delegate?.llmService(
                    self,
                    didFailWithError: "Invalid JSON structure",
                    isAuthenticationFailure: false,
                    provider: provider
                )
                completion(nil, nil)
                return
            }

            guard let parseResult = LLMResponseParser.parse(json) else {
                log("Error: Could not parse response")
                delegate?.llmService(
                    self,
                    didFailWithError: "Invalid JSON structure",
                    isAuthenticationFailure: false,
                    provider: provider
                )
                completion(nil, nil)
                return
            }

            let content = parseResult.content
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
        } catch {
            log("Error: JSON parsing error: \(error.localizedDescription)")
            delegate?.llmService(
                self,
                didFailWithError: "JSON parsing error",
                isAuthenticationFailure: false,
                provider: provider
            )
            completion(nil, nil)
        }
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
}
