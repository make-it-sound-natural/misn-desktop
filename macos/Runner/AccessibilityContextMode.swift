import Foundation

/// How much text the "App context" feature reads through the Accessibility
/// API from the app where the user is typing.
enum AccessibilityContextMode: String {
    case off
    case field
    case fieldAndNearby

    static func parse(_ value: String?) -> AccessibilityContextMode {
        guard let value = value,
              let mode = AccessibilityContextMode(rawValue: value) else {
            return .off
        }
        return mode
    }
}
