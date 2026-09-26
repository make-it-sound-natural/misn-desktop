import ApplicationServices
import Carbon

/// Failure of a single Accessibility read, reduced to what the context
/// capturer acts on.
enum AXReadError: Error, Equatable {
    /// Accessibility is off for this process (`kAXErrorAPIDisabled`).
    case apiDisabled
    /// The target app did not answer within the messaging timeout.
    case timeout
    /// The attribute is missing, unsupported or of an unexpected type.
    case unavailable
}

/// Seam over `AXUIElementCopy*` so the context capture logic can run
/// against a fake element tree in tests.
protocol AXElementReading {
    associatedtype Element

    func isProcessTrusted() -> Bool
    func isSecureEventInputEnabled() -> Bool
    func applicationElement(processID: pid_t) -> Element
    func setMessagingTimeout(_ seconds: Float, for element: Element)
    func element(
        _ attribute: String,
        of element: Element
    ) -> Result<Element, AXReadError>
    func string(
        _ attribute: String,
        of element: Element
    ) -> Result<String, AXReadError>
    func integer(
        _ attribute: String,
        of element: Element
    ) -> Result<Int, AXReadError>
    func range(
        _ attribute: String,
        of element: Element
    ) -> Result<CFRange, AXReadError>
    /// Reads `kAXStringForRangeParameterizedAttribute`; `range` is in UTF-16
    /// code units.
    func string(
        for range: CFRange,
        of element: Element
    ) -> Result<String, AXReadError>
}

struct LiveAXElementReader: AXElementReading {
    func isProcessTrusted() -> Bool {
        // Never the prompting variant: context capture must stay silent.
        AXIsProcessTrusted()
    }

    func isSecureEventInputEnabled() -> Bool {
        IsSecureEventInputEnabled()
    }

    func applicationElement(processID: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(processID)
    }

    func setMessagingTimeout(_ seconds: Float, for element: AXUIElement) {
        AXUIElementSetMessagingTimeout(element, seconds)
    }

    func element(
        _ attribute: String,
        of element: AXUIElement
    ) -> Result<AXUIElement, AXReadError> {
        copyValue(attribute, of: element).flatMap { value in
            guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
                return .failure(.unavailable)
            }
            return .success(unsafeBitCast(value, to: AXUIElement.self))
        }
    }

    func string(
        _ attribute: String,
        of element: AXUIElement
    ) -> Result<String, AXReadError> {
        copyValue(attribute, of: element).flatMap { value in
            guard let string = value as? String else {
                return .failure(.unavailable)
            }
            return .success(string)
        }
    }

    func integer(
        _ attribute: String,
        of element: AXUIElement
    ) -> Result<Int, AXReadError> {
        copyValue(attribute, of: element).flatMap { value in
            guard let number = value as? NSNumber else {
                return .failure(.unavailable)
            }
            return .success(number.intValue)
        }
    }

    func range(
        _ attribute: String,
        of element: AXUIElement
    ) -> Result<CFRange, AXReadError> {
        copyValue(attribute, of: element).flatMap { value in
            guard CFGetTypeID(value) == AXValueGetTypeID() else {
                return .failure(.unavailable)
            }
            let axValue = unsafeBitCast(value, to: AXValue.self)
            var range = CFRange()
            guard AXValueGetType(axValue) == .cfRange,
                  AXValueGetValue(axValue, .cfRange, &range) else {
                return .failure(.unavailable)
            }
            return .success(range)
        }
    }

    func string(
        for range: CFRange,
        of element: AXUIElement
    ) -> Result<String, AXReadError> {
        var cfRange = range
        guard let parameter = AXValueCreate(.cfRange, &cfRange) else {
            return .failure(.unavailable)
        }
        var value: CFTypeRef?
        let error = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            parameter,
            &value
        )
        return Self.result(error, value).flatMap { value in
            guard let string = value as? String else {
                return .failure(.unavailable)
            }
            return .success(string)
        }
    }

    private func copyValue(
        _ attribute: String,
        of element: AXUIElement
    ) -> Result<CFTypeRef, AXReadError> {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        )
        return Self.result(error, value)
    }

    private static func result(
        _ error: AXError,
        _ value: CFTypeRef?
    ) -> Result<CFTypeRef, AXReadError> {
        switch error {
        case .success:
            guard let value = value else { return .failure(.unavailable) }
            return .success(value)
        case .apiDisabled:
            return .failure(.apiDisabled)
        case .cannotComplete:
            // What a messaging timeout or an unresponsive app reports.
            return .failure(.timeout)
        default:
            return .failure(.unavailable)
        }
    }
}
