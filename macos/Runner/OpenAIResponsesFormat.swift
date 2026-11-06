import Foundation

/// OpenAI Responses with strict four-variant output and response storage off.
struct OpenAIResponsesFormat: LLMWireFormat {
    private var omitsReasoning = false

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
                "detail": "high"
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
        if config.requestSpeed != .standard {
            body["service_tier"] = config.requestSpeed.rawValue
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
            return .failure(.init(message: "Unexpected response from OpenAI."))
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
            return .failure(.init(message: "Unexpected response from OpenAI."))
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

        var copy = self
        copy.omitsReasoning = true
        return copy
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
