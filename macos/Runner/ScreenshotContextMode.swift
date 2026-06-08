import Foundation

enum ScreenshotContextMode: String {
    case off
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
