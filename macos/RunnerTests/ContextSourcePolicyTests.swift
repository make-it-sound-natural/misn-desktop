import XCTest
@testable import Make_It_Sound_Natural

final class ContextSourcePolicyTests: XCTestCase {
    private typealias Reason = ContextSourcePolicy.ScreenshotReason

    private let screenshotModes: [ScreenshotContextMode] = [
        .off, .activeApplication, .fullScreen,
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

    func testFieldExcerptIsSentAndComplementsTheScreenshot() {
        let modes: [AccessibilityContextMode] = [.field, .fieldAndNearby]
        for mode in modes {
            let field = context(mode: mode)
            for screenshotMode in screenshotModes {
                let screenshotOn = screenshotMode != .off
                assertDecision(
                    .usable(field),
                    screenshotMode: screenshotMode,
                    sends: field,
                    fallbackReason: nil,
                    screenshotReason: screenshotOn ? .noNearbyText : .screenshotOff,
                    takesScreenshot: screenshotOn
                )
            }
        }
    }

    func testNearbyTextReplacesTheScreenshot() {
        let nearby = context(
            mode: .fieldAndNearby,
            nearbyText: "Anna: is the draft ready?"
        )
        for screenshotMode in screenshotModes {
            assertDecision(
                .usable(nearby),
                screenshotMode: screenshotMode,
                sends: nearby,
                fallbackReason: nil,
                screenshotReason: .nearbyTextAvailable,
                takesScreenshot: false
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
