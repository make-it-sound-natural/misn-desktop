import XCTest
@testable import Make_It_Sound_Natural

final class OpenAIResponsesFormatTests: XCTestCase {
    private let format = OpenAIResponsesFormat()
    private let variants = #"{"balanced":"b","casual":"c","formal":"f","concise":"n"}"#

    func testRequestTargetsResponsesEndpointWithBearerKey() throws {
        let request = try request()

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.openai.com/v1/responses"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer openai-key"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "application/json"
        )
    }

    func testBodyCarriesModelInstructionsReasoningAndStoreFalse() throws {
        for effort in ReasoningEffort.allCases {
            var config = config()
            config.reasoningEffort = effort
            let body = try payload(config: config)

            XCTAssertEqual(body["model"] as? String, "gpt-6.1-sol")
            XCTAssertEqual(body["instructions"] as? String, "Rewrite naturally.")
            let reasoning = try XCTUnwrap(body["reasoning"] as? [String: String])
            XCTAssertEqual(reasoning, ["effort": effort.rawValue])
            XCTAssertEqual(body["store"] as? Bool, false)
        }
    }

    func testTextOnlyInputIsOneUserMessageWithInputText() throws {
        let body = try payload()
        let input = try XCTUnwrap(body["input"] as? [[String: Any]])

        XCTAssertEqual(input.count, 1)
        XCTAssertEqual(input[0]["role"] as? String, "user")
        let content = try XCTUnwrap(input[0]["content"] as? [[String: String]])
        XCTAssertEqual(content, [["type": "input_text", "text": "Original text"]])
    }

    func testScreenshotInputAddsHighDetailInputImage() throws {
        let attachment = LLMService.ScreenshotAttachment(
            mimeType: "image/png", base64Data: "abc123"
        )
        let body = try payload(config: config(screenshot: attachment))
        let input = try XCTUnwrap(body["input"] as? [[String: Any]])
        let content = try XCTUnwrap(input[0]["content"] as? [[String: String]])

        XCTAssertEqual(content.count, 2)
        XCTAssertEqual(content[0], ["type": "input_text", "text": "Original text"])
        XCTAssertEqual(content[1], [
            "type": "input_image",
            "image_url": attachment.dataURL,
            "detail": "high"
        ])
    }

    func testTextFormatIsStrictCorrectionVariantsSchema() throws {
        let body = try payload()
        let text = try XCTUnwrap(body["text"] as? [String: Any])
        let outputFormat = try XCTUnwrap(text["format"] as? [String: Any])

        XCTAssertEqual(Set(outputFormat.keys), ["type", "name", "strict", "schema"])
        XCTAssertEqual(outputFormat["type"] as? String, "json_schema")
        XCTAssertEqual(outputFormat["name"] as? String, "correction_variants")
        XCTAssertEqual(outputFormat["strict"] as? Bool, true)
        let schema = try XCTUnwrap(outputFormat["schema"] as? NSDictionary)
        XCTAssertEqual(schema, CorrectionVariantsJSON.jsonSchema as NSDictionary)
    }

    func testStandardSpeedOmitsServiceTier() throws {
        XCTAssertNil(try payload()["service_tier"])
    }

    func testFastAndUltrafastSetServiceTier() throws {
        for speed in [RequestSpeed.fast, .ultrafast] {
            XCTAssertEqual(
                try payload(config: config(speed: speed))["service_tier"] as? String,
                speed.rawValue
            )
        }
    }

    func testCompletedMessageReturnsMarkerContentAndSkipsOtherItems() throws {
        let data = try response(output: [
            ["type": "reasoning", "summary": [], "content": NSNull()],
            ["type": "function_call", "name": "ignored"],
            ["type": "message", "content": [[
                "type": "output_text", "text": variants, "annotations": []
            ]]]
        ])

        XCTAssertEqual(
            try format.variantsContent(from: data).get(),
            "---BALANCED---\nb\n\n---CASUAL---\nc\n\n" +
            "---FORMAL---\nf\n\n---CONCISE---\nn"
        )
    }

    func testRefusalFailsWithRefusalText() throws {
        for refusal in ["I cannot help with that.", ""] {
            let data = try response(output: [[
                "type": "message",
                "content": [["type": "refusal", "refusal": refusal]]
            ]])
            let message = refusal.isEmpty
                ? "OpenAI declined to rewrite this text."
                : "OpenAI declined to rewrite this text: \(refusal)"
            assertFailure(data, message: message)
        }
        assertFailure(try response(output: [[
            "type": "message", "content": [["type": "refusal"]]
        ]]), message: "OpenAI declined to rewrite this text.")
    }

    func testIncompleteFailsWithReason() throws {
        let data = try response(status: "incomplete", reason: "max_output_tokens")
        assertFailure(
            data,
            message: "OpenAI stopped before finishing the response (max_output_tokens)."
        )
    }

    func testIncompleteWithoutReasonFailsWithGenericMessage() throws {
        assertFailure(
            try response(status: "incomplete"),
            message: "OpenAI stopped before finishing the response."
        )
    }

    func testOutputTextThatIsNotVariantsJsonFailsWithUnexpectedMessage() throws {
        assertFailure(try response(output: [[
            "type": "message",
            "content": [["type": "output_text", "text": "plain text"]]
        ]]), message: "Unexpected response from OpenAI.")
    }

    func testUndecodableBodyFailsWithUnexpectedMessage() {
        for body in ["not JSON", "{}", #"{"output":42}"#] {
            assertFailure(Data(body.utf8), message: "Unexpected response from OpenAI.")
        }
    }

    func testReasoningRejectionRetriesOnceWithoutReasoning() throws {
        let errors = [
            #"{"error":{"param":"reasoning","code":"unsupported_parameter"}}"#,
            #"{"error":{"param":"reasoning.effort","code":"unsupported_value"}}"#,
            #"{"error":{"message":"Unknown parameter: reasoning"}}"#,
            #"{"error":{"message":"reasoning.effort is not supported"}}"#,
            #"{"error":{"message":"Unsupported value for reasoning.effort"}}"#,
            #"{"error":{"message":"Invalid value for reasoning"}}"#
        ]
        for status in [400, 422] {
            for error in errors {
                let data = Data(error.utf8)
                let retry = try XCTUnwrap(format.retrying(
                    afterErrorData: data, statusCode: status
                ), error)
                let request = try XCTUnwrap(retry.makeRequest(
                    text: "Original text",
                    config: config(speed: .ultrafast),
                    systemInstructions: "Rewrite naturally."
                ))
                let body = try XCTUnwrap(request.httpBody)
                let payload = try XCTUnwrap(
                    JSONSerialization.jsonObject(with: body) as? [String: Any]
                )
                var expected = try self.payload(config: config(speed: .ultrafast))
                expected.removeValue(forKey: "reasoning")
                XCTAssertEqual(payload as NSDictionary, expected as NSDictionary)
                XCTAssertNil(retry.retrying(
                    afterErrorData: data, statusCode: status
                ))
            }
        }
    }

    func testUnrelatedErrorsAndNonValidationStatusesDoNotRetry() {
        let errors = [
            #"{"error":{"param":"service_tier","code":"unsupported_value","message":"Use Standard"}}"#,
            #"{"error":{"param":"service_tier","message":"reasoning.effort is unsupported"}}"#,
            #"{"error":{"param":"model","message":"Invalid value; reasoning is low"}}"#,
            #"{"error":{"message":"reasoning.effort quota exceeded"}}"#,
            #"{"error":{"message":"Unsupported parameter: reasoningXeffort"}}"#,
            #"{"error":{"message":"Unsupported parameter: reasoning.budget"}}"#,
            #"{"error":{"message":"Invalid schema for text.format"}}"#,
            "not JSON"
        ]
        for status in [400, 422] {
            for error in errors {
                XCTAssertNil(format.retrying(
                    afterErrorData: Data(error.utf8), statusCode: status
                ), error)
            }
        }
        let rejection = Data(
            #"{"error":{"param":"reasoning.effort","code":"unsupported_value"}}"#.utf8
        )
        for status in [401, 403, 429, 500, 503] {
            XCTAssertNil(format.retrying(
                afterErrorData: rejection, statusCode: status
            ))
        }
    }

    func testFactoryRoutesEachProviderToItsFormat() {
        XCTAssertTrue(LLMWireFormatFactory.forProvider("openai") is OpenAIResponsesFormat)
        XCTAssertTrue(
            LLMWireFormatFactory.forProvider("anthropic-messages") is AnthropicMessagesFormat
        )
        for provider in ["openrouter", "anthropic", "tokenguard", "custom-endpoint"] {
            XCTAssertTrue(
                LLMWireFormatFactory.forProvider(provider) is ChatCompletionsFormat,
                provider
            )
        }
    }

    private func request(config: LLMService.Configuration? = nil) throws -> URLRequest {
        try XCTUnwrap(format.makeRequest(
            text: "Original text",
            config: config ?? self.config(),
            systemInstructions: "Rewrite naturally."
        ))
    }

    private func payload(config: LLMService.Configuration? = nil) throws -> [String: Any] {
        let body = try XCTUnwrap(request(config: config).httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    private func config(
        speed: RequestSpeed = .standard,
        screenshot: LLMService.ScreenshotAttachment? = nil
    ) -> LLMService.Configuration {
        .init(
            provider: AppDefaults.openAiProvider,
            apiKey: "openai-key", openRouterApiKey: "", customProviderApiKey: "",
            customProviderBaseUrl: nil, model: "gpt-6.1-sol", customPrompt: nil,
            context: nil, targetProfileInstruction: nil,
            screenshotAttachment: screenshot, accessibilityContext: nil,
            requestSpeed: speed
        )
    }

    private func response(
        status: String = "completed",
        reason: String? = nil,
        output: [[String: Any]] = []
    ) throws -> Data {
        var body: [String: Any] = [
            "status": status, "output": output,
            "incomplete_details": NSNull()
        ]
        if let reason { body["incomplete_details"] = ["reason": reason] }
        return try JSONSerialization.data(withJSONObject: body)
    }

    private func assertFailure(
        _ data: Data,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch format.variantsContent(from: data) {
        case .success:
            XCTFail("Expected response failure", file: file, line: line)
        case .failure(let error):
            XCTAssertEqual(error.message, message, file: file, line: line)
        }
    }
}
