import Foundation

/// IDs for registered hotkeys - must match ShortcutManager registration
enum ShortcutID: UInt32 {
    case correction = 1
    case replaceContext = 2
    case appendContext = 3
}

/// Protocol for handling shortcut actions (allows testing with mocks)
protocol ShortcutActionHandler: AnyObject {
    func performCorrection()
    func captureContext(replace: Bool)
}

/// Dispatches shortcut triggers to appropriate handlers
class ShortcutDispatcher {
    weak var actionHandler: ShortcutActionHandler?

    func dispatch(shortcutID: UInt32) {
        guard let id = ShortcutID(rawValue: shortcutID) else {
            return
        }

        switch id {
        case .correction:
            actionHandler?.performCorrection()
        case .replaceContext:
            actionHandler?.captureContext(replace: true)
        case .appendContext:
            actionHandler?.captureContext(replace: false)
        }
    }
}
