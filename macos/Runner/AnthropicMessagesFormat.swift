import Foundation
import os.log

/// Anthropic's native Messages API with structured outputs, so a completed
/// reply is the four-variant JSON; refusal and max_tokens replies are not.
struct AnthropicMessagesFormat: LLMWireFormat {
    private static let messagesUrl = "https://api.anthropic.com/v1/messages"

    private static let logger = OSLog(
        subsystem: "com.makeitsoundnatural.macos",
        category: "AnthropicMessagesFormat"
    )

    func makeRequest(
        text: String,
        config: LLMService.Configuration,
        systemInstructions: String
    ) -> URLRequest? {
        guard let url = URL(string: Self.messagesUrl) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anthropicApiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(
            AppDefaults.anthropicApiVersion,
            forHTTPHeaderField: "anthropic-version"
        )
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": AppDefaults.anthropicMaxTokens,
            "system": systemInstructions,
            "messages": [
                [
                    "role": "user",
                    "content": userContent(
                        text: text,
                        screenshotAttachment: config.screenshotAttachment
                    )
                ]
            ],
            "output_config": [
                "effort": Self.effort(for: config.reasoningEffort),
                "format": [
                    "type": "json_schema",
                    "schema": CorrectionVariantsJSON.jsonSchema
                ]
            ]
        ]

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

    func variantsContent(
        from data: Data
    ) -> Result<String, LLMResponseFailure> {
        // The one check of the response shape; nothing downstream re-reads it.
        guard let response = try? JSONDecoder().decode(
            AnthropicMessageResponse.self,
            from: data
        ) else {
            return unexpectedResponse(data)
        }

        switch response.stopReason {
        case "end_turn":
            let text = response.content
                .filter { $0.type == "text" }
                .compactMap(\.text)
                .joined()
            guard let variants = try? JSONDecoder().decode(
                CorrectionVariantsJSON.self,
                from: Data(text.utf8)
            ) else {
                return unexpectedResponse(data)
            }
            return .success(variants.markerContent)
        case "refusal":
            Self.log(
                "Refusal category: \(response.stopDetails?.category ?? "none")"
            )
            return .failure(.init(message: "Claude declined to rewrite this text."))
        case "max_tokens":
            return .failure(
                .init(message: "The response was cut off before it finished.")
            )
        default:
            return unexpectedResponse(data)
        }
    }

    /// The request never carries optional parameters to drop, so an error
    /// is always reported as is.
    func retrying(
        afterErrorData data: Data?,
        statusCode: Int
    ) -> LLMWireFormat? {
        nil
    }

    /// Thinking cannot be turned off on every catalog model, so None sends
    /// the lowest effort instead.
    private static func effort(for level: ReasoningEffort) -> String {
        switch level {
        case .none, .low:
            return "low"
        case .medium:
            return "medium"
        case .high:
            return "high"
        }
    }

    private func userContent(
        text: String,
        screenshotAttachment: LLMService.ScreenshotAttachment?
    ) -> Any {
        guard let screenshotAttachment = screenshotAttachment else {
            return text
        }

        return [
            ["type": "text", "text": text],
            [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": screenshotAttachment.mimeType,
                    "data": screenshotAttachment.base64Data
                ]
            ]
        ]
    }

    private func unexpectedResponse(
        _ data: Data
    ) -> Result<String, LLMResponseFailure> {
        Self.log(
            "Error: Unexpected response body: " +
            (String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>")
        )
        return .failure(.init(message: "Unexpected response from Anthropic."))
    }

    private static func log(_ message: String) {
        os_log("%{private}@", log: logger, type: .debug, message)
        #if DEBUG
        let timestamp = Date().timeIntervalSince1970
        print("⏱️ [\(String(format: "%.3f", timestamp))] \(message)")
        #endif
    }
}

private struct AnthropicMessageResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }

    struct StopDetails: Decodable {
        let category: String?
    }

    let content: [ContentBlock]
    let stopReason: String
    let stopDetails: StopDetails?

    enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
        case stopDetails = "stop_details"
    }
}
