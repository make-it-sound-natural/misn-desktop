import XCTest
@testable import Make_It_Sound_Natural

final class RunnerTests: XCTestCase {
    func testAccessibilityCheckDoesNotRequestPrompt() {
        let result = AccessibilityPermissionProbe.status(
            prompt: false,
            isTrusted: { prompt in
                XCTAssertFalse(prompt)
                return false
            }
        )

        XCTAssertFalse(result)
    }

    func testAccessibilityRequestUsesPrompt() {
        let result = AccessibilityPermissionProbe.status(
            prompt: true,
            isTrusted: { prompt in
                XCTAssertTrue(prompt)
                return true
            }
        )

        XCTAssertTrue(result)
    }

    func testCustomProviderKeychainAccountIsScopedAndSanitized() {
        XCTAssertEqual(
            MethodChannelHandler.customProviderKeychainAccount(provider: "tokenguard"),
            "custom_provider_api_key_tokenguard"
        )
        XCTAssertEqual(
            MethodChannelHandler.customProviderKeychainAccount(provider: "token guard"),
            "custom_provider_api_key_token-guard"
        )
        XCTAssertEqual(
            MethodChannelHandler.customProviderKeychainAccount(provider: " TokenGuard "),
            "custom_provider_api_key_tokenguard"
        )
        XCTAssertNil(
            MethodChannelHandler.customProviderKeychainAccount(provider: "!!!")
        )
    }
}
