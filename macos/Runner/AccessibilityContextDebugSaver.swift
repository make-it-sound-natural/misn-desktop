import Foundation

/// DEBUG-only: writes one JSON file per shortcut run with what the
/// Accessibility read produced and what happened to the screenshot. Lets the
/// per-app coverage be checked without printing user text to the console.
final class AccessibilityContextDebugSaver {
    private let environment: [String: String]
    private let store: DebugArtifactStore

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        outputDirectory: URL? = nil,
        maxFiles: Int = 20,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.environment = environment
        self.store = DebugArtifactStore(
            directoryEnvironmentKey: "MISN_ACCESSIBILITY_CONTEXT_DIR",
            defaultDirectoryName: "DebugAccessibilityContext",
            environment: environment,
            outputDirectory: outputDirectory,
            maxFiles: maxFiles,
            fileManager: fileManager,
            now: now
        )
    }

    /// `screenshotReason` is a short slug from the context source policy that
    /// explains `screenshotTaken`, for example why the screenshot was skipped.
    func saveIfEnabled(
        result: AccessibilityContextResult,
        screenshotTaken: Bool,
        screenshotReason: String
    ) -> URL? {
        #if DEBUG
        guard environment["MISN_SAVE_ACCESSIBILITY_CONTEXT"] == "1" else {
            debugLog(
                "Accessibility context debug save disabled. Set " +
                "MISN_SAVE_ACCESSIBILITY_CONTEXT=1"
            )
            return nil
        }

        let entry = AccessibilityContextDebugEntry(
            result: result,
            screenshotTaken: screenshotTaken,
            screenshotReason: screenshotReason
        )
        do {
            let fileURL = try store.write(
                try Self.encoder.encode(entry),
                nameSuffix: "\(entry.mode).json"
            )
            debugLog("Accessibility context debug saved: \(fileURL.path)")
            return fileURL
        } catch {
            debugLog("Accessibility context debug save failed: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys, .withoutEscapingSlashes
        ]
        return encoder
    }()

    private func debugLog(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }
}

/// The JSON written for one run. Keys without a value are left out.
private struct AccessibilityContextDebugEntry: Encodable {
    struct Timings: Encodable {
        let focusedElement: Double
        let metadata: Double
        let excerpt: Double
        let total: Double
    }

    struct Parts: Encodable {
        let windowTitle: String?
        let fieldLabel: String?
        let textBeforeSelection: String
        let textAfterSelection: String
        let nearbyText: String
    }

    struct Screenshot: Encodable {
        let taken: Bool
        let reason: String
    }

    let app: String?
    let bundleId: String?
    let role: String?
    let subrole: String?
    let mode: String
    let timingsMs: Timings
    let usable: Bool
    let unusableReason: String?
    let screenshot: Screenshot
    let parts: Parts
    /// The exact `<app_context>` block sent to the LLM. Absent when the read
    /// was unusable, because nothing is sent then.
    let appContext: String?

    init(
        result: AccessibilityContextResult,
        screenshotTaken: Bool,
        screenshotReason: String
    ) {
        let context: AccessibilityContext
        switch result {
        case .usable(let resolved):
            context = resolved
            usable = true
            unusableReason = nil
            appContext = PromptTemplates.appContextSection(resolved)
        case .unusable(let reason, let partial):
            context = partial
            usable = false
            unusableReason = reason.rawValue
            appContext = nil
        }

        app = context.appName
        bundleId = context.bundleId
        role = context.role
        subrole = context.subrole
        mode = context.mode.rawValue
        timingsMs = Timings(
            focusedElement: context.timings.focusedElement,
            metadata: context.timings.metadata,
            excerpt: context.timings.excerpt,
            total: context.timings.total
        )
        screenshot = Screenshot(taken: screenshotTaken, reason: screenshotReason)
        parts = Parts(
            windowTitle: context.windowTitle,
            fieldLabel: context.fieldLabel,
            textBeforeSelection: context.textBeforeSelection,
            textAfterSelection: context.textAfterSelection,
            nearbyText: context.nearbyText
        )
    }
}
