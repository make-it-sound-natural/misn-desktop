import Foundation
import os.log

/// OpenAI Responses with strict four-variant output and response storage off.
struct OpenAIResponsesFormat: LLMWireFormat {
    private var omitsReasoning = false

    private static let logger = OSLog(
        subsystem: "com.makeitsoundnatural.macos",
        category: "OpenAIResponsesFormat"
    )

    func makeRequest(
        text: String,
        config: LLMService.Configuration,
        systemInstructions: String
    ) -> URLRequest? {
        guard let url = URL(string: "https://api.openai.com/v1/responses")
        else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization"
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var content = [["type": "input_text", "text": text]]
        if let screenshot = config.screenshotAttachment {
            content.append([
                "type": "input_image",
                "image_url": screenshot.dataURL,
                "detail": LLMService.ScreenshotAttachment.detail
            ])
        }
        var body: [String: Any] = [
            "model": config.model,
            "instructions": systemInstructions,
            "input": [["role": "user", "content": content]],
            "text": ["format": [
                "type": "json_schema",
                "name": "correction_variants",
                "strict": true,
                "schema": CorrectionVariantsJSON.jsonSchema
            ]],
            "store": false
        ]
        if !omitsReasoning {
            body["reasoning"] = ["effort": config.reasoningEffort.rawValue]
        }
        if let serviceTier = Self.serviceTier(for: config.requestSpeed) {
            body["service_tier"] = serviceTier
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request.httpBody == nil ? nil : request
    }

    func variantsContent(
        from data: Data
    ) -> Result<String, LLMResponseFailure> {
        guard let response = try? JSONDecoder().decode(
            OpenAIResponse.self, from: data
        ) else {
            return unexpectedResponse(data)
        }
        let content = response.output.flatMap { $0.content ?? [] }
        if let refusal = content.first(where: { $0.type == "refusal" }) {
            let text = refusal.refusal ?? ""
            let message = text.isEmpty
                ? "OpenAI declined to rewrite this text."
                : "OpenAI declined to rewrite this text: \(text)"
            return .failure(.init(message: message))
        }
        if response.status == "incomplete" {
            let reason = response.incompleteDetails?.reason ?? ""
            let detail = reason.isEmpty ? "" : " (\(reason))"
            let message =
                "OpenAI stopped before finishing the response\(detail)."
            return .failure(.init(message: message))
        }
        let text = response.output
            .filter { $0.type == "message" }
            .flatMap { $0.content ?? [] }
            .filter { $0.type == "output_text" }
            .compactMap(\.text)
            .joined()
        guard let variants = try? JSONDecoder().decode(
            CorrectionVariantsJSON.self, from: Data(text.utf8)
        ) else {
            return unexpectedResponse(data)
        }
        return .success(variants.markerContent)
    }

    func retrying(
        afterErrorData data: Data?,
        statusCode: Int
    ) -> LLMWireFormat? {
        guard !omitsReasoning,
              LLMCompatibility.rejectedParameters(
                  data: data, statusCode: statusCode
              ).contains(.reasoningEffort)
        else { return nil }

        Self.log("Retrying without: reasoning")
        var copy = self
        copy.omitsReasoning = true
        return copy
    }

    /// OpenAI's `service_tier` value; `nil` sends no tier, which is
    /// Standard processing.
    private static func serviceTier(for speed: RequestSpeed) -> String? {
        switch speed {
        case .standard:
            return nil
        case .fast:
            return "fast"
        case .ultrafast:
            return "ultrafast"
        }
    }

    private func unexpectedResponse(
        _ data: Data
    ) -> Result<String, LLMResponseFailure> {
        Self.log(
            "Error: Unexpected response body: " +
            (String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>")
        )
        return .failure(.init(message: "Unexpected response from OpenAI."))
    }

    private static func log(_ message: String) {
        os_log("%{private}@", log: logger, type: .debug, message)
        #if DEBUG
        let timestamp = Date().timeIntervalSince1970
        print("⏱️ [\(String(format: "%.3f", timestamp))] \(message)")
        #endif
    }
}

private struct OpenAIResponse: Decodable {
    struct Output: Decodable {
        let type: String
        let content: [Content]?
    }

    struct Content: Decodable {
        let type: String
        let text: String?
        let refusal: String?
    }

    struct IncompleteDetails: Decodable {
        let reason: String?
    }

    let status: String
    let output: [Output]
    let incompleteDetails: IncompleteDetails?

    enum CodingKeys: String, CodingKey {
        case status, output
        case incompleteDetails = "incomplete_details"
    }
}
