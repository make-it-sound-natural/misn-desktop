import XCTest
@testable import Make_It_Sound_Natural

final class LLMServicePromptTests: XCTestCase {
    func testSystemPromptIncludesCustomPromptTargetProfileAndFixedRules() {
        let service = LLMService()
        let prompt = service.buildSystemPrompt(
            customPrompt: "Make it polished.\n",
            targetProfileInstruction: "Rewrite in natural British English."
        )

        XCTAssertTrue(prompt.contains("Make it polished."))
        XCTAssertTrue(prompt.contains("Rewrite in natural British English."))
        XCTAssertTrue(prompt.contains(PromptTemplates.fixedPromptSection))
    }

    func testConfigurationAcceptsTargetProfileInstruction() {
        let config = LLMService.Configuration(
            provider: "openai",
            apiKey: "key",
            openRouterApiKey: "",
            model: "gpt-5.4-nano",
            customPrompt: nil,
            context: nil,
            targetProfileInstruction: "Rewrite in natural Spanish.",
            screenshotAttachment: nil
        )

        XCTAssertEqual(
            config.targetProfileInstruction,
            "Rewrite in natural Spanish."
        )
    }

    func testSystemPromptMentionsScreenshotWhenAttachmentPresent() {
        let service = LLMService()
        let prompt = service.appendScreenshotInstructionIfNeededForTesting(
            systemInstructions: "Base rules",
            hasScreenshot: true
        )

        XCTAssertTrue(prompt.contains("screenshot is context only"))
        XCTAssertTrue(prompt.contains("rewrite only the selected text"))
    }
}
