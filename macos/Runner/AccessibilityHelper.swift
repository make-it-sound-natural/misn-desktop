import Cocoa
import os.log

/// Helper for checking macOS accessibility permissions and element editability
struct AccessibilityHelper {
    struct EditabilityResult {
        let isEditable: Bool
        let reason: String?
    }

    private static let logger = OSLog(
        subsystem: "com.makeitsoundnatural.macos",
        category: "AccessibilityHelper"
    )

    /// Known code editors that don't properly expose accessibility for text views
    /// These apps have custom text rendering and AX APIs return AXWindow instead of AXTextArea
    static let knownCodeEditors: Set<String> = [
        "com.sublimetext.4",
        "com.sublimetext.3",
        "com.sublimetext.2",
        "com.sublimehq.Sublime-Text",
        "com.microsoft.VSCode",
        "com.visualstudio.code.oss",
        "com.jetbrains.intellij",
        "com.jetbrains.intellij.ce",
        "com.jetbrains.WebStorm",
        "com.jetbrains.pycharm",
        "com.jetbrains.CLion",
        "com.jetbrains.goland",
        "com.jetbrains.rider",
        "com.jetbrains.AppCode",
        "com.jetbrains.PhpStorm",
        "com.jetbrains.RubyMine",
        "com.jetbrains.DataGrip",
        "com.github.atom",
        "io.brackets.appshell",
        "com.panic.Nova",
        "com.barebones.bbedit",
        "com.macromates.TextMate",
        "com.coteditor.CotEditor",
        "abnerworks.Typora",
        "com.toketaware.Emacs",
        "org.vim.MacVim",
        "net.kovidgoyal.kitty",
        "com.googlecode.iterm2",
        "com.apple.Terminal"
    ]

    /// List of roles that are typically editable text fields
    private static let editableRoles: Set<String> = [
        "AXTextField",
        "AXTextArea",
        "AXComboBox",
        "AXSearchField",
        "AXSecureTextField"
    ]

    /// Checks if accessibility permissions are granted
    /// - Returns: true if the app is trusted with accessibility permissions
    static func checkPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Checks if the currently focused UI element is editable
    /// - Returns: EditabilityResult with isEditable status and optional reason
    static func checkFocusedElementIsEditable() -> EditabilityResult {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            log("No frontmost application found")
            return EditabilityResult(isEditable: false, reason: "No active application")
        }

        if let bundleId = frontApp.bundleIdentifier, knownCodeEditors.contains(bundleId) {
            log("Known code editor detected: \(bundleId) - allowing operation")
            return EditabilityResult(isEditable: true, reason: nil)
        }

        guard let axElement = getFocusedElement(for: frontApp) else {
            return EditabilityResult(isEditable: true, reason: nil)
        }

        let role = getElementRole(axElement)
        log("Focused element role: \(role)")

        return checkElementEditability(axElement, role: role, appName: frontApp.localizedName)
    }

    /// Returns the focused window's Core Graphics window id when macOS exposes it.
    static func focusedWindowID(for app: NSRunningApplication) -> CGWindowID? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var focusedWindow: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard focusResult == .success, let focusedWindow = focusedWindow else {
            log("Could not get focused window (error: \(focusResult.rawValue))")
            return nil
        }

        let windowElement = unsafeBitCast(focusedWindow, to: AXUIElement.self)
        var windowNumber: CFTypeRef?
        let numberResult = AXUIElementCopyAttributeValue(
            windowElement,
            "AXWindowNumber" as CFString,
            &windowNumber
        )

        guard numberResult == .success,
              let number = windowNumber as? NSNumber else {
            log("Could not get focused window id (error: \(numberResult.rawValue))")
            return nil
        }

        return CGWindowID(number.uint32Value)
    }

    private static func getFocusedElement(for app: NSRunningApplication) -> AXUIElement? {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        if focusResult != .success {
            log("Could not get focused element (error: \(focusResult.rawValue))")
            return nil
        }

        guard let element = focusedElement else {
            log("Focused element is nil")
            return nil
        }

        return unsafeBitCast(element, to: AXUIElement.self)
    }

    private static func getElementRole(_ element: AXUIElement) -> String {
        var roleValue: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &roleValue
        )

        if roleResult == .success, let roleStr = roleValue as? String {
            return roleStr
        }

        return "unknown"
    }

    private static func checkElementEditability(
        _ element: AXUIElement,
        role: String,
        appName: String?
    ) -> EditabilityResult {
        if editableRoles.contains(role) {
            log("Element is editable (role: \(role))")
            return EditabilityResult(isEditable: true, reason: nil)
        }

        if checkAXEditableAttribute(element) {
            return EditabilityResult(isEditable: true, reason: nil)
        }

        if role == "AXWebArea" || role == "AXGroup" || role == "AXScrollArea" {
            log("Web/Group/ScrollArea detected - allowing operation")
            return EditabilityResult(isEditable: true, reason: nil)
        }

        if checkTextSelectionSupport(element) {
            return EditabilityResult(isEditable: true, reason: nil)
        }

        return notEditableResult(role: role, appName: appName)
    }

    private static func checkAXEditableAttribute(_ element: AXUIElement) -> Bool {
        var editableValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            "AXEditable" as CFString,
            &editableValue
        )

        if result == .success, let isEditable = editableValue as? Bool, isEditable {
            log("Element is editable (AXEditable: true)")
            return true
        }

        return false
    }

    private static func checkTextSelectionSupport(_ element: AXUIElement) -> Bool {
        var selectedTextValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedTextValue
        )

        if result == .success {
            log("Element supports text selection")
            return true
        }

        return false
    }

    private static func notEditableResult(role: String, appName: String?) -> EditabilityResult {
        let name = appName ?? "Unknown app"
        log("Element is not editable (role: \(role), app: \(name))")

        let reason = reasonForRole(role)
        return EditabilityResult(isEditable: false, reason: reason)
    }

    private static func reasonForRole(_ role: String) -> String {
        switch role {
        case "AXButton":
            return "You're focused on a button, not a text field"
        case "AXImage":
            return "You're focused on an image, not a text field"
        case "AXLink":
            return "You're focused on a link, not a text field"
        case "AXStaticText":
            return "You're focused on static text that can't be edited"
        case "AXWindow", "AXApplication":
            return "Focus on a text field to use this shortcut"
        default:
            return "The current element is not a text field"
        }
    }

    private static func log(_ message: String) {
        os_log("%{private}@", log: logger, type: .debug, message)
        #if DEBUG
        let timestamp = Date().timeIntervalSince1970
        print("⏱️ [\(String(format: "%.3f", timestamp))] \(message)")
        #endif
    }
}
