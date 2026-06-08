import Cocoa
import Carbon

/// Handles processing results and pasting variants
class VariantHandler {
    struct ProcessingContext {
        let fullContent: String?
        let correctedText: String?
        let previousClipboard: String?
        let lastActiveAppBundleId: String?
        let simulateKeyPress: (CGKeyCode, CGEventFlags) -> Void
        let log: (String) -> Void
    }

    weak var delegate: VariantHandlerDelegate?

    func handleProcessingResult(_ context: ProcessingContext) {
        let fullContent = context.fullContent
        let correctedText = context.correctedText
        let previousClipboard = context.previousClipboard
        let log = context.log
        guard let correctedText = correctedText, let fullContent = fullContent else {
            handleFailure(previousClipboard, log: log)
            return
        }

        log("OpenAI response received. Variants generated.")
        delegate?.variantHandler(self, didGenerateVariants: fullContent)

        if checkWindowChanged(context.lastActiveAppBundleId, log: log) {
            handleWindowChanged(previousClipboard, log: log)
            return
        }

        pasteAndRestore(
            correctedText,
            previousClipboard: previousClipboard,
            simulateKeyPress: context.simulateKeyPress,
            log: log
        )
    }

    private func handleFailure(_ previousClipboard: String?, log: @escaping (String) -> Void) {
        log("Error: Failed to get correction (callback returned nil)")
        DispatchQueue.main.async {
            if !StatusBubble.shared.isShowingError {
                log("Hiding bubble (not showing error)")
                StatusBubble.shared.hide()
            } else {
                log("Bubble showing error - not hiding")
            }
        }
        delegate?.variantHandler(self, didFailWithError: "Failed to get correction")
        if let old = previousClipboard {
            ClipboardService.restore(old)
        }
    }

    private func checkWindowChanged(_ lastActiveAppBundleId: String?, log: @escaping (String) -> Void) -> Bool {
        let currentBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let changed = currentBundleId != lastActiveAppBundleId

        if changed {
            log("Window changed during processing - skipping auto-paste")
            log("Original: \(lastActiveAppBundleId ?? "nil"), Current: \(currentBundleId ?? "nil")")
        }

        return changed
    }

    private func handleWindowChanged(_ previousClipboard: String?, log: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            StatusBubble.shared.updateState(.cancelled)
        }

        delegate?.variantHandler(self, didChangeWindow: true)

        if let old = previousClipboard {
            log("Restoring original clipboard content (no paste)")
            ClipboardService.restore(old)
        }
    }

    private func pasteAndRestore(
        _ text: String,
        previousClipboard: String?,
        simulateKeyPress: @escaping (CGKeyCode, CGEventFlags) -> Void,
        log: @escaping (String) -> Void
    ) {
        log("Preparing to paste corrected text...")
        ClipboardService.setContent(text)

        usleep(50000)

        log("Simulating Cmd+V")
        simulateKeyPress(CGKeyCode(kVK_ANSI_V), .maskCommand)

        DispatchQueue.main.async {
            StatusBubble.shared.updateState(.success)
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.6) {
            if let old = previousClipboard {
                log("Restoring original clipboard content")
                ClipboardService.restore(old)
            }
        }

        delegate?.variantHandler(self, didCompleteSuccessfully: true)
    }
}

protocol VariantHandlerDelegate: AnyObject {
    func variantHandler(_ handler: VariantHandler, didGenerateVariants content: String)
    func variantHandler(_ handler: VariantHandler, didFailWithError error: String)
    func variantHandler(_ handler: VariantHandler, didChangeWindow: Bool)
    func variantHandler(_ handler: VariantHandler, didCompleteSuccessfully: Bool)
}
