import Foundation

/// Electron apps (Slack, Discord, Notion, …) build no Accessibility tree
/// until a client sets `AXManualAccessibility` on the app element. The tree
/// then builds asynchronously and stays on until the app quits, so this is
/// done once per process, after a read found nothing usable there or a
/// nearby walk found an empty tree. That run still falls back to the
/// screenshot; later runs get the tree.
///
/// Never sets `AXEnhancedUserInterface`: it breaks window animations and
/// window managers.
final class ElectronAccessibilityEnabler<Reader: AXElementReading> {
    static var attribute: String { "AXManualAccessibility" }

    /// A nearby walk that covered fewer nodes than this and kept no text
    /// found a tree that is off. Slack exposes its composer even then, and
    /// the walk around it visits 2 nodes; with the tree on it visits
    /// hundreds.
    static var emptyWalkNodeLimit: Int { 10 }

    private let reader: Reader
    private let messagingTimeout: Float
    private let isElectronApp: (URL) -> Bool
    private let lock = NSLock()
    private var attemptedProcessIDs: Set<pid_t> = []

    init(
        reader: Reader,
        messagingTimeout: Float,
        isElectronApp: @escaping (URL) -> Bool = ElectronAppDetector.isElectronApp
    ) {
        self.reader = reader
        self.messagingTimeout = messagingTimeout
        self.isElectronApp = isElectronApp
    }

    /// Returns whether this call set the attribute.
    func enableIfNeeded(
        after reason: AccessibilityContext.UnusableReason,
        in request: AccessibilityContextRequest
    ) -> Bool {
        Self.treeMayBeOff(reason) && enable(in: request)
    }

    /// Returns whether this call set the attribute.
    func enableIfNeeded(
        afterNearbyWalk walk: NearbyTextWalk,
        text: String,
        in request: AccessibilityContextRequest
    ) -> Bool {
        Self.treeMayBeOff(walk, text: text) && enable(in: request)
    }

    private func enable(in request: AccessibilityContextRequest) -> Bool {
        guard let bundleURL = request.bundleURL,
              isElectronApp(bundleURL),
              markAttempted(request.processID) else {
            return false
        }
        let app = reader.applicationElement(processID: request.processID)
        reader.setMessagingTimeout(messagingTimeout, for: app)
        return (try? reader.setBoolean(true, Self.attribute, of: app).get())
            != nil
    }

    /// What an Electron app with its tree off looks like. The guards that
    /// stop before reading anything (off, not trusted, secure input, code
    /// editor) and a hung app say nothing about the tree.
    private static func treeMayBeOff(
        _ reason: AccessibilityContext.UnusableReason
    ) -> Bool {
        switch reason {
        case .noFocusedElement, .windowOrApplicationRole, .rangeUnavailable:
            return true
        default:
            return false
        }
    }

    /// A walk that was cut short did not see the whole tree, so its size
    /// says nothing.
    private static func treeMayBeOff(
        _ walk: NearbyTextWalk,
        text: String
    ) -> Bool {
        walk.cutoff == nil && text.isEmpty
            && walk.nodesVisited < emptyWalkNodeLimit
    }

    /// Once per pid whatever the outcome, so an app that rejects the
    /// attribute is not asked on every shortcut.
    private func markAttempted(_ processID: pid_t) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return attemptedProcessIDs.insert(processID).inserted
    }
}

enum ElectronAppDetector {
    static func isElectronApp(_ bundleURL: URL) -> Bool {
        let framework = bundleURL.appendingPathComponent(
            "Contents/Frameworks/Electron Framework.framework"
        )
        return FileManager.default.fileExists(atPath: framework.path)
    }
}
