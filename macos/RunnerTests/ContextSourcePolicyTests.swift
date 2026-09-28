import XCTest
@testable import Make_It_Sound_Natural

final class ContextSourcePolicyTests: XCTestCase {
    private typealias Reason = ContextSourcePolicy.ScreenshotReason

    private let screenshotModes: [ScreenshotContextMode] = [
        .off, .fieldArea, .activeApplication, .fullScreen,
    ]

    private func context(
        mode: AccessibilityContextMode,
        nearbyText: String = ""
    ) -> AccessibilityContext {
        var context = AccessibilityContext(
            mode: mode,
            appName: "Mail",
            bundleId: "com.apple.mail"
        )
        context.textBeforeSelection = "Hi Anna, "
        context.nearbyText = nearbyText
        return context
    }

    private func assertDecision(
        _ accessibility: AccessibilityContextResult?,
        screenshotMode: ScreenshotContextMode,
        sends expectedContext: AccessibilityContext?,
        fallbackReason: AccessibilityContext.UnusableReason?,
        screenshotReason: Reason,
        takesScreenshot: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let decision = ContextSourcePolicy.decide(
            accessibility: accessibility,
            screenshotMode: screenshotMode
        )
        let label = "screenshot mode \(screenshotMode.rawValue)"
        XCTAssertEqual(
            decision.accessibilityContext, expectedContext, label,
            file: file, line: line
        )
        XCTAssertEqual(
            decision.accessibilityFallbackReason, fallbackReason, label,
            file: file, line: line
        )
        XCTAssertEqual(
            decision.screenshotReason, screenshotReason, label,
            file: file, line: line
        )
        XCTAssertEqual(
            decision.takesScreenshot, takesScreenshot, label,
            file: file, line: line
        )
    }

    func testAccessibilityOffUsesOnlyTheScreenshotSetting() {
        for screenshotMode in screenshotModes {
            let screenshotOn = screenshotMode != .off
            assertDecision(
                nil,
                screenshotMode: screenshotMode,
                sends: nil,
                fallbackReason: nil,
                screenshotReason: screenshotOn ? .accessibilityOff : .screenshotOff,
                takesScreenshot: screenshotOn
            )
        }
    }

    func testUsableReadIsSentAndTheScreenshotFollowsItsSetting() {
        let contexts = [
            context(mode: .field),
            context(mode: .fieldAndNearby),
            context(
                mode: .fieldAndNearby,
                nearbyText: "Anna: is the draft ready?"
            )
        ]
        for sent in contexts {
            for screenshotMode in screenshotModes {
                let screenshotOn = screenshotMode != .off
                assertDecision(
                    .usable(sent),
                    screenshotMode: screenshotMode,
                    sends: sent,
                    fallbackReason: nil,
                    screenshotReason: screenshotOn
                        ? .accessibilityUsable
                        : .screenshotOff,
                    takesScreenshot: screenshotOn
                )
            }
        }
    }

    /// The whole message selected, or a field without a range: the source
    /// and any nearby text still go out.
    func testUnusableReadThatReachedTheFieldSendsWhatItHas() {
        var partial = context(mode: .fieldAndNearby)
        partial.textBeforeSelection = ""
        partial.nearbyText = "Anna: is the draft ready?"
        let reasons: [AccessibilityContext.UnusableReason] = [
            .noSurroundingText, .mostlyPlaceholderText, .rangeUnavailable,
        ]
        for reason in reasons {
            assertDecision(
                .unusable(reason, partial: partial),
                screenshotMode: .activeApplication,
                sends: partial,
                fallbackReason: reason,
                screenshotReason: .accessibilityUnusable,
                takesScreenshot: true
            )
        }
    }

    func testUnusableReadFallsBackToTheScreenshotOnlyWhenItIsOn() {
        let modes: [AccessibilityContextMode] = [.field, .fieldAndNearby]
        let reasons: [AccessibilityContext.UnusableReason] = [
            .selectionMismatch, .timeout, .secureField,
        ]
        for mode in modes {
            for reason in reasons {
                let result = AccessibilityContextResult.unusable(
                    reason,
                    partial: context(mode: mode)
                )
                for screenshotMode in screenshotModes {
                    let screenshotOn = screenshotMode != .off
                    assertDecision(
                        result,
                        screenshotMode: screenshotMode,
                        sends: nil,
                        fallbackReason: reason,
                        screenshotReason: screenshotOn
                            ? .accessibilityUnusable
                            : .screenshotOff,
                        takesScreenshot: screenshotOn
                    )
                }
            }
        }
    }
}
