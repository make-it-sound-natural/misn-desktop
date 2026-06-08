import XCTest
@testable import Make_It_Sound_Natural

final class LLMServicePayloadTests: XCTestCase {
    func testDebugRequestContextLinesShowAttachedInputs() {
        let service = LLMService()
        let attachment = LLMService.ScreenshotAttachment(
            mimeType: "image/jpeg",
            base64Data: "abc123"
        )
        let config = LLMService.Configuration(
            provider: "openai",
            apiKey: "key",
            openRouterApiKey: "",
            customProviderApiKey: "",
            customProviderBaseUrl: nil,
            model: "gpt-5.4-mini",
            customPrompt: nil,
            context: "Slack thread about pnpm and axios security",
            targetProfileInstruction: nil,
            screenshotAttachment: attachment
        )

        let lines = service.debugRequestContextLines(config: config)

        XCTAssertEqual(
            lines[0],
            "Text context attached to LLM request: yes, length=42"
        )
        XCTAssertEqual(
            lines[1],
            "Text context preview: Slack thread about pnpm and axios security"
        )
        XCTAssertEqual(
            lines[2],
            "Text context full: hidden. Set MISN_LOG_FULL_LLM_CONTEXT=1"
        )
        XCTAssertEqual(
            lines[3],
            "Screenshot context attached to LLM request: yes, " +
            "mime=image/jpeg, base64Length=6, detail=low"
        )
    }

    func testDebugRequestContextLinesCanShowFullContext() {
        let service = LLMService(
            environment: ["MISN_LOG_FULL_LLM_CONTEXT": "1"]
        )
        let config = LLMService.Configuration(
            provider: "openai",
            apiKey: "key",
            openRouterApiKey: "",
            customProviderApiKey: "",
            customProviderBaseUrl: nil,
            model: "gpt-5.4-mini",
            customPrompt: nil,
            context: "private context",
            targetProfileInstruction: nil,
            screenshotAttachment: nil
        )

        let lines = service.debugRequestContextLines(config: config)

        XCTAssertEqual(lines[2], "Text context full:\nprivate context")
        XCTAssertEqual(lines[3], "Screenshot context attached to LLM request: no")
    }

    func testTextOnlyPayloadKeepsUserContentString() throws {
        let service = LLMService()
        let config = LLMService.Configuration(
            provider: "openai",
            apiKey: "key",
            openRouterApiKey: "",
            customProviderApiKey: "",
            customProviderBaseUrl: nil,
            model: "gpt-5.4-mini",
            customPrompt: nil,
            context: nil,
            targetProfileInstruction: nil,
            screenshotAttachment: nil
        )

        let payload = service.buildPayloadForTesting(
            text: "hello",
            config: config,
            systemInstructions: "system"
        )

        let messages = try XCTUnwrap(payload["messages"] as? [[String: Any]])
        XCTAssertEqual(messages[1]["content"] as? String, "hello")
    }

    func testImagePayloadUsesMultimodalUserContent() throws {
        let service = LLMService()
        let attachment = LLMService.ScreenshotAttachment(
            mimeType: "image/jpeg",
            base64Data: "abc123"
        )
        let config = LLMService.Configuration(
            provider: "openai",
            apiKey: "key",
            openRouterApiKey: "",
            customProviderApiKey: "",
            customProviderBaseUrl: nil,
            model: "gpt-5.4-mini",
            customPrompt: nil,
            context: nil,
            targetProfileInstruction: nil,
            screenshotAttachment: attachment
        )

        let payload = service.buildPayloadForTesting(
            text: "hello",
            config: config,
            systemInstructions: "system"
        )

        let messages = try XCTUnwrap(payload["messages"] as? [[String: Any]])
        let content = try XCTUnwrap(messages[1]["content"] as? [[String: Any]])
        XCTAssertEqual(content[0]["type"] as? String, "text")
        XCTAssertEqual(content[0]["text"] as? String, "hello")
        XCTAssertEqual(content[1]["type"] as? String, "image_url")
        let imageURL = try XCTUnwrap(content[1]["image_url"] as? [String: Any])
        XCTAssertEqual(
            imageURL["url"] as? String,
            "data:image/jpeg;base64,abc123"
        )
        XCTAssertEqual(imageURL["detail"] as? String, "low")
    }

    func testOpenRouterCustomSlugImagePayloadUsesMultimodalContent() throws {
        let service = LLMService()
        let attachment = LLMService.ScreenshotAttachment(
            mimeType: "image/jpeg",
            base64Data: "abc123"
        )
        let config = LLMService.Configuration(
            provider: AppDefaults.openRouterProvider,
            apiKey: AppDefaults.apiKey,
            openRouterApiKey: "openrouter-key",
            customProviderApiKey: "",
            customProviderBaseUrl: nil,
            model: "openai/gpt-5-mini:nitro",
            customPrompt: nil,
            context: nil,
            targetProfileInstruction: nil,
            screenshotAttachment: attachment
        )

        let payload = service.buildPayloadForTesting(
            text: "hello",
            config: config,
            systemInstructions: "system"
        )

        let messages = try XCTUnwrap(payload["messages"] as? [[String: Any]])
        let content = try XCTUnwrap(messages[1]["content"] as? [[String: Any]])
        XCTAssertEqual(content[0]["type"] as? String, "text")
        XCTAssertEqual(content[1]["type"] as? String, "image_url")
        let imageURL = try XCTUnwrap(content[1]["image_url"] as? [String: Any])
        XCTAssertEqual(
            imageURL["url"] as? String,
            "data:image/jpeg;base64,abc123"
        )
    }

    func testCustomProviderRequestUsesNormalizedUrlAndCustomKey() throws {
        let service = LLMService()
        let config = LLMService.Configuration(
            provider: "tokenguard",
            apiKey: "openai-key",
            openRouterApiKey: "openrouter-key",
            customProviderApiKey: "custom-key",
            customProviderBaseUrl: "https://tokenguard.int.agrd.dev/api/v1",
            model: "kimi-k2.6",
            customPrompt: nil,
            context: nil,
            targetProfileInstruction: nil,
            screenshotAttachment: nil
        )

        let request = try XCTUnwrap(service.buildRequestForTesting(
            text: "hello",
            config: config,
            systemInstructions: "system"
        ))

        XCTAssertEqual(
            request.url?.absoluteString,
            "https://tokenguard.int.agrd.dev/api/v1/chat/completions"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer custom-key"
        )
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Title"))
    }

    func testCustomProviderDoesNotDoubleAppendChatCompletions() throws {
        let service = LLMService()
        let config = LLMService.Configuration(
            provider: "tokenguard",
            apiKey: "",
            openRouterApiKey: "",
            customProviderApiKey: "custom-key",
            customProviderBaseUrl:
                "https://tokenguard.int.agrd.dev/api/v1/chat/completions",
            model: "kimi-k2.6",
            customPrompt: nil,
            context: nil,
            targetProfileInstruction: nil,
            screenshotAttachment: nil
        )

        let request = try XCTUnwrap(service.buildRequestForTesting(
            text: "hello",
            config: config,
            systemInstructions: "system"
        ))

        XCTAssertEqual(
            request.url?.absoluteString,
            "https://tokenguard.int.agrd.dev/api/v1/chat/completions"
        )
    }

    func testCustomProviderFallbackPayloadOmitsResponseFormat() {
        let service = LLMService()
        let config = LLMService.Configuration(
            provider: "tokenguard",
            apiKey: "",
            openRouterApiKey: "",
            customProviderApiKey: "custom-key",
            customProviderBaseUrl: "https://tokenguard.int.agrd.dev/api/v1",
            model: "deepseek-v4-flash",
            customPrompt: nil,
            context: nil,
            targetProfileInstruction: nil,
            screenshotAttachment: nil
        )

        let payload = service.buildPayloadForTesting(
            text: "hello",
            config: config,
            systemInstructions: "Return only JSON.",
            includeResponseFormat: false
        )

        XCTAssertNil(payload["response_format"])
        XCTAssertEqual(payload["model"] as? String, "deepseek-v4-flash")
    }
}
