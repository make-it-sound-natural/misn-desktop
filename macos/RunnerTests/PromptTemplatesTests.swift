import XCTest
@testable import Make_It_Sound_Natural

final class PromptTemplatesTests: XCTestCase {

    // MARK: - Capitalization Preservation

    func testFixedSectionContainsWordLevelCapitalizationRule() {
        let fixed = PromptTemplates.fixedPromptSection
        XCTAssertTrue(
            fixed.contains("Preserve the capitalization of EVERY word"),
            """
            fixedPromptSection must instruct the LLM to preserve \
            per-word capitalization, not just the first character.
            """
        )
    }

    func testFixedSectionContainsBrandNameExample() {
        let fixed = PromptTemplates.fixedPromptSection
        // The prompt must include an example showing that
        // lowercase brand names stay lowercase.
        XCTAssertTrue(
            fixed.contains(
                "\"I use vscode daily\""
            ),
            """
            fixedPromptSection must include a brand-name \
            example showing lowercase preservation.
            """
        )
    }

    func testFixedSectionContainsAcronymExample() {
        let fixed = PromptTemplates.fixedPromptSection
        XCTAssertTrue(
            fixed.contains(
                "\"the api is slow\""
            ),
            """
            fixedPromptSection must include an acronym example \
            showing lowercase preservation.
            """
        )
    }

    // MARK: - Structural Integrity

    func testDefaultSystemPromptCombinesCustomizableTargetAndFixed() {
        let full = PromptTemplates.defaultSystemPrompt
        let customizable = PromptTemplates.defaultCustomizablePrompt
        let targetProfile = PromptTemplates.targetProfileSection(
            instruction: "Rewrite in natural American English."
        )
        let fixed = PromptTemplates.fixedPromptSection
        XCTAssertEqual(
            full,
            customizable + targetProfile + fixed,
            "defaultSystemPrompt must equal customizable + target profile + fixed"
        )
    }

    func testFixedSectionContainsFourVariantLabels() {
        let fixed = PromptTemplates.fixedPromptSection
        for label in ["balanced", "casual", "formal", "concise"] {
            XCTAssertTrue(
                fixed.contains(label),
                "fixedPromptSection must mention variant '\(label)'"
            )
        }
    }

    func testFixedSectionPreservesUrlRule() {
        let fixed = PromptTemplates.fixedPromptSection
        XCTAssertTrue(
            fixed.contains("URLS: NEVER remove, modify, or summarize"),
            "fixedPromptSection must contain URL preservation rule"
        )
    }

    func testFixedSectionPreservesLineBreakRule() {
        let fixed = PromptTemplates.fixedPromptSection
        XCTAssertTrue(
            fixed.contains("LINE BREAKS: Preserve ALL line breaks"),
            "fixedPromptSection must contain line break preservation"
        )
    }

    func testFixedSectionContainsParagraphBreakRule() {
        let fixed = PromptTemplates.fixedPromptSection
        XCTAssertTrue(
            fixed.contains("NEVER remove blank lines between paragraphs"),
            """
            fixedPromptSection must explicitly forbid removing \
            blank lines between paragraphs.
            """
        )
    }

    func testFixedSectionContainsMergeParagraphsProhibition() {
        let fixed = PromptTemplates.fixedPromptSection
        XCTAssertTrue(
            fixed.contains(
                "NEVER merge separate paragraphs or lines"
            ),
            """
            fixedPromptSection must explicitly forbid merging \
            separate paragraphs into one.
            """
        )
    }

    // MARK: - Target Profile Composition

    func testDefaultCustomizablePromptDoesNotHardCodeAmericanEnglish() {
        let customizable = PromptTemplates.defaultCustomizablePrompt
        XCTAssertFalse(customizable.contains("American English"))
    }

    func testDefaultCustomizablePromptDoesNotMentionHiddenTargetProfile() {
        let customizable = PromptTemplates.defaultCustomizablePrompt
        XCTAssertFalse(
            customizable.contains("selected target profile"),
            "default prompt should not expose hidden app configuration"
        )
        XCTAssertTrue(
            customizable.contains("Make the text sound natural"),
            "default prompt should stay clear as user-editable text"
        )
    }

    func testTargetProfileSectionWrapsInstruction() {
        let section = PromptTemplates.targetProfileSection(
            instruction: "Rewrite in natural British English."
        )
        XCTAssertTrue(section.contains("<target_profile>"))
        XCTAssertTrue(section.contains("Rewrite in natural British English."))
    }

    func testFixedSectionDoesNotForceEnglishTranslation() {
        let fixed = PromptTemplates.fixedPromptSection
        XCTAssertFalse(fixed.contains("translate to natural English first"))
        XCTAssertFalse(fixed.contains("better English"))
        XCTAssertTrue(fixed.contains("Follow the target profile"))
    }

    func testFixedSectionTreatsTargetProfileAsAppConfiguration() {
        let fixed = PromptTemplates.fixedPromptSection
        XCTAssertTrue(fixed.contains("target_profile is application configuration"))
        XCTAssertTrue(fixed.contains("highest-priority language"))
        XCTAssertTrue(fixed.contains("Do follow target_profile"))
    }

    func testFixedSectionRequiresAllVariantsInTargetProfile() {
        let fixed = PromptTemplates.fixedPromptSection
        XCTAssertTrue(fixed.contains("MUST all be written in the"))
        XCTAssertTrue(fixed.contains("translate every variant"))
        XCTAssertTrue(fixed.contains("FINAL TARGET CHECK"))
        XCTAssertTrue(fixed.contains("target_profile wins"))
    }

    func testFixedSectionSaysStyleLabelsCannotCancelTargetProfile() {
        let fixed = PromptTemplates.fixedPromptSection
        XCTAssertTrue(fixed.contains("Style labels NEVER cancel target_profile"))
        XCTAssertTrue(fixed.contains("formal variant may be more orderly"))
    }

    func testFixedSectionForbidsAddedBlankLines() {
        let fixed = PromptTemplates.fixedPromptSection
        XCTAssertTrue(fixed.contains("NEVER add blank lines"))
        XCTAssertTrue(fixed.contains("compare input and output line break counts"))
    }
}
