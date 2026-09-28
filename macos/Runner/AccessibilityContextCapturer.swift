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
    /// calls, so run it off the main thread. `deadline` is the uptime at
    /// which the shortcut stops waiting; the nearby walk ends before it and
    /// keeps what it found.
    func capture(
        _ request: AccessibilityContextRequest,
        until deadline: TimeInterval
    ) -> AccessibilityContextCapture
}

enum AccessibilityContextLimits {
    /// Per element, so a hung app costs 100 ms instead of the ~6 s default.
    static let messagingTimeout: Float = 0.1
    /// How long the shortcut waits for the read, counted from the moment it
    /// started before Cmd+C. The copy itself takes at least 50 ms, so most
    /// of this is already spent by the time the clipboard arrives.
    static let captureDeadline: TimeInterval = 0.3
    /// Left between the end of the nearby walk and the capture deadline. One
    /// walk step makes several AX calls, so the walk can overrun its own
    /// deadline by that much.
    static let nearbyDeadlineMargin: TimeInterval = 0.05
    /// Text caps are in UTF-16 units.
    static let windowTitleLength = 200
    static let fieldLabelLength = 200
    static let textBeforeSelectionLength = 1_500
    static let textAfterSelectionLength = 500
    /// A field whose range cannot be used is read whole up to this length. A
    /// chat composer fits; a document or a terminal buffer does not.
    static let wholeValueLength = 5_000
}

final class AccessibilityContextCapturer<Reader: AXElementReading>:
    AccessibilityContextCapturing {
    // Named in the typed throws of the private extension below.
    fileprivate typealias Reason = AccessibilityContext.UnusableReason
    private typealias Limits = AccessibilityContextLimits

    private let reader: Reader
    private let now: () -> TimeInterval
    private let nearbyText: NearbyTextCollector<Reader>
    private let electronAccessibility: ElectronAccessibilityEnabler<Reader>

    init(
        reader: Reader,
        isElectronApp: @escaping (URL) -> Bool = ElectronAppDetector.isElectronApp,
        now: @escaping () -> TimeInterval = {
            ProcessInfo.processInfo.systemUptime
        }
    ) {
        self.reader = reader
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
        _ request: AccessibilityContextRequest,
        until deadline: TimeInterval
    ) -> AccessibilityContextCapture {
        let start = now()
        var context = AccessibilityContext(
            mode: request.mode,
            appName: request.appName,
            bundleId: request.bundleId
        )
        let field: AccessibilityContextCapture.Field
        do throws(Reason) {
            field = .excerpt(try readField(
                request,
                nearbyDeadline: deadline - Limits.nearbyDeadlineMargin,
                into: &context
            ))
        } catch {
            field = .unusable(error)
            // The nearby walk may already have asked, before a range error.
            if electronAccessibility.enableIfNeeded(after: error, in: request) {
                context.requestedManualAccessibility = true
            }
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
        nearbyDeadline: TimeInterval,
        into context: inout AccessibilityContext
    ) throws(Reason) -> AccessibilityFieldExcerpt {
        guard request.mode != .off else { throw Reason.disabled }
        guard reader.isProcessTrusted() else { throw Reason.notTrusted }
        guard !reader.isSecureEventInputEnabled() else {
            throw Reason.secureInput
        }

        var stepStart = now()
        let app = reader.applicationElement(processID: request.processID)
        let field = try focusedField(of: app, into: &context)
        context.timings.focusedElement = milliseconds(since: stepStart)

        stepStart = now()
        context.windowTitle = try windowTitle(of: app)
        context.fieldLabel = try label(of: field)
        let fieldFrame = reader.frame(of: field)
        context.fieldFrame = try? fieldFrame.get()
        context.timings.metadata = milliseconds(since: stepStart)

        stepStart = now()
        let fieldExcerpt: Result<AccessibilityFieldExcerpt, Reason>
        do throws(Reason) {
            fieldExcerpt = .success(try excerpt(of: field, into: &context))
        } catch .rangeUnavailable {
            // A composer without a range can still have a thread above it.
            fieldExcerpt = .failure(.rangeUnavailable)
        }
        context.timings.excerpt = milliseconds(since: stepStart)

        if request.mode == .fieldAndNearby {
            stepStart = now()
            (context.nearbyText, context.nearbyWalk) = nearbyText.collect(
                around: field,
                frame: fieldFrame,
                until: nearbyDeadline
            )
            context.timings.nearby = milliseconds(since: stepStart)
            if let walk = context.nearbyWalk {
                context.requestedManualAccessibility = electronAccessibility
                    .enableIfNeeded(
                        afterNearbyWalk: walk,
                        text: context.nearbyText,
                        in: request
                    )
            }
        }
        return try fieldExcerpt.get()
    }

    func focusedField(
        of app: Reader.Element,
        into context: inout AccessibilityContext
    ) throws(Reason) -> Reader.Element {
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

    func windowTitle(of app: Reader.Element) throws(Reason) -> String? {
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

    func label(of field: Reader.Element) throws(Reason) -> String? {
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

    /// Reads a bounded window around the selection. Reads `kAXValue` only
    /// when the range is unusable and the field is short: a terminal or a
    /// long document would return all of its text.
    func excerpt(
        of field: Reader.Element,
        into context: inout AccessibilityContext
    ) throws(Reason) -> AccessibilityFieldExcerpt {
        let count = try optional(
            reader.integer(kAXNumberOfCharactersAttribute, of: field)
        )
        let selection = try optional(
            reader.range(kAXSelectedTextRangeAttribute, of: field)
        )
        context.fieldCharacterCount = count
        context.fieldSelection = selection.map {
            NSRange(location: $0.location, length: $0.length)
        }
        if let count = count, let selection = selection,
           let excerpt = try windowExcerpt(
            of: field,
            count: count,
            selection: selection
           ) {
            return excerpt
        }
        let excerpt = try wholeValueExcerpt(of: field, count: count)
        context.fieldReadWhole = true
        return excerpt
    }

    func windowExcerpt(
        of field: Reader.Element,
        count: Int,
        selection: CFRange
    ) throws(Reason) -> AccessibilityFieldExcerpt? {
        guard selection.location >= 0, selection.length >= 0,
              selection.location + selection.length <= count else {
            return nil
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
            return nil
        }

        return AccessibilityFieldExcerpt(
            text: text,
            selection: NSRange(location: beforeLength, length: selection.length),
            startsAtFieldStart: window.location == 0,
            endsAtFieldEnd: selectionEnd + afterLength == count
        )
    }

    /// Slack's composer reports no usable range in some states. It is short,
    /// so its whole value is read and the copied text is found in it later.
    func wholeValueExcerpt(
        of field: Reader.Element,
        count: Int?
    ) throws(Reason) -> AccessibilityFieldExcerpt {
        guard count.map({ $0 <= Limits.wholeValueLength }) ?? true,
              let value = try optional(
                reader.string(kAXValueAttribute, of: field)
              ),
              value.utf16.count <= Limits.wholeValueLength else {
            throw Reason.rangeUnavailable
        }
        return AccessibilityFieldExcerpt(
            text: value,
            selection: nil,
            startsAtFieldStart: true,
            endsAtFieldEnd: true
        )
    }

    func touch(_ element: Reader.Element) {
        reader.setMessagingTimeout(Limits.messagingTimeout, for: element)
    }

    /// A missing attribute reads as nil; a disabled API or a hung app stops
    /// the capture.
    func optional<Value>(
        _ result: Result<Value, AXReadError>
    ) throws(Reason) -> Value? {
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
        // A single Character over the cap leaves nothing.
        let capped = text.prefix(utf16Limit: limit)
        return capped.isEmpty ? nil : capped
    }

    func milliseconds(since start: TimeInterval) -> Double {
        (now() - start) * 1_000
    }
}
