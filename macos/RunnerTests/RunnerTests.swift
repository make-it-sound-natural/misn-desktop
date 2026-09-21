import Sparkle
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

final class NightlySparkleVersionTests: XCTestCase {
    func testNightlyMigrationAndDailyOrdering() {
        let comparator = SUStandardVersionComparator.default
        let versions = ["1", "2", "3", "4", "5", "6",
                        "2026092001", "2026092009", "2026092010",
                        "2026092099", "2026092101", "2026100101"]
        for (older, newer) in zip(versions, versions.dropFirst()) {
            XCTAssertEqual(comparator.compareVersion(older, toVersion: newer),
                           .orderedAscending, "\(older) -> \(newer)")
            XCTAssertEqual(comparator.compareVersion(newer, toVersion: older),
                           .orderedDescending)
        }
        XCTAssertEqual(comparator.compareVersion("2026092001",
                                                 toVersion: "2026092001"),
                       .orderedSame)
    }

    func testMarketingVersionsAreNotUsedAsNightlyBuildNumbers() {
        let comparator = SUStandardVersionComparator.default
        // Sparkle ignores the suffix after a hyphen; display versions cannot
        // order two nightlies with the same base version.
        XCTAssertEqual(comparator.compareVersion("1.1.0-nightly.20260920.1",
                                                 toVersion: "1.1.0-nightly.20260921.1"),
                       .orderedSame)
        XCTAssertEqual(comparator.compareVersion("1.1.0-beta.1",
                                                 toVersion: "1.1.0"),
                       .orderedSame)
    }
}
