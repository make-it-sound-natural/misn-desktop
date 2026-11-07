import XCTest
@testable import Make_It_Sound_Natural

final class LLMServiceAuthFailureTests: XCTestCase {
    func testProcessTextForwardsAuthFailureWithProvider() {
        let transport = ScriptedLLMTransport(responses: [
            (401, #"{"error":{"code":"invalid_api_key"}}"#)
        ])
        defer { transport.invalidate() }
        let service = LLMService(session: transport.session)
        let delegate = CapturingLLMDelegate()
        service.delegate = delegate

        let result = processTextAndWait(service, text: "Hello", config: .init(
            provider: AppDefaults.openRouterProvider,
            apiKey: "openai-key",
            openRouterApiKey: "bad-openrouter-key",
            customProviderApiKey: "",
            customProviderBaseUrl: nil,
            model: "test-model",
            customPrompt: nil,
            context: nil,
            targetProfileInstruction: "Rewrite naturally.",
            screenshotAttachment: nil,
            accessibilityContext: nil
        ))

        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(result.variantOrError, "Invalid API key. Check settings.")
        XCTAssertEqual(delegate.error, "Invalid API key. Check settings.")
        XCTAssertEqual(delegate.provider, AppDefaults.openRouterProvider)
        XCTAssertTrue(delegate.isAuthenticationFailure)
    }
}
