import Foundation

/// Text read through the Accessibility API from the app where the user is
/// typing. It goes to the LLM as reference data next to the selected text.
struct AccessibilityContext: Equatable {
    /// Why an Accessibility read cannot serve as context. The shortcut then
    /// falls back to the screenshot, when that is enabled.
    enum UnusableReason: String, Error, Equatable {
        case disabled
        case notTrusted
        /// A password field is focused somewhere (`IsSecureEventInputEnabled`).
        case secureInput
        case secureField
        case noFocusedElement
        case apiDisabled
        case timeout
        case windowOrApplicationRole
        /// The field exposes no usable selection range or character count.
        case rangeUnavailable
        /// The copied text is not in the excerpt: focus moved, or AX
        /// reported another element.
        case selectionMismatch
        /// The excerpt is only the selection and there is no nearby text.
        case noSurroundingText
        /// The text around the selection is mostly U+FFFC or whitespace.
        case mostlyPlaceholderText

        /// The field text is unusable, but the read reached the right field:
        /// its app, window, label and any nearby text are still worth
        /// sending.
        var keepsPartialContext: Bool {
            switch self {
            case .noSurroundingText, .mostlyPlaceholderText, .rangeUnavailable:
                return true
            case .disabled, .notTrusted, .secureInput, .secureField,
                 .noFocusedElement, .apiDisabled, .timeout,
                 .windowOrApplicationRole, .selectionMismatch:
                return false
            }
        }
    }

    /// Wall-clock time of each capture step, in milliseconds.
    struct Timings: Equatable {
        var focusedElement: Double = 0
        var metadata: Double = 0
        var excerpt: Double = 0
        var nearby: Double = 0
        var total: Double = 0
    }

    let mode: AccessibilityContextMode
    let appName: String?
    let bundleId: String?
    var role: String?
    var subrole: String?
    var windowTitle: String?
    /// Placeholder, description, title or linked title element of the field.
    var fieldLabel: String?
    /// Screen coordinates, origin at the top left. Crops the screenshot to
    /// the part of the window the field belongs to.
    var fieldFrame: CGRect?
    /// What the field reported, for the debug saver: why a range was
    /// unusable is otherwise invisible.
    var fieldCharacterCount: Int?
    var fieldSelection: NSRange?
    /// The range was unusable, so the field's whole value was read.
    var fieldReadWhole = false
    var textBeforeSelection = ""
    var textAfterSelection = ""
    /// Text shown above the field, `fieldAndNearby` mode only.
    var nearbyText = ""
    /// How the nearby text walk went; nil when it did not run.
    var nearbyWalk: NearbyTextWalk?
    /// Whether this run asked an Electron app to build its Accessibility
    /// tree (`AXManualAccessibility`).
    var requestedManualAccessibility = false
    var timings = Timings()

    init(mode: AccessibilityContextMode, appName: String?, bundleId: String?) {
        self.mode = mode
        self.appName = appName
        self.bundleId = bundleId
    }
}

/// How a nearby text walk went, for the debug saver and logs.
struct NearbyTextWalk: Equatable {
    /// What stopped the walk before it found enough text or reached the
    /// window.
    enum Cutoff: String, Equatable {
        case nodeBudget
        case deadline
        /// The target app stopped answering or the API was disabled.
        case readFailed
        /// More text was found than fits; the farthest was dropped.
        case textLength
        /// The field reports no frame, so nothing can be placed above it.
        case noFieldFrame
    }

    var nodesVisited = 0
    var cutoff: Cutoff?
}

enum AccessibilityContextResult: Equatable {
    case usable(AccessibilityContext)
    /// `partial` keeps whatever was read before the capture gave up (app,
    /// window title, field label, timings) but no field text.
    case unusable(
        AccessibilityContext.UnusableReason,
        partial: AccessibilityContext
    )
}

/// An Accessibility read taken before Cmd+C, while the copied text is not
/// known yet. `resolve(copiedText:)` validates it once the clipboard arrives.
struct AccessibilityContextCapture: Equatable {
    enum Field: Equatable {
        case unusable(AccessibilityContext.UnusableReason)
        case excerpt(AccessibilityFieldExcerpt)
    }

    let context: AccessibilityContext
    let field: Field

    func resolve(copiedText: String) -> AccessibilityContextResult {
        switch field {
        case .unusable(let reason):
            return .unusable(reason, partial: context)
        case .excerpt(let excerpt):
            return resolve(excerpt, copiedText: copiedText)
        }
    }

    private func resolve(
        _ excerpt: AccessibilityFieldExcerpt,
        copiedText: String
    ) -> AccessibilityContextResult {
        guard let parts = excerpt.split(around: copiedText) else {
            return .unusable(.selectionMismatch, partial: context)
        }
        let surrounding = parts.before + parts.after
        let hasSurroundingText = !surrounding
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        let fieldTextUsable = hasSurroundingText
            && !Self.isMostlyPlaceholder(surrounding)
        // Nearby text is worth sending on its own, so field text that is
        // only a trailing newline or embeds does not discard it.
        guard fieldTextUsable || !context.nearbyText.isEmpty else {
            return .unusable(
                hasSurroundingText ? .mostlyPlaceholderText : .noSurroundingText,
                partial: context
            )
        }

        var resolved = context
        if fieldTextUsable {
            resolved.textBeforeSelection = Self.withoutPlaceholders(parts.before)
            resolved.textAfterSelection = Self.withoutPlaceholders(parts.after)
        }
        return .usable(resolved)
    }

    private static let objectReplacement: Unicode.Scalar = "\u{FFFC}"

    /// Rich text editors expose attachments and embeds as U+FFFC.
    private static func isMostlyPlaceholder(_ text: String) -> Bool {
        let scalars = text.unicodeScalars
        let placeholders = scalars.filter { scalar in
            scalar == objectReplacement || scalar.properties.isWhitespace
        }
        return placeholders.count * 2 > scalars.count
    }

    private static func withoutPlaceholders(_ text: String) -> String {
        text.replacingOccurrences(of: String(objectReplacement), with: "")
    }
}

/// Caps for text read from other apps count UTF-16 code units, the unit AX
/// ranges use. A Character can carry any number of combining marks, so a
/// cap in Characters bounds nothing.
extension String {
    /// A cut edge drops the word it went through, but no more than this: text
    /// without spaces (CJK) would otherwise lose everything up to a newline.
    static let partialWordLengthLimit = 40

    /// The longest prefix of whole Characters within `limit` UTF-16 units.
    func prefix(utf16Limit limit: Int) -> String {
        guard utf16.count > limit else { return self }
        var used = 0
        var end = startIndex
        for index in indices {
            used += self[index].utf16.count
            guard used <= limit else { break }
            end = self.index(after: index)
        }
        return String(self[..<end])
    }

    /// The longest suffix of whole Characters within `limit` UTF-16 units.
    func suffix(utf16Limit limit: Int) -> String {
        guard utf16.count > limit else { return self }
        var used = 0
        var start = endIndex
        for index in indices.reversed() {
            used += self[index].utf16.count
            guard used <= limit else { break }
            start = index
        }
        return String(self[start...])
    }

    /// Drops the partial word before the first whitespace, when it is short
    /// enough to be one.
    func droppingFirstPartialWord() -> String {
        guard let cut = prefix(Self.partialWordLengthLimit + 1)
            .firstIndex(where: { $0.isWhitespace }) else {
            return self
        }
        return String(self[index(after: cut)...])
    }

    /// Drops the partial word after the last whitespace, when it is short
    /// enough to be one.
    func droppingLastPartialWord() -> String {
        guard let cut = suffix(Self.partialWordLengthLimit + 1)
            .lastIndex(where: { $0.isWhitespace }) else {
            return self
        }
        return String(self[..<cut])
    }

    /// Without invisible format characters (Unicode Cf), such as the tag
    /// characters that can hide instructions from a reader. Keeps the zero
    /// width joiner and non-joiner, which emoji and some scripts need.
    var withoutFormatCharacters: String {
        let kept = unicodeScalars.filter { scalar in
            scalar.properties.generalCategory != .format
                || scalar == "\u{200C}" || scalar == "\u{200D}"
        }
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: kept)
        return String(scalars)
    }
}
