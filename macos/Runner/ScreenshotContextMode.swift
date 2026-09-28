import Foundation

enum ScreenshotContextMode: String {
    case off
    /// The active window cropped to the column around the focused field.
    case fieldArea
    case activeApplication
    case fullScreen

    static func parse(_ value: String?) -> ScreenshotContextMode {
        guard let value = value,
              let mode = ScreenshotContextMode(rawValue: value) else {
            return .off
        }
        return mode
    }
}
