import XCTest

@testable import Make_It_Sound_Natural

/// Covers the predicate that decides whether Cmd+Z is sent into the user's
/// document. A wrong `true` here destroys text the app did not write, so the
/// boundaries are pinned explicitly.
final class PasteVerificationTests: XCTestCase {

    private func matches(
        _ pasted: String,
        in value: String,
        atCaret caret: Int
    ) -> Bool {
        AccessibilityHelper.suffixMatches(pasted, in: value, atCaret: caret)
    }

    func testCaretRightAfterThePasteMatches() {
        XCTAssertTrue(matches("world", in: "hello world", atCaret: 11))
    }

    func testPasteFollowedByMoreTextStillMatchesAtItsOwnCaret() {
        // The paste need not end the document — only sit before the caret.
        XCTAssertTrue(matches("hello", in: "hello world", atCaret: 5))
    }

    func testTypingAfterThePasteBreaksTheMatch() {
        // The exact case the guard exists for: undoing here would eat the
        // character the user just typed.
        XCTAssertFalse(matches("world", in: "hello world!", atCaret: 12))
    }

    func testCaretBeforeTheEndOfThePasteDoesNotMatch() {
        XCTAssertFalse(matches("hello", in: "hi", atCaret: 2))
    }

    func testCaretPastTheEndOfTheValueDoesNotMatch() {
        XCTAssertFalse(matches("hi", in: "hi", atCaret: 5))
    }

    func testEmptyPasteNeverMatches() {
        XCTAssertFalse(matches("", in: "hello", atCaret: 5))
    }

    // MARK: - Unit alignment

    /// Regression: the caret is a UTF-16 offset. Indexing grapheme clusters
    /// with it made every field containing an emoji fail verification, so the
    /// replacement silently degraded to a clipboard copy.
    func testAstralCharactersBeforeTheCaretStillMatch() {
        let value = "café 🎉done"
        XCTAssertEqual((value as NSString).length, 11)
        XCTAssertEqual(value.count, 10, "grapheme count differs from UTF-16")

        XCTAssertTrue(matches("🎉done", in: value, atCaret: 11))
    }

    func testDecomposedDiacriticsBeforeTheCaretStillMatch() {
        let value = "cafe\u{301} 🎉done"
        XCTAssertEqual((value as NSString).length, 12)

        XCTAssertTrue(matches("🎉done", in: value, atCaret: 12))
    }

    func testPastedEmojiIsComparedWhole() {
        XCTAssertTrue(matches("🎉", in: "ok 🎉", atCaret: 5))
        XCTAssertFalse(matches("🎉", in: "ok 🎉!", atCaret: 6))
    }
}
