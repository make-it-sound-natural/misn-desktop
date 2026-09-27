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

    /// `decision` is what the context source policy made of `result`: the
    /// App context that was sent and why the screenshot was or was not taken.
    func saveIfEnabled(
        result: AccessibilityContextResult,
        decision: ContextSourcePolicy.Decision,
        screenshotTaken: Bool
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
            decision: decision,
            screenshotTaken: screenshotTaken
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
        let nearby: Double
        let total: Double
    }

    struct Parts: Encodable {
        let windowTitle: String?
        let fieldLabel: String?
        let textBeforeSelection: String
        let textAfterSelection: String
        let nearbyText: String
    }

    struct Nearby: Encodable {
        let textLength: Int
        let nodesVisited: Int
        let cutoff: String?
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
    /// Absent when the nearby walk did not run.
    let nearby: Nearby?
    /// Whether this run asked an Electron app to build its tree.
    let requestedManualAccessibility: Bool
    let screenshot: Screenshot
    let parts: Parts
    /// The exact `<app_context>` block sent to the LLM. Absent when nothing
    /// was sent.
    let appContext: String?

    init(
        result: AccessibilityContextResult,
        decision: ContextSourcePolicy.Decision,
        screenshotTaken: Bool
    ) {
        let context: AccessibilityContext
        switch result {
        case .usable(let resolved):
            context = resolved
            usable = true
            unusableReason = nil
        case .unusable(let reason, let partial):
            context = partial
            usable = false
            unusableReason = reason.rawValue
        }
        appContext = decision.accessibilityContext
            .flatMap(PromptTemplates.appContextSection)

        app = context.appName
        bundleId = context.bundleId
        role = context.role
        subrole = context.subrole
        mode = context.mode.rawValue
        timingsMs = Timings(
            focusedElement: context.timings.focusedElement,
            metadata: context.timings.metadata,
            excerpt: context.timings.excerpt,
            nearby: context.timings.nearby,
            total: context.timings.total
        )
        nearby = context.nearbyWalk.map { walk in
            Nearby(
                textLength: context.nearbyText.count,
                nodesVisited: walk.nodesVisited,
                cutoff: walk.cutoff?.rawValue
            )
        }
        requestedManualAccessibility = context.requestedManualAccessibility
        screenshot = Screenshot(
            taken: screenshotTaken,
            reason: decision.screenshotReason.rawValue
        )
        parts = Parts(
            windowTitle: context.windowTitle,
            fieldLabel: context.fieldLabel,
            textBeforeSelection: context.textBeforeSelection,
            textAfterSelection: context.textAfterSelection,
            nearbyText: context.nearbyText
        )
    }
}
