import Foundation

/// Field text around the selection as the target app reported it. Offsets
/// are UTF-16 code units, the unit AX ranges use.
struct AccessibilityFieldExcerpt: Equatable {
    let text: String
    /// Where the app said the selection is, relative to `text`.
    let selection: NSRange
    /// Whether `text` starts at the beginning of the field, so its first word
    /// is complete.
    let startsAtFieldStart: Bool
    /// Whether `text` ends at the end of the field, so its last word is
    /// complete.
    let endsAtFieldEnd: Bool

    /// Splits the excerpt around the copied text and trims the words the
    /// excerpt window cut through. Returns nil when the copied text is not in
    /// the excerpt.
    func split(around copiedText: String) -> (before: String, after: String)? {
        let text = self.text as NSString
        guard let located = locate(copiedText, in: text) else { return nil }

        var start = 0
        var end = text.length
        // A window edge can fall inside a surrogate pair; drop the lone half
        // (or the U+FFFD an app may have put in its place).
        if !startsAtFieldStart, end > start,
           Self.isBrokenHalf(text.character(at: start), UTF16.isTrailSurrogate) {
            start += 1
        }
        if !endsAtFieldEnd, end > start,
           Self.isBrokenHalf(text.character(at: end - 1), UTF16.isLeadSurrogate) {
            end -= 1
        }
        guard start <= located.location, NSMaxRange(located) <= end else {
            return nil
        }

        let before = text.substring(
            with: NSRange(location: start, length: located.location - start)
        )
        let after = text.substring(
            with: NSRange(
                location: NSMaxRange(located),
                length: end - NSMaxRange(located)
            )
        )
        return (
            startsAtFieldStart ? before : Self.droppingFirstPartialWord(before),
            endsAtFieldEnd ? after : Self.droppingLastPartialWord(after)
        )
    }

    private func locate(_ copiedText: String, in text: NSString) -> NSRange? {
        let copied = Self.normalized(copiedText)
        if !copied.isEmpty, NSMaxRange(selection) <= text.length,
           Self.normalized(text.substring(with: selection)) == copied {
            return selection
        }
        // Some apps report offsets that drift from the text they return
        // (attachments, collapsed markup). Trust the copied text instead and
        // take its occurrence nearest to the reported selection.
        let trimmed = copiedText.trimmingCharacters(in: .whitespacesAndNewlines)
        for needle in [copiedText, trimmed] where !needle.isEmpty {
            if let range = nearestOccurrence(of: needle, in: text) {
                return range
            }
        }
        return nil
    }

    private func nearestOccurrence(
        of needle: String,
        in text: NSString
    ) -> NSRange? {
        var nearest: NSRange?
        var searchRange = NSRange(location: 0, length: text.length)
        while true {
            let found = text.range(
                of: needle,
                options: .literal,
                range: searchRange
            )
            guard found.location != NSNotFound else { break }
            let distance = abs(found.location - selection.location)
            if nearest.map({ abs($0.location - selection.location) > distance })
                ?? true {
                nearest = found
            }
            let next = found.location + 1
            searchRange = NSRange(location: next, length: text.length - next)
        }
        return nearest
    }

    private static func isBrokenHalf(
        _ unit: unichar,
        _ isHalf: (UTF16.CodeUnit) -> Bool
    ) -> Bool {
        isHalf(unit) || unit == 0xFFFD
    }

    /// Copying through the pasteboard can change line endings, non-breaking
    /// spaces and surrounding whitespace.
    private static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Keeps text without any whitespace (e.g. CJK) whole rather than
    /// dropping all of it.
    private static func droppingFirstPartialWord(_ text: String) -> String {
        guard let cut = text.firstIndex(where: { $0.isWhitespace }) else {
            return text
        }
        return String(text[text.index(after: cut)...])
    }

    private static func droppingLastPartialWord(_ text: String) -> String {
        guard let cut = text.lastIndex(where: { $0.isWhitespace }) else {
            return text
        }
        return String(text[..<cut])
    }
}
