import ApplicationServices
import Foundation

enum NearbyTextLimits {
    /// Shared by every ancestor the walk climbs. Slack's message pane alone
    /// is about 290 nodes, and the empty levels below it cost a few dozen.
    static let nodeBudget = 500
    static let deadline: TimeInterval = 0.15
    /// In UTF-16 units, like every cap on text read from another app.
    static let textLength = 3_000
    /// The climb goes on until it has this much text, so a short label next
    /// to the field does not stand in for the thread above it.
    static let climbTextLength = 1_000
}

/// Which elements the nearby text walk skips.
enum NearbyTextRoles {
    /// Chrome and navigation around the content, never message text. Applies
    /// below the ancestors only: a field inside a tab group still gets the
    /// rest of that tab's content.
    static let skippedRoles: Set<String> = [
        kAXToolbarRole,
        kAXMenuBarRole,
        kAXMenuRole,
        kAXTabGroupRole,
        kAXOutlineRole,
        kAXScrollBarRole
    ]

    /// Sidebar lists: AppKit source lists and web navigation landmarks.
    static let skippedSubroles: Set<String> = [
        "AXSourceList",
        "AXLandmarkNavigation"
    ]

    /// Containers whose subrole can mark a sidebar; only these pay for the
    /// extra subrole read.
    static let subroleCheckedRoles: Set<String> = [
        kAXGroupRole,
        kAXListRole
    ]
}

/// Text and geometry rules of the nearby walk that need no Accessibility
/// reads.
enum NearbyTextFilters {
    private typealias Limits = NearbyTextLimits

    static func clean(_ raw: String) -> String? {
        let text = raw
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // A single Character over the cap leaves nothing.
        let capped = suffix(text, Limits.textLength)
        return capped.isEmpty ? nil : capped
    }

    static func overlapsHorizontally(_ frame: CGRect, _ field: CGRect) -> Bool {
        frame.minX < field.maxX && frame.maxX > field.minX
    }

    /// Slack's virtualized message list is 1 px square while its rows span
    /// the whole pane.
    static func isDegenerate(_ frame: CGRect) -> Bool {
        frame.width <= 1 || frame.height <= 1
    }

    /// The last `limit` UTF-16 units, starting at a whole word when cut.
    static func suffix(_ text: String, _ limit: Int) -> String {
        guard text.utf16.count > limit else { return text }
        guard limit > 0 else { return "" }
        return text.suffix(utf16Limit: limit).droppingFirstPartialWord()
    }
}
