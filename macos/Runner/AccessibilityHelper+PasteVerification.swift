import Cocoa
import os.log

/// Verifies that a paste this app performed is still intact.
extension AccessibilityHelper {

    /// Returns whether [text] sits immediately before the caret in the app's
    /// focused text element.
    ///
    /// Used to confirm that a paste this app performed is still the last
    /// thing in that field before undoing it. If anything has been typed,
    /// deleted, or the focus moved, this returns false and the caller must
    /// not send an undo.
    static func focusedTextEndsWith(
        _ text: String,
        for app: NSRunningApplication
    ) -> Bool {
        guard !text.isEmpty else { return false }
        guard let element = focusedElement(for: app) else {
            log("Cannot verify paste: no focused element")
            return false
        }

        var valueRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                element,
                kAXValueAttribute as CFString,
                &valueRef
            ) == .success,
            let value = valueRef as? String
        else {
            log("Cannot verify paste: focused element has no readable value")
            return false
        }

        var rangeRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                &rangeRef
            ) == .success,
            let rangeValue = rangeRef,
            CFGetTypeID(rangeValue) == AXValueGetTypeID()
        else {
            log("Cannot verify paste: no selection range")
            return false
        }

        var range = CFRange(location: 0, length: 0)
        guard
            AXValueGetValue(
                unsafeBitCast(rangeValue, to: AXValue.self),
                .cfRange,
                &range
            )
        else {
            log("Cannot verify paste: unreadable selection range")
            return false
        }

        let caret = range.location + range.length
        guard Self.suffixMatches(text, in: value, atCaret: caret) else {
            log("Cannot verify paste: our text is not at the caret")
            return false
        }
        return true
    }

    /// Returns whether [pasted] occupies the positions ending at [caret]
    /// in [value].
    ///
    /// Split out from the AX plumbing so the arithmetic can be tested without
    /// a live application.
    ///
    /// [caret] is an offset in UTF-16 code units, because that is what
    /// `kAXSelectedTextRangeAttribute` reports — it is an `NSRange`. The
    /// comparison therefore has to happen in the same unit: indexing a
    /// `Character` array with this offset misaligns as soon as the text holds
    /// an emoji, a non-BMP character, or a decomposed diacritic, which
    /// silently disabled the whole replacement for that field.
    static func suffixMatches(
        _ pasted: String,
        in value: String,
        atCaret caret: Int
    ) -> Bool {
        guard !pasted.isEmpty else { return false }

        // NSString indexes in UTF-16 too, and slicing it copies only the
        // suffix — the focused element may hold an entire document, so this
        // must not walk or materialise the whole value.
        let haystack = value as NSString
        let length = (pasted as NSString).length
        guard caret >= length, caret <= haystack.length else { return false }

        let range = NSRange(location: caret - length, length: length)
        return haystack.substring(with: range) == pasted
    }

    private static func log(_ message: String) {
        #if DEBUG
        print("🔎 PasteVerification: \(message)")
        #endif
    }

    private static func focusedElement(
        for app: NSRunningApplication
    ) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                appElement,
                kAXFocusedUIElementAttribute as CFString,
                &focused
            ) == .success,
            let element = focused
        else {
            return nil
        }
        return unsafeBitCast(element, to: AXUIElement.self)
    }
}
