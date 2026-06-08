import Carbon
import Cocoa
import os.log

/// Manages global hotkey registration and validation
class ShortcutManager {
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyRefContextReplace: EventHotKeyRef?
    private var hotKeyRefContextAppend: EventHotKeyRef?

    private var currentCorrectionShortcut: String?
    private var currentReplaceShortcut: String?
    private var currentAppendShortcut: String?

    private weak var delegate: ShortcutManagerDelegate?

    private let logger = OSLog(
        subsystem: "com.makeitsoundnatural.macos",
        category: "ShortcutManager"
    )

    init(delegate: ShortcutManagerDelegate) {
        self.delegate = delegate
    }

    func registerShortcut() {
        updateCorrectionShortcut(AppDefaults.correctionShortcut)
        updateReplaceShortcut(AppDefaults.replaceShortcut)
        updateAppendShortcut(AppDefaults.appendShortcut)
    }

    func updateCorrectionShortcut(_ shortcut: String) {
        log("Updating correction shortcut to: \(shortcut)")
        currentCorrectionShortcut = shortcut

        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }

        registerHotKey(shortcut, id: 1, ref: &hotKeyRef)
    }

    func updateReplaceShortcut(_ shortcut: String) {
        log("Updating replace shortcut to: \(shortcut)")
        currentReplaceShortcut = shortcut

        if let ref = hotKeyRefContextReplace {
            UnregisterEventHotKey(ref)
            hotKeyRefContextReplace = nil
        }

        registerHotKey(shortcut, id: 2, ref: &hotKeyRefContextReplace)
    }

    func updateAppendShortcut(_ shortcut: String) {
        log("Updating append shortcut to: \(shortcut)")
        currentAppendShortcut = shortcut

        if let ref = hotKeyRefContextAppend {
            UnregisterEventHotKey(ref)
            hotKeyRefContextAppend = nil
        }

        registerHotKey(shortcut, id: 3, ref: &hotKeyRefContextAppend)
    }

    func disableShortcuts() {
        log("Disabling global shortcuts")

        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }

        if let ref = hotKeyRefContextReplace {
            UnregisterEventHotKey(ref)
            hotKeyRefContextReplace = nil
        }

        if let ref = hotKeyRefContextAppend {
            UnregisterEventHotKey(ref)
            hotKeyRefContextAppend = nil
        }
    }

    func enableShortcuts() {
        log("Enabling global shortcuts")

        if let current = currentCorrectionShortcut {
            updateCorrectionShortcut(current)
        } else {
            updateCorrectionShortcut(AppDefaults.correctionShortcut)
        }

        if let current = currentReplaceShortcut {
            updateReplaceShortcut(current)
        } else {
            updateReplaceShortcut(AppDefaults.replaceShortcut)
        }

        if let current = currentAppendShortcut {
            updateAppendShortcut(current)
        } else {
            updateAppendShortcut(AppDefaults.appendShortcut)
        }
    }

    func validateShortcut(
        _ shortcut: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard let (keyCode, modifiers) = parseShortcut(shortcut) else {
            completion(false, "Invalid format")
            return
        }

        if let conflict = checkConfiguredShortcutConflict(keyCode, modifiers) {
            completion(false, conflict)
            return
        }

        if let conflict = checkSystemShortcutConflict(keyCode, modifiers) {
            completion(false, conflict)
            return
        }

        completion(true, nil)
    }

    // MARK: - Private Methods

    private func registerHotKey(_ shortcut: String, id: UInt32, ref: inout EventHotKeyRef?) {
        guard let (keyCode, modifiers) = parseShortcut(shortcut) else {
            log("Failed to parse shortcut: \(shortcut)")
            return
        }

        let hotKeyID = EventHotKeyID(signature: 0x4D49534E, id: id)
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        if eventHandler == nil {
            let selfPointer = UnsafeMutableRawPointer(
                Unmanaged.passUnretained(self).toOpaque()
            )
            let handlerBlock: EventHandlerUPP = { _, theEvent, userData -> OSStatus in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<ShortcutManager>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                return manager.handleHotKey(theEvent)
            }
            InstallEventHandler(
                GetApplicationEventTarget(),
                handlerBlock,
                1,
                &eventType,
                selfPointer,
                &eventHandler
            )
        }

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr {
            log("Registered shortcut ID \(id): \(shortcut)")
        } else {
            log("Failed to register shortcut ID \(id): \(shortcut) (Status: \(status))")
        }
    }

    private func handleHotKey(_ event: EventRef?) -> OSStatus {
        log("Shortcut triggered!")

        var hotKeyID = EventHotKeyID()
        GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        delegate?.shortcutManager(self, didTriggerHotKeyWithID: hotKeyID.id)
        return noErr
    }

    private func parseShortcut(_ shortcut: String) -> (UInt32, UInt32)? {
        log("parseShortcut called with: \(shortcut)")
        let parts = shortcut.lowercased().components(separatedBy: "+")
        var modifiers: UInt32 = 0
        var keyCode: UInt32?

        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            log("Parsing part: '\(trimmed)'")
            switch trimmed {
            case "cmd", "command", "meta": modifiers |= UInt32(cmdKey)
            case "shift": modifiers |= UInt32(shiftKey)
            case "ctrl", "control": modifiers |= UInt32(controlKey)
            case "alt", "option": modifiers |= UInt32(optionKey)
            default:
                keyCode = KeyCodeMapper.keyCode(for: trimmed)
                log("Parsed key '\(trimmed)' -> code: \(String(describing: keyCode))")
            }
        }

        guard let code = keyCode else {
            log("parseShortcut failed: No key code found")
            return nil
        }
        log("parseShortcut success: code=\(code), modifiers=\(modifiers)")
        return (code, modifiers)
    }

    private func checkConfiguredShortcutConflict(
        _ keyCode: UInt32,
        _ modifiers: UInt32
    ) -> String? {
        if let correction = currentCorrectionShortcut,
           let (corrCode, corrMods) = parseShortcut(correction),
           corrCode == keyCode, corrMods == modifiers {
            return "Correction Shortcut"
        }

        if let replace = currentReplaceShortcut,
           let (repCode, repMods) = parseShortcut(replace),
           repCode == keyCode, repMods == modifiers {
            return "Replace Context Shortcut"
        }

        if let append = currentAppendShortcut,
           let (appCode, appMods) = parseShortcut(append),
           appCode == keyCode, appMods == modifiers {
            return "Append Context Shortcut"
        }

        return nil
    }

    private func checkSystemShortcutConflict(_ keyCode: UInt32, _ modifiers: UInt32) -> String? {
        if modifiers == cmdKey {
            return checkCmdShortcuts(keyCode)
        }

        if modifiers == (cmdKey | shiftKey) {
            return checkCmdShiftShortcuts(keyCode)
        }

        return nil
    }

    private func checkCmdShortcuts(_ keyCode: UInt32) -> String? {
        let conflicts: [UInt32: String] = [
            UInt32(kVK_ANSI_C): "Copy",
            UInt32(kVK_ANSI_V): "Paste",
            UInt32(kVK_ANSI_X): "Cut",
            UInt32(kVK_ANSI_Z): "Undo",
            UInt32(kVK_ANSI_A): "Select All",
            UInt32(kVK_ANSI_Q): "Quit",
            UInt32(kVK_ANSI_W): "Close Window",
            UInt32(kVK_Space): "Spotlight",
            UInt32(kVK_Tab): "App Switcher"
        ]
        return conflicts[keyCode]
    }

    private func checkCmdShiftShortcuts(_ keyCode: UInt32) -> String? {
        if keyCode == kVK_ANSI_3 || keyCode == kVK_ANSI_4 || keyCode == kVK_ANSI_5 {
            return "Screenshots"
        }
        return nil
    }

    private func log(_ message: String) {
        os_log("%{private}@", log: logger, type: .debug, message)
        #if DEBUG
        let timestamp = Date().timeIntervalSince1970
        print("⏱️ [\(String(format: "%.3f", timestamp))] \(message)")
        #endif
    }
}

protocol ShortcutManagerDelegate: AnyObject {
    func shortcutManager(_ manager: ShortcutManager, didTriggerHotKeyWithID id: UInt32)
}
