import Foundation
import os.log

/// OpenAI-compatible Chat Completions, used by OpenAI, OpenRouter, and
/// custom providers.
struct ChatCompletionsFormat: LLMWireFormat {
    let provider: String
    /// Parameters a provider rejected earlier; they stay removed on every
    /// later attempt.
    var excludedParameters: Set<LLMCompatibility.Parameter> = []

    /// Low detail shrinks the image to 512 px, and the text in a window
    /// becomes unreadable.
    static let screenshotDetail = "high"

    private static let logger = OSLog(
        subsystem: "com.makeitsoundnatural.macos",
        category: "ChatCompletionsFormat"
    )

    func makeRequest(
        text: String,
        config: LLMService.Configuration,
        systemInstructions: String
    ) -> URLRequest? {
        guard let url = requestUrl(for: config) else {
            Self.log("Error: Invalid URL for provider \(config.provider)")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        configureRequestHeaders(&request, config: config)

        let instructions = excludedParameters.contains(.responseFormat)
            ? fallbackJsonInstructions(systemInstructions)
            : systemInstructions
        let body = payload(
            text: text,
            config: config,
            systemInstructions: instructions
        )

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            return request
        } catch {
            Self.log(
                "Error: Failed to encode payload: \(error.localizedDescription)"
            )
            return nil
        }
    }

    func payload(
        text: String,
        config: LLMService.Configuration,
        systemInstructions: String
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
        if !excludedParameters.contains(.reasoningEffort) {
            payload["reasoning_effort"] = config.reasoningEffort.rawValue
        }
        if !excludedParameters.contains(.responseFormat) {
            payload["response_format"] = [
                "type": "json_schema",
                "json_schema": [
                    "name": "correction_variants",
                    "strict": true,
                    "schema": CorrectionVariantsJSON.jsonSchema
                ]
            ]
        }
        if config.provider == AppDefaults.openAiProvider {
            payload["service_tier"] = "priority"
        }
        return payload
    }

    func variantsContent(
        from data: Data
    ) -> Result<String, LLMResponseFailure> {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            Self.log(
                "Error: JSON parsing error: \(error.localizedDescription)"
            )
            return .failure(.init(message: "JSON parsing error"))
        }

        guard let json = object as? [String: Any] else {
            return .failure(.init(message: "Invalid JSON structure"))
        }
        guard let parseResult = LLMResponseParser.parse(json) else {
            Self.log("Error: Could not parse response")
            return .failure(.init(message: "Invalid JSON structure"))
        }
        return .success(parseResult.content)
    }

    func retrying(
        afterErrorData data: Data?,
        statusCode: Int
    ) -> LLMWireFormat? {
        let rejected = LLMCompatibility.rejectedParameters(
            data: data,
            statusCode: statusCode
        ).subtracting(excludedParameters).filter {
            $0 != .responseFormat || !isBuiltInProvider
        }
        guard !rejected.isEmpty else { return nil }

        // Removed parameters stay removed; at most two retries.
        Self.log("Retrying without: \(rejected.map(\.rawValue).sorted())")
        var copy = self
        copy.excludedParameters = excludedParameters.union(rejected)
        return copy
    }

    private var isBuiltInProvider: Bool {
        provider == AppDefaults.openRouterProvider
            || provider == AppDefaults.openAiProvider
    }

    private func requestUrl(for config: LLMService.Configuration) -> URL? {
        let rawUrl: String
        if config.provider == AppDefaults.openRouterProvider {
            rawUrl = "https://openrouter.ai/api/v1/chat/completions"
        } else if config.provider == AppDefaults.openAiProvider {
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

    private func configureRequestHeaders(
        _ request: inout URLRequest,
        config: LLMService.Configuration
    ) {
        request.setValue(
            "Bearer \(config.activeApiKey)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if config.provider == AppDefaults.openRouterProvider {
            request.setValue(AppDefaults.appName, forHTTPHeaderField: "X-Title")
        }
    }

    private func fallbackJsonInstructions(
        _ systemInstructions: String
    ) -> String {
        systemInstructions + """


<provider_compatibility_output_format>
The provider does not support the response_format request parameter. Return
ONLY a valid JSON object with exactly these string keys: balanced, casual,
formal, concise. Do not wrap it in markdown. Do not add commentary.
</provider_compatibility_output_format>
"""
    }

    private func userMessageContent(
        text: String,
        screenshotAttachment: LLMService.ScreenshotAttachment?
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
                    "detail": Self.screenshotDetail
                ]
            ]
        ]
    }

    private static func log(_ message: String) {
        os_log("%{private}@", log: logger, type: .debug, message)
        #if DEBUG
        let timestamp = Date().timeIntervalSince1970
        print("⏱️ [\(String(format: "%.3f", timestamp))] \(message)")
        #endif
    }
}
