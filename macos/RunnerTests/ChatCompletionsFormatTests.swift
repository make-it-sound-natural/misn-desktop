import XCTest
@testable import Make_It_Sound_Natural

final class ChatCompletionsFormatTests: XCTestCase {
    private let format = ChatCompletionsFormat(provider: "openrouter")

    func testStructuredOutputBecomesMarkerContent() throws {
        let variants = """
        {"balanced":"b","casual":"c","formal":"f","concise":"n"}
        """
        let body = try JSONSerialization.data(withJSONObject: [
            "choices": [["message": ["content": variants]]]
        ])

        let result = format.variantsContent(from: body)

        XCTAssertEqual(
            try result.get(),
            "---BALANCED---\nb\n\n---CASUAL---\nc\n\n" +
            "---FORMAL---\nf\n\n---CONCISE---\nn"
        )
    }

    func testNonJsonBodyFailsWithJsonParsingError() {
        let result = format.variantsContent(from: Data("not JSON".utf8))

        XCTAssertEqual(failureMessage(result), "JSON parsing error")
    }

    func testNonObjectBodyFailsWithInvalidStructure() {
        let result = format.variantsContent(from: Data("[]".utf8))

        XCTAssertEqual(failureMessage(result), "Invalid JSON structure")
    }

    func testPayloadNeverSendsServiceTier() {
        for provider in ["openai", "openrouter", "tokenguard"] {
            for speed in [RequestSpeed.fast, .ultrafast] {
                let config = LLMService.Configuration(
                    provider: provider,
                    apiKey: "openai-key",
                    openRouterApiKey: "router-key",
                    customProviderApiKey: "custom-key",
                    customProviderBaseUrl: "https://example.com/v1",
                    model: "test-model",
                    customPrompt: nil,
                    context: nil,
                    targetProfileInstruction: nil,
                    screenshotAttachment: nil,
                    accessibilityContext: nil,
                    requestSpeed: speed
                )
                let body = ChatCompletionsFormat(provider: provider).payload(
                    text: "Selected text",
                    config: config,
                    systemInstructions: "Rewrite naturally."
                )

                XCTAssertNil(body["service_tier"], "\(provider), \(speed)")
            }
        }
    }

    private func failureMessage(
        _ result: Result<String, LLMResponseFailure>
    ) -> String? {
        guard case .failure(let failure) = result else { return nil }
        return failure.message
    }
}
