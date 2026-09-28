import Foundation

/// How much text the "App context" feature reads through the Accessibility
/// API from the app where the user is typing.
enum AccessibilityContextMode: String {
    case off
    case field
    case fieldAndNearby
}
