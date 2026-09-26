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
        case codeEditor
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
    }

    /// Wall-clock time of each capture step, in milliseconds.
    struct Timings: Equatable {
        var focusedElement: Double = 0
        var metadata: Double = 0
        var excerpt: Double = 0
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
    var textBeforeSelection = ""
    var textAfterSelection = ""
    /// Text shown near the field; stays empty until nearby capture exists.
    var nearbyText = ""
    var timings = Timings()

    init(mode: AccessibilityContextMode, appName: String?, bundleId: String?) {
        self.mode = mode
        self.appName = appName
        self.bundleId = bundleId
    }
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
        guard hasSurroundingText || !context.nearbyText.isEmpty else {
            return .unusable(.noSurroundingText, partial: context)
        }
        guard !Self.isMostlyPlaceholder(surrounding) else {
            return .unusable(.mostlyPlaceholderText, partial: context)
        }

        var resolved = context
        resolved.textBeforeSelection = Self.withoutPlaceholders(parts.before)
        resolved.textAfterSelection = Self.withoutPlaceholders(parts.after)
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
