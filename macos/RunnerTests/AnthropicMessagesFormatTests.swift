import XCTest
@testable import Make_It_Sound_Natural

final class AnthropicMessagesFormatTests: XCTestCase {
    private let format = AnthropicMessagesFormat()
    private let variantsJson = """
    {"balanced":"b","casual":"c","formal":"f","concise":"n"}
    """
    private let markerContent = "---BALANCED---\nb\n\n---CASUAL---\nc\n\n" +
        "---FORMAL---\nf\n\n---CONCISE---\nn"

    func testRequestTargetsMessagesEndpointWithAnthropicHeaders() throws {
        let request = try XCTUnwrap(makeRequest(config()))

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.anthropic.com/v1/messages"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "x-api-key"),
            "anthropic-key"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "anthropic-version"),
            "2026-10-21"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "content-type"),
            "application/json"
        )
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testRequestBodyCarriesModelMaxTokensAndSystem() throws {
        let body = try payload(config(), systemInstructions: "Rewrite well.")

        XCTAssertEqual(body["model"] as? String, "claude-haiku-5-5")
        XCTAssertEqual(body["max_tokens"] as? Int, 16000)
        XCTAssertEqual(body["system"] as? String, "Rewrite well.")
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0]["role"] as? String, "user")
    }

    func testTextOnlyRequestSendsPlainStringContent() throws {
        let message = try userMessage(config())

        XCTAssertEqual(message["content"] as? String, "Selected text")
    }

    func testScreenshotRequestSendsTextAndBase64ImageBlocks() throws {
        let attachment = LLMService.ScreenshotAttachment(
            mimeType: "image/jpeg",
            base64Data: "abc123"
        )
        let message = try userMessage(config(screenshot: attachment))

        let content = try XCTUnwrap(message["content"] as? [[String: Any]])
        XCTAssertEqual(content.count, 2)
        XCTAssertEqual(
            content[0] as NSDictionary,
            ["type": "text", "text": "Selected text"] as NSDictionary
        )
        XCTAssertEqual(content[1]["type"] as? String, "image")
        XCTAssertEqual(
            content[1]["source"] as? NSDictionary,
            [
                "type": "base64",
                "media_type": "image/jpeg",
                "data": "abc123"
            ] as NSDictionary
        )
    }

    func testEffortMapsEveryReasoningLevel() throws {
        let expected: [ReasoningEffort: String] = [
            .none: "low", .low: "low", .medium: "medium", .high: "high"
        ]
        XCTAssertEqual(Set(expected.keys), Set(ReasoningEffort.allCases))
        for (level, effort) in expected {
            let outputConfig = try XCTUnwrap(
                payload(config(reasoningEffort: level))["output_config"]
                    as? [String: Any]
            )
            XCTAssertEqual(outputConfig["effort"] as? String, effort, "\(level)")
        }
    }

    func testOutputFormatUsesFourVariantSchema() throws {
        let outputConfig = try XCTUnwrap(
            payload(config())["output_config"] as? [String: Any]
        )
        let format = try XCTUnwrap(outputConfig["format"] as? [String: Any])

        XCTAssertEqual(format["type"] as? String, "json_schema")
        XCTAssertEqual(
            format["schema"] as? NSDictionary,
            [
                "type": "object",
                "properties": [
                    "balanced": ["type": "string"],
                    "casual": ["type": "string"],
                    "formal": ["type": "string"],
                    "concise": ["type": "string"]
                ],
                "required": ["balanced", "casual", "formal", "concise"],
                "additionalProperties": false
            ] as NSDictionary
        )
    }

    func testRequestSendsOnlyMessagesApiFields() throws {
        let body = try payload(config(reasoningEffort: .none))

        XCTAssertEqual(
            Set(body.keys),
            ["model", "max_tokens", "system", "messages", "output_config"]
        )
        let outputConfig = try XCTUnwrap(body["output_config"] as? [String: Any])
        XCTAssertEqual(Set(outputConfig.keys), ["effort", "format"])
    }

    func testEndTurnSkipsThinkingAndReturnsMarkerContent() throws {
        let result = format.variantsContent(from: try responseBody(
            stopReason: "end_turn",
            content: [
                ["type": "thinking", "thinking": "Considering.", "signature": "sig"],
                ["type": "text", "text": variantsJson]
            ]
        ))

        XCTAssertEqual(try result.get(), markerContent)
    }

    func testRefusalFailsWithDeclinedMessage() throws {
        let result = format.variantsContent(from: try responseBody(
            stopReason: "refusal",
            content: [],
            extra: ["stop_details": ["type": "refusal", "category": "cyber"]]
        ))

        XCTAssertEqual(
            failureMessage(result),
            "Claude declined to rewrite this text."
        )
    }

    func testMaxTokensFailsWithCutOffMessage() throws {
        let result = format.variantsContent(from: try responseBody(
            stopReason: "max_tokens",
            content: [["type": "text", "text": "{\"balanced\":\"b"]]
        ))

        XCTAssertEqual(
            failureMessage(result),
            "The response was cut off before it finished."
        )
    }

    func testOtherStopReasonFailsWithUnexpectedMessage() throws {
        let result = format.variantsContent(from: try responseBody(
            stopReason: "pause_turn",
            content: [["type": "text", "text": variantsJson]]
        ))

        XCTAssertEqual(failureMessage(result), "Unexpected response from Anthropic.")
    }

    func testNonJsonTextFailsWithUnexpectedMessage() throws {
        let result = format.variantsContent(from: try responseBody(
            stopReason: "end_turn",
            content: [["type": "text", "text": "Here are four rewrites."]]
        ))

        XCTAssertEqual(failureMessage(result), "Unexpected response from Anthropic.")
    }

    func testJsonMissingKeyFailsWithUnexpectedMessage() throws {
        let result = format.variantsContent(from: try responseBody(
            stopReason: "end_turn",
            content: [[
                "type": "text",
                "text": #"{"balanced":"b","casual":"c","formal":"f"}"#
            ]]
        ))

        XCTAssertEqual(failureMessage(result), "Unexpected response from Anthropic.")
    }

    func testUndecodableBodyFailsWithUnexpectedMessage() throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "content": [["type": "text", "text": variantsJson]]
        ])

        let result = format.variantsContent(from: body)

        XCTAssertEqual(failureMessage(result), "Unexpected response from Anthropic.")
    }

    func testRetryingReturnsNilForRejectedResponseFormat() {
        let body = Data(#"""
        {"type":"error","error":{"type":"invalid_request_error","message":"response_format is not supported"}}
        """#.utf8)

        XCTAssertNil(format.retrying(afterErrorData: body, statusCode: 400))
    }

    func testFactoryRoutesOnlyAnthropicProviderToMessagesApi() throws {
        let service = LLMService()
        let native = try XCTUnwrap(service.buildRequestForTesting(
            text: "Selected text",
            config: config(),
            systemInstructions: "system"
        ))
        let custom = try XCTUnwrap(service.buildRequestForTesting(
            text: "Selected text",
            config: config(provider: "anthropic"),
            systemInstructions: "system"
        ))

        XCTAssertEqual(
            native.url?.absoluteString,
            "https://api.anthropic.com/v1/messages"
        )
        XCTAssertEqual(
            custom.url?.absoluteString,
            "https://api.anthropic.com/v1/chat/completions"
        )
    }

    private func config(
        provider: String = AppDefaults.anthropicProvider,
        screenshot: LLMService.ScreenshotAttachment? = nil,
        reasoningEffort: ReasoningEffort = .low
    ) -> LLMService.Configuration {
        .init(
            provider: provider,
            apiKey: "openai-key",
            openRouterApiKey: "router-key",
            anthropicApiKey: "anthropic-key",
            customProviderApiKey: "custom-key",
            customProviderBaseUrl: "https://api.anthropic.com/v1",
            model: "claude-haiku-5-5",
            customPrompt: nil,
            context: nil,
            targetProfileInstruction: nil,
            screenshotAttachment: screenshot,
            accessibilityContext: nil,
            reasoningEffort: reasoningEffort
        )
    }

    private func makeRequest(
        _ config: LLMService.Configuration,
        systemInstructions: String = "system"
    ) -> URLRequest? {
        format.makeRequest(
            text: "Selected text",
            config: config,
            systemInstructions: systemInstructions
        )
    }

    private func payload(
        _ config: LLMService.Configuration,
        systemInstructions: String = "system"
    ) throws -> [String: Any] {
        let request = try XCTUnwrap(
            makeRequest(config, systemInstructions: systemInstructions)
        )
        let body = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
    }

    private func userMessage(
        _ config: LLMService.Configuration
    ) throws -> [String: Any] {
        let messages = try XCTUnwrap(
            payload(config)["messages"] as? [[String: Any]]
        )
        return try XCTUnwrap(messages.first)
    }

    private func responseBody(
        stopReason: String,
        content: [[String: Any]],
        extra: [String: Any] = [:]
    ) throws -> Data {
        var body: [String: Any] = [
            "id": "msg_test",
            "type": "message",
            "role": "assistant",
            "model": "claude-haiku-5-5",
            "content": content,
            "stop_reason": stopReason
        ]
        body.merge(extra) { _, new in new }
        return try JSONSerialization.data(withJSONObject: body)
    }

    private func failureMessage(
        _ result: Result<String, LLMResponseFailure>
    ) -> String? {
        guard case .failure(let failure) = result else { return nil }
        return failure.message
    }
}
