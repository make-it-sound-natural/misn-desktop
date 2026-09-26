import XCTest
@testable import Make_It_Sound_Natural

final class LLMServicePayloadTests: XCTestCase {
    func testSerializedReasoningLevelsAndDefaultForEveryProvider() throws {
        let service = LLMService()
        for provider in ["openai", "openrouter", "tokenguard", "custom-endpoint"] {
            var config = LLMService.Configuration(
                provider: provider,
                apiKey: "key", openRouterApiKey: "router-key",
                customProviderApiKey: "custom-key",
                customProviderBaseUrl: "https://example.test/v1",
                model: "test-model", customPrompt: nil, context: nil,
                targetProfileInstruction: nil, screenshotAttachment: nil,
                accessibilityContext: nil
            )
            XCTAssertEqual(config.reasoningEffort, .low)
            for effort in ReasoningEffort.allCases {
                config.reasoningEffort = effort
                let request = try XCTUnwrap(service.buildRequestForTesting(
                    text: "hello", config: config, systemInstructions: "system"
                ))
                let body = try XCTUnwrap(request.httpBody)
                let payload = try XCTUnwrap(
                    JSONSerialization.jsonObject(with: body) as? [String: Any]
                )
                XCTAssertEqual(payload["reasoning_effort"] as? String, effort.rawValue)
                XCTAssertNil(payload["reasoning"])
                XCTAssertNotNil(payload["response_format"])
            }
        }
    }

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
            screenshotAttachment: attachment,
            accessibilityContext: nil
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
            screenshotAttachment: nil,
            accessibilityContext: nil
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
            screenshotAttachment: nil,
            accessibilityContext: nil
        )

        let payload = service.buildPayloadForTesting(
            text: "hello",
            config: config,
            systemInstructions: "system"
        )

        let messages = try XCTUnwrap(payload["messages"] as? [[String: Any]])
        XCTAssertEqual(messages[1]["content"] as? String, "hello")
        XCTAssertEqual(payload["reasoning_effort"] as? String, "low")
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
            screenshotAttachment: attachment,
            accessibilityContext: nil
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
            screenshotAttachment: attachment,
            accessibilityContext: nil
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
            screenshotAttachment: nil,
            accessibilityContext: nil
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
            screenshotAttachment: nil,
            accessibilityContext: nil
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
            screenshotAttachment: nil,
            accessibilityContext: nil
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

    // MARK: - App context

    func testTextOnlyPayloadWithAppContextKeepsUserContentString() throws {
        let service = LLMService()
        let config = makeConfiguration(accessibilityContext: .slackFixture())

        let payload = service.buildPayloadForTesting(
            text: "hello",
            config: config,
            systemInstructions: service.buildFinalSystemInstructions(
                text: "hello",
                config: config
            )
        )

        let messages = try XCTUnwrap(payload["messages"] as? [[String: Any]])
        let system = try XCTUnwrap(messages[0]["content"] as? String)
        XCTAssertTrue(system.contains("<app_context>"))
        XCTAssertTrue(system.contains("review the mockups?"))
        XCTAssertEqual(messages[1]["content"] as? String, "hello")
    }

    func testImagePayloadWithAppContextKeepsRawSelectionAndBothContexts()
        throws {
        let service = LLMService()
        let config = makeConfiguration(
            screenshot: .init(mimeType: "image/jpeg", base64Data: "abc123"),
            accessibilityContext: .slackFixture()
        )

        let payload = service.buildPayloadForTesting(
            text: "hello",
            config: config,
            systemInstructions: service.buildFinalSystemInstructions(
                text: "hello",
                config: config
            )
        )

        let messages = try XCTUnwrap(payload["messages"] as? [[String: Any]])
        let system = try XCTUnwrap(messages[0]["content"] as? String)
        XCTAssertTrue(system.contains("<app_context>"))
        XCTAssertTrue(system.contains("Screenshot context:"))
        let content = try XCTUnwrap(messages[1]["content"] as? [[String: Any]])
        XCTAssertEqual(content.count, 2)
        XCTAssertEqual(content[0]["text"] as? String, "hello")
        XCTAssertEqual(content[1]["type"] as? String, "image_url")
    }

    func testDebugRequestContextLinesReportAppContextLengthsOnly() {
        let service = LLMService()
        let config = makeConfiguration(accessibilityContext: .slackFixture())

        let lines = service.debugRequestContextLines(config: config)
            .filter { $0.hasPrefix("App context") }

        XCTAssertEqual(lines, [
            "App context attached to LLM request: yes, mode=fieldAndNearby, " +
            "windowLength=17, fieldLength=15, beforeLength=9, " +
            "afterLength=8, nearbyLength=37",
            "App context full: hidden. Set MISN_LOG_FULL_LLM_CONTEXT=1"
        ])
    }

    func testDebugRequestContextLinesCanShowFullAppContext() throws {
        let service = LLMService(
            environment: ["MISN_LOG_FULL_LLM_CONTEXT": "1"]
        )
        let context = AccessibilityContext.slackFixture()
        let config = makeConfiguration(accessibilityContext: context)

        let lines = service.debugRequestContextLines(config: config)

        let section = try XCTUnwrap(PromptTemplates.appContextSection(context))
        XCTAssertTrue(lines.contains("App context full:\n\(section)"))
    }

    func testDebugRequestContextLinesReportMissingAppContextAndFallbackReason() {
        let service = LLMService()
        var config = makeConfiguration()

        XCTAssertEqual(
            service.debugRequestContextLines(config: config)
                .filter { $0.hasPrefix("App context") },
            ["App context attached to LLM request: no"]
        )

        config.accessibilityFallbackReason = .windowOrApplicationRole

        XCTAssertEqual(
            service.debugRequestContextLines(config: config)
                .filter { $0.hasPrefix("App context") },
            [
                "App context attached to LLM request: no",
                "App context fallback reason: windowOrApplicationRole"
            ]
        )
    }

    private func makeConfiguration(
        screenshot: LLMService.ScreenshotAttachment? = nil,
        accessibilityContext: AccessibilityContext? = nil
    ) -> LLMService.Configuration {
        LLMService.Configuration(
            provider: "openai",
            apiKey: "key",
            openRouterApiKey: "",
            customProviderApiKey: "",
            customProviderBaseUrl: nil,
            model: "gpt-5.4-mini",
            customPrompt: nil,
            context: nil,
            targetProfileInstruction: nil,
            screenshotAttachment: screenshot,
            accessibilityContext: accessibilityContext
        )
    }
}
