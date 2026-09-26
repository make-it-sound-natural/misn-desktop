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
    /// Hashable so a tree walk can tell elements apart; `AXUIElement`
    /// compares with `CFEqual`.
    associatedtype Element: Hashable

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
    /// Reads at most the last `maxCount` children, so a huge list costs no
    /// more than the walk can use.
    func lastChildren(
        _ maxCount: Int,
        of element: Element
    ) -> Result<[Element], AXReadError>
    /// Position and size in screen coordinates, origin at the top left.
    func frame(of element: Element) -> Result<CGRect, AXReadError>
    /// The one write: `AXManualAccessibility` on an Electron app element.
    func setBoolean(
        _ value: Bool,
        _ attribute: String,
        of element: Element
    ) -> Result<Void, AXReadError>
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
        axValue(attribute, .cfRange, of: element).flatMap { value in
            var range = CFRange()
            return AXValueGetValue(value, .cfRange, &range)
                ? .success(range)
                : .failure(.unavailable)
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

    func lastChildren(
        _ maxCount: Int,
        of element: AXUIElement
    ) -> Result<[AXUIElement], AXReadError> {
        var count: CFIndex = 0
        let countError = AXUIElementGetAttributeValueCount(
            element,
            kAXChildrenAttribute as CFString,
            &count
        )
        guard countError == .success else {
            return .failure(Self.readError(countError))
        }
        let length = min(count, maxCount)
        guard length > 0 else { return .success([]) }
        var values: CFArray?
        let error = AXUIElementCopyAttributeValues(
            element,
            kAXChildrenAttribute as CFString,
            count - length,
            length,
            &values
        )
        return Self.result(error, values).flatMap { values in
            guard let children = values as? [AXUIElement] else {
                return .failure(.unavailable)
            }
            return .success(children)
        }
    }

    func frame(of element: AXUIElement) -> Result<CGRect, AXReadError> {
        axValue(kAXPositionAttribute, .cgPoint, of: element).flatMap { position in
            axValue(kAXSizeAttribute, .cgSize, of: element).flatMap { size in
                var origin = CGPoint.zero
                var extent = CGSize.zero
                guard AXValueGetValue(position, .cgPoint, &origin),
                      AXValueGetValue(size, .cgSize, &extent) else {
                    return .failure(.unavailable)
                }
                return .success(CGRect(origin: origin, size: extent))
            }
        }
    }

    func setBoolean(
        _ value: Bool,
        _ attribute: String,
        of element: AXUIElement
    ) -> Result<Void, AXReadError> {
        let error = AXUIElementSetAttributeValue(
            element,
            attribute as CFString,
            (value ? kCFBooleanTrue : kCFBooleanFalse) as CFTypeRef
        )
        guard error == .success else {
            return .failure(Self.readError(error))
        }
        return .success(())
    }

    /// Copies an `AXValue` attribute holding `type`; the caller unpacks it
    /// into the matching concrete struct.
    private func axValue(
        _ attribute: String,
        _ type: AXValueType,
        of element: AXUIElement
    ) -> Result<AXValue, AXReadError> {
        copyValue(attribute, of: element).flatMap { value in
            guard CFGetTypeID(value) == AXValueGetTypeID() else {
                return .failure(.unavailable)
            }
            let axValue = unsafeBitCast(value, to: AXValue.self)
            guard AXValueGetType(axValue) == type else {
                return .failure(.unavailable)
            }
            return .success(axValue)
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
        guard error == .success else { return .failure(readError(error)) }
        guard let value = value else { return .failure(.unavailable) }
        return .success(value)
    }

    private static func readError(_ error: AXError) -> AXReadError {
        switch error {
        case .apiDisabled:
            return .apiDisabled
        case .cannotComplete:
            // What a messaging timeout or an unresponsive app reports.
            return .timeout
        default:
            return .unavailable
        }
    }
}
