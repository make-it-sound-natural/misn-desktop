import ApplicationServices
import Foundation

/// The app the shortcut fired in, taken when the shortcut starts.
struct AccessibilityContextRequest {
    let mode: AccessibilityContextMode
    let processID: pid_t
    let appName: String?
    let bundleId: String?
    /// Where the app is installed; tells Electron apps apart.
    let bundleURL: URL?
}

protocol AccessibilityContextCapturing {
    /// Reads the focused field before Cmd+C. Makes blocking cross-process AX
    /// calls, so run it off the main thread.
    func capture(
        _ request: AccessibilityContextRequest
    ) -> AccessibilityContextCapture
}

enum AccessibilityContextLimits {
    /// Per element, so a hung app costs 100 ms instead of the ~6 s default.
    static let messagingTimeout: Float = 0.1
    /// How long the shortcut waits for the read, counted from the moment it
    /// started before Cmd+C. The copy itself takes at least 50 ms, so most
    /// of this is already spent by the time the clipboard arrives.
    static let captureDeadline: TimeInterval = 0.3
    static let windowTitleLength = 200
    static let fieldLabelLength = 200
    static let textBeforeSelectionLength = 1_500
    static let textAfterSelectionLength = 500
}

final class AccessibilityContextCapturer<Reader: AXElementReading>:
    AccessibilityContextCapturing {
    private typealias Reason = AccessibilityContext.UnusableReason
    private typealias Limits = AccessibilityContextLimits

    private let reader: Reader
    private let codeEditors: Set<String>
    private let now: () -> TimeInterval
    private let nearbyText: NearbyTextCollector<Reader>
    private let electronAccessibility: ElectronAccessibilityEnabler<Reader>

    init(
        reader: Reader,
        codeEditors: Set<String> = AccessibilityHelper.knownCodeEditors,
        isElectronApp: @escaping (URL) -> Bool = ElectronAppDetector.isElectronApp,
        now: @escaping () -> TimeInterval = {
            ProcessInfo.processInfo.systemUptime
        }
    ) {
        self.reader = reader
        self.codeEditors = codeEditors
        self.now = now
        self.nearbyText = NearbyTextCollector(
            reader: reader,
            messagingTimeout: Limits.messagingTimeout,
            now: now
        )
        self.electronAccessibility = ElectronAccessibilityEnabler(
            reader: reader,
            messagingTimeout: Limits.messagingTimeout,
            isElectronApp: isElectronApp
        )
    }

    func capture(
        _ request: AccessibilityContextRequest
    ) -> AccessibilityContextCapture {
        let start = now()
        var context = AccessibilityContext(
            mode: request.mode,
            appName: request.appName,
            bundleId: request.bundleId
        )
        let field: AccessibilityContextCapture.Field
        do {
            field = .excerpt(try readField(request, into: &context))
        } catch {
            // readField throws nothing but UnusableReason.
            let reason = error as? Reason ?? .noFocusedElement
            field = .unusable(reason)
            context.requestedManualAccessibility = electronAccessibility
                .enableIfNeeded(after: reason, in: request)
        }
        context.timings.total = milliseconds(since: start)
        return AccessibilityContextCapture(context: context, field: field)
    }
}

extension AccessibilityContextCapturer where Reader == LiveAXElementReader {
    convenience init() {
        self.init(reader: LiveAXElementReader())
    }
}

private extension AccessibilityContextCapturer {
    func readField(
        _ request: AccessibilityContextRequest,
        into context: inout AccessibilityContext
    ) throws -> AccessibilityFieldExcerpt {
        guard request.mode != .off else { throw Reason.disabled }
        guard reader.isProcessTrusted() else { throw Reason.notTrusted }
        guard !reader.isSecureEventInputEnabled() else {
            throw Reason.secureInput
        }
        if let bundleId = request.bundleId, codeEditors.contains(bundleId) {
            throw Reason.codeEditor
        }

        var stepStart = now()
        let app = reader.applicationElement(processID: request.processID)
        let field = try focusedField(of: app, into: &context)
        context.timings.focusedElement = milliseconds(since: stepStart)

        stepStart = now()
        context.windowTitle = try windowTitle(of: app)
        context.fieldLabel = try label(of: field)
        context.timings.metadata = milliseconds(since: stepStart)

        stepStart = now()
        let fieldExcerpt: AccessibilityFieldExcerpt
        do {
            defer { context.timings.excerpt = milliseconds(since: stepStart) }
            fieldExcerpt = try excerpt(of: field)
        }

        if request.mode == .fieldAndNearby {
            stepStart = now()
            (context.nearbyText, context.nearbyWalk) = nearbyText.collect(
                around: field
            )
            context.timings.nearby = milliseconds(since: stepStart)
        }
        return fieldExcerpt
    }

    func focusedField(
        of app: Reader.Element,
        into context: inout AccessibilityContext
    ) throws -> Reader.Element {
        touch(app)
        guard let field = try optional(
            reader.element(kAXFocusedUIElementAttribute, of: app)
        ) else {
            throw Reason.noFocusedElement
        }
        touch(field)

        context.role = try optional(reader.string(kAXRoleAttribute, of: field))
        context.subrole = try optional(
            reader.string(kAXSubroleAttribute, of: field)
        )
        let roles = [context.role, context.subrole]
        if roles.contains(kAXSecureTextFieldSubrole) {
            throw Reason.secureField
        }
        if roles.contains(kAXWindowRole) || roles.contains(kAXApplicationRole) {
            throw Reason.windowOrApplicationRole
        }
        return field
    }

    func windowTitle(of app: Reader.Element) throws -> String? {
        guard let window = try optional(
            reader.element(kAXFocusedWindowAttribute, of: app)
        ) else {
            return nil
        }
        touch(window)
        return clipped(
            try optional(reader.string(kAXTitleAttribute, of: window)),
            to: Limits.windowTitleLength
        )
    }

    func label(of field: Reader.Element) throws -> String? {
        let attributes = [
            kAXPlaceholderValueAttribute,
            kAXDescriptionAttribute,
            kAXTitleAttribute
        ]
        for attribute in attributes {
            if let label = clipped(
                try optional(reader.string(attribute, of: field)),
                to: Limits.fieldLabelLength
            ) {
                return label
            }
        }
        guard let titleElement = try optional(
            reader.element(kAXTitleUIElementAttribute, of: field)
        ) else {
            return nil
        }
        touch(titleElement)
        // A linked label is static text, so its value is short and safe to
        // read, unlike the field's own value.
        for attribute in [kAXValueAttribute, kAXTitleAttribute] {
            if let label = clipped(
                try optional(reader.string(attribute, of: titleElement)),
                to: Limits.fieldLabelLength
            ) {
                return label
            }
        }
        return nil
    }

    /// Reads a bounded window around the selection. Never reads `kAXValue`:
    /// a terminal or a long document would return all of its text.
    func excerpt(of field: Reader.Element) throws -> AccessibilityFieldExcerpt {
        guard let count = try optional(
                reader.integer(kAXNumberOfCharactersAttribute, of: field)
              ),
              let selection = try optional(
                reader.range(kAXSelectedTextRangeAttribute, of: field)
              ),
              selection.location >= 0, selection.length >= 0,
              selection.location + selection.length <= count else {
            throw Reason.rangeUnavailable
        }

        let selectionEnd = selection.location + selection.length
        let beforeLength = min(
            selection.location,
            Limits.textBeforeSelectionLength
        )
        let afterLength = min(
            count - selectionEnd,
            Limits.textAfterSelectionLength
        )
        let window = CFRange(
            location: selection.location - beforeLength,
            length: beforeLength + selection.length + afterLength
        )
        guard let text = try optional(reader.string(for: window, of: field))
        else {
            throw Reason.rangeUnavailable
        }

        return AccessibilityFieldExcerpt(
            text: text,
            selection: NSRange(location: beforeLength, length: selection.length),
            startsAtFieldStart: window.location == 0,
            endsAtFieldEnd: selectionEnd + afterLength == count
        )
    }

    func touch(_ element: Reader.Element) {
        reader.setMessagingTimeout(Limits.messagingTimeout, for: element)
    }

    /// A missing attribute reads as nil; a disabled API or a hung app stops
    /// the capture.
    func optional<Value>(
        _ result: Result<Value, AXReadError>
    ) throws -> Value? {
        switch result {
        case .success(let value):
            return value
        case .failure(.unavailable):
            return nil
        case .failure(.apiDisabled):
            throw Reason.apiDisabled
        case .failure(.timeout):
            throw Reason.timeout
        }
    }

    func clipped(_ text: String?, to limit: Int) -> String? {
        guard let text = text?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !text.isEmpty else {
            return nil
        }
        return String(text.prefix(limit))
    }

    func milliseconds(since start: TimeInterval) -> Double {
        (now() - start) * 1_000
    }
}
