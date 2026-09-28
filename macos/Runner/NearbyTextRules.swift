import ApplicationServices

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
