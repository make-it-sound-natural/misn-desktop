import ApplicationServices
import XCTest
@testable import Make_It_Sound_Natural

/// One element of the fake AX tree. Compares by identity, like distinct
/// `AXUIElement`s.
final class FakeAXNode: Hashable {
    let name: String
    var strings: [String: String] = [:]
    var elements: [String: FakeAXNode] = [:]
    var integers: [String: Int] = [:]
    var ranges: [String: CFRange] = [:]
    var errors: [String: AXReadError] = [:]
    /// Read as `kAXChildrenAttribute`; errors under that key too.
    private(set) var children: [FakeAXNode] = []
    /// Read as `kAXParentAttribute`; weak so a tree does not leak.
    private(set) weak var parent: FakeAXNode?
    /// Read by `frame(of:)`; errors under `kAXPositionAttribute`.
    var frame: CGRect?
    /// Backs `kAXStringForRangeParameterizedAttribute`.
    var text: String?
    /// Simulates apps whose returned text drifts from the reported offsets.
    var textForRangeOverride: String?

    init(_ name: String, role: String? = nil, frame: CGRect? = nil) {
        self.name = name
        self.frame = frame
        strings[kAXRoleAttribute] = role
    }

    static func == (lhs: FakeAXNode, rhs: FakeAXNode) -> Bool { lhs === rhs }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    /// Appends `nodes` as children, in on-screen order.
    @discardableResult
    func add(_ nodes: FakeAXNode...) -> FakeAXNode {
        for node in nodes {
            node.parent = self
            children.append(node)
        }
        return self
    }

    /// A text area whose value and selection are given in UTF-16 offsets.
    static func textArea(_ value: String, selection: NSRange) -> FakeAXNode {
        let node = FakeAXNode("field", role: kAXTextAreaRole)
        node.text = value
        node.strings[kAXValueAttribute] = value
        node.integers[kAXNumberOfCharactersAttribute] = value.utf16.count
        node.ranges[kAXSelectedTextRangeAttribute] = CFRange(
            location: selection.location,
            length: selection.length
        )
        return node
    }
}

final class FakeAXReader: AXElementReading {
    var trusted = true
    var secureInput = false
    let app = FakeAXNode("app", role: kAXApplicationRole)
    private(set) var reads: [(node: String, attribute: String)] = []
    private(set) var rangeReads: [CFRange] = []
    private(set) var timeouts: [String: Float] = [:]
    private(set) var childrenRequests: [Int] = []
    private(set) var writes: [(node: String, attribute: String, value: Bool)] = []
    private(set) var applicationProcessIDs: [pid_t] = []
    var writeError: AXReadError?

    func isProcessTrusted() -> Bool { trusted }
    func isSecureEventInputEnabled() -> Bool { secureInput }
    func applicationElement(processID: pid_t) -> FakeAXNode {
        applicationProcessIDs.append(processID)
        return app
    }

    func setMessagingTimeout(_ seconds: Float, for element: FakeAXNode) {
        timeouts[element.name] = seconds
    }

    func element(
        _ attribute: String,
        of element: FakeAXNode
    ) -> Result<FakeAXNode, AXReadError> {
        if attribute == kAXParentAttribute, let parent = element.parent {
            return read(attribute, of: element, from: [attribute: parent])
        }
        return read(attribute, of: element, from: element.elements)
    }

    func string(
        _ attribute: String,
        of element: FakeAXNode
    ) -> Result<String, AXReadError> {
        read(attribute, of: element, from: element.strings)
    }

    func integer(
        _ attribute: String,
        of element: FakeAXNode
    ) -> Result<Int, AXReadError> {
        read(attribute, of: element, from: element.integers)
    }

    func range(
        _ attribute: String,
        of element: FakeAXNode
    ) -> Result<CFRange, AXReadError> {
        read(attribute, of: element, from: element.ranges)
    }

    func string(
        for range: CFRange,
        of element: FakeAXNode
    ) -> Result<String, AXReadError> {
        rangeReads.append(range)
        let attribute = kAXStringForRangeParameterizedAttribute
        reads.append((element.name, attribute))
        if let error = element.errors[attribute] { return .failure(error) }
        if let override = element.textForRangeOverride {
            return .success(override)
        }
        guard let text = element.text else { return .failure(.unavailable) }
        let nsRange = NSRange(location: range.location, length: range.length)
        return .success((text as NSString).substring(with: nsRange))
    }

    func lastChildren(
        _ maxCount: Int,
        of element: FakeAXNode
    ) -> Result<[FakeAXNode], AXReadError> {
        childrenRequests.append(maxCount)
        return read(
            kAXChildrenAttribute,
            of: element,
            from: [kAXChildrenAttribute: Array(element.children.suffix(maxCount))]
        )
    }

    func frame(of element: FakeAXNode) -> Result<CGRect, AXReadError> {
        read(
            kAXPositionAttribute,
            of: element,
            from: element.frame.map { [kAXPositionAttribute: $0] } ?? [:]
        )
    }

    func setBoolean(
        _ value: Bool,
        _ attribute: String,
        of element: FakeAXNode
    ) -> Result<Void, AXReadError> {
        writes.append((element.name, attribute, value))
        return writeError.map { .failure($0) } ?? .success(())
    }

    func readAttributes(of node: String) -> [String] {
        reads.filter { $0.node == node }.map { $0.attribute }
    }

    private func read<Value>(
        _ attribute: String,
        of element: FakeAXNode,
        from values: [String: Value]
    ) -> Result<Value, AXReadError> {
        reads.append((element.name, attribute))
        if let error = element.errors[attribute] { return .failure(error) }
        guard let value = values[attribute] else {
            return .failure(.unavailable)
        }
        return .success(value)
    }
}

final class AccessibilityContextCapturerTests: XCTestCase {
    private var reader: FakeAXReader!
    private var window: FakeAXNode!

    override func setUp() {
        super.setUp()
        reader = FakeAXReader()
        window = FakeAXNode("window", role: kAXWindowRole)
        window.strings[kAXTitleAttribute] = "#design - AdGuard"
        reader.app.elements[kAXFocusedWindowAttribute] = window
    }

    override func tearDown() {
        reader = nil
        window = nil
        super.tearDown()
    }

    // MARK: - Mode

    func testModeParseFallsBackToOff() {
        XCTAssertEqual(AccessibilityContextMode.parse("field"), .field)
        XCTAssertEqual(
            AccessibilityContextMode.parse("fieldAndNearby"),
            .fieldAndNearby
        )
        XCTAssertEqual(AccessibilityContextMode.parse("unknown"), .off)
        XCTAssertEqual(AccessibilityContextMode.parse(nil), .off)
    }

    // MARK: - Usable field context

    func testFieldModeReadsWindowTitleLabelAndSurroundingText() {
        let field = focus("Hi team, please review this today. Thanks!", "review")
        field.strings[kAXPlaceholderValueAttribute] = "Message #design"

        let context = usableContext(copiedText: "review")

        XCTAssertEqual(context.appName, "Slack")
        XCTAssertEqual(context.bundleId, "com.tinyspeck.slackmacgap")
        XCTAssertEqual(context.role, kAXTextAreaRole)
        XCTAssertEqual(context.windowTitle, "#design - AdGuard")
        XCTAssertEqual(context.fieldLabel, "Message #design")
        XCTAssertEqual(context.textBeforeSelection, "Hi team, please ")
        XCTAssertEqual(context.textAfterSelection, " this today. Thanks!")
        XCTAssertEqual(context.nearbyText, "")
        XCTAssertEqual(context.mode, .field)
    }

    func testKnownCodeEditorIsReadLikeAnyOtherApp() {
        focus("let x = 1", "x")

        for bundleId in AccessibilityHelper.knownCodeEditors {
            let result = capture(bundleId: bundleId).resolve(copiedText: "x")

            guard case .usable(let context) = result else {
                XCTFail("\(bundleId) is unusable: \(result)")
                continue
            }
            XCTAssertEqual(context.bundleId, bundleId)
            XCTAssertEqual(context.textBeforeSelection, "let ")
            XCTAssertEqual(context.textAfterSelection, " = 1")
        }
    }

    func testSelectionAtFieldStartHasNoTextBefore() {
        focus("Hello there, how are you?", "Hello")

        let context = usableContext(copiedText: "Hello")

        XCTAssertEqual(context.textBeforeSelection, "")
        XCTAssertEqual(context.textAfterSelection, " there, how are you?")
    }

    func testSelectionAtFieldEndHasNoTextAfter() {
        focus("Hello there, how are you?", "you?")

        let context = usableContext(copiedText: "you?")

        XCTAssertEqual(context.textBeforeSelection, "Hello there, how are ")
        XCTAssertEqual(context.textAfterSelection, "")
    }

    func testEmojiOffsetsAreUTF16() {
        focus("Hi 👋🏽 there 👨‍👩‍👧 friends, see you 🚀 soon", "there 👨‍👩‍👧 friends")

        let context = usableContext(copiedText: "there 👨‍👩‍👧 friends")

        XCTAssertEqual(context.textBeforeSelection, "Hi 👋🏽 ")
        XCTAssertEqual(context.textAfterSelection, ", see you 🚀 soon")
    }

    func testHugeValueReadsOnlyBoundedRangeAndNeverValue() {
        let word = "lorem "
        let head = String(repeating: word, count: 100_000)
        let tail = String(repeating: word, count: 100_000)
        focus(head + "SELECTED" + tail, "SELECTED")

        let context = usableContext(copiedText: "SELECTED")

        XCTAssertFalse(
            reader.readAttributes(of: "field").contains(kAXValueAttribute)
        )
        XCTAssertEqual(reader.rangeReads.count, 1)
        XCTAssertEqual(
            reader.rangeReads.first?.length,
            AccessibilityContextLimits.textBeforeSelectionLength
                + "SELECTED".utf16.count
                + AccessibilityContextLimits.textAfterSelectionLength
        )
        XCTAssertLessThanOrEqual(
            context.textBeforeSelection.utf16.count,
            AccessibilityContextLimits.textBeforeSelectionLength
        )
        XCTAssertLessThanOrEqual(
            context.textAfterSelection.utf16.count,
            AccessibilityContextLimits.textAfterSelectionLength
        )
        // Trimmed to whole words at both cut edges.
        XCTAssertTrue(context.textBeforeSelection.hasPrefix("lorem "))
        XCTAssertTrue(context.textAfterSelection.hasSuffix(" lorem"))
    }

    func testWindowEdgeInsideSurrogatePairIsDropped() {
        // 1,601 UTF-16 units before the selection: the 1,500-unit window
        // starts on the low half of an emoji.
        let before = String(repeating: "😀", count: 800) + "b"
        focus(before + "X", "X")

        let context = usableContext(copiedText: "X")

        XCTAssertFalse(context.textBeforeSelection.contains("\u{FFFD}"))
        XCTAssertEqual(
            context.textBeforeSelection,
            String(repeating: "😀", count: 749) + "b"
        )
    }

    func testDriftedOffsetsFallBackToCopiedTextNearestTheSelection() {
        let field = focus("one two three two four", "three")
        // The app returns text shifted by one character from its own range.
        field.textForRangeOverride = "Xone two three two four"

        let context = usableContext(copiedText: "three")

        XCTAssertEqual(context.textBeforeSelection, "Xone two ")
        XCTAssertEqual(context.textAfterSelection, " two four")
    }

    func testObjectReplacementCharactersAreStripped() {
        focus("See \u{FFFC} the attached plan please", "plan")

        let context = usableContext(copiedText: "plan")

        XCTAssertEqual(context.textBeforeSelection, "See  the attached ")
    }

    func testLabelFallsBackToTitleUIElement() {
        let field = focus("Dear Anna, thanks", "thanks")
        let label = FakeAXNode("label", role: kAXStaticTextRole)
        label.strings[kAXValueAttribute] = "Reply to Anna"
        field.elements[kAXTitleUIElementAttribute] = label

        let context = usableContext(copiedText: "thanks")

        XCTAssertEqual(context.fieldLabel, "Reply to Anna")
    }

    func testLongWindowTitleIsClipped() {
        window.strings[kAXTitleAttribute] = String(repeating: "t", count: 500)
        focus("Hello there", "there")

        let context = usableContext(copiedText: "there")

        XCTAssertEqual(
            context.windowTitle?.count,
            AccessibilityContextLimits.windowTitleLength
        )
    }

    func testMessagingTimeoutIsSetOnEveryTouchedElement() {
        let field = focus("Dear Anna, thanks", "thanks")
        field.elements[kAXTitleUIElementAttribute] = FakeAXNode("label")

        _ = capture().resolve(copiedText: "thanks")

        let timeout = AccessibilityContextLimits.messagingTimeout
        XCTAssertEqual(
            reader.timeouts,
            ["app": timeout, "field": timeout, "window": timeout, "label": timeout]
        )
    }

    func testTimingsAreRecordedPerStep() {
        focus("Hello there", "there")
        var clock: TimeInterval = 0
        let capturer = AccessibilityContextCapturer(reader: reader) {
            clock += 0.001
            return clock
        }

        let timings = capturer.capture(request()).context.timings

        XCTAssertGreaterThan(timings.focusedElement, 0)
        XCTAssertGreaterThan(timings.metadata, 0)
        XCTAssertGreaterThan(timings.excerpt, 0)
        XCTAssertGreaterThan(timings.total, timings.excerpt)
    }

    // MARK: - Privacy guards

    func testSecureTextFieldIsNeverRead() {
        let field = focus("hunter2", "hunter2")
        field.strings[kAXRoleAttribute] = kAXTextFieldRole
        field.strings[kAXSubroleAttribute] = kAXSecureTextFieldSubrole

        let result = capture().resolve(copiedText: "hunter2")

        XCTAssertEqual(reason(of: result), .secureField)
        XCTAssertEqual(
            reader.readAttributes(of: "field"),
            [kAXRoleAttribute, kAXSubroleAttribute]
        )
        XCTAssertTrue(reader.rangeReads.isEmpty)
    }

    func testSecureEventInputSkipsAllReads() {
        focus("Hello there", "there")
        reader.secureInput = true

        let result = capture().resolve(copiedText: "there")

        XCTAssertEqual(reason(of: result), .secureInput)
        XCTAssertTrue(reader.reads.isEmpty)
    }

    func testNotTrustedSkipsAllReads() {
        focus("Hello there", "there")
        reader.trusted = false

        let result = capture().resolve(copiedText: "there")

        XCTAssertEqual(reason(of: result), .notTrusted)
        XCTAssertTrue(reader.reads.isEmpty)
    }

    func testOffModeSkipsAllReads() {
        focus("Hello there", "there")

        let result = capture(mode: .off).resolve(copiedText: "there")

        XCTAssertEqual(reason(of: result), .disabled)
        XCTAssertTrue(reader.reads.isEmpty)
    }

    // MARK: - Unusable results

    func testCopiedTextMismatchMeansFocusMoved() {
        focus("Hello there, how are you?", "there")

        let result = capture().resolve(copiedText: "something else")

        XCTAssertEqual(reason(of: result), .selectionMismatch)
        guard case .unusable(_, let partial) = result else { return }
        XCTAssertEqual(partial.windowTitle, "#design - AdGuard")
        XCTAssertEqual(partial.textBeforeSelection, "")
    }

    func testTimeoutStopsTheCapture() {
        reader.app.errors[kAXFocusedUIElementAttribute] = .timeout

        let result = capture().resolve(copiedText: "there")

        XCTAssertEqual(reason(of: result), .timeout)
        XCTAssertEqual(reader.reads.count, 1)
    }

    func testTimeoutOnRangeReadStopsTheCapture() {
        let field = focus("Hello there", "there")
        field.errors[kAXStringForRangeParameterizedAttribute] = .timeout

        let result = capture().resolve(copiedText: "there")

        XCTAssertEqual(reason(of: result), .timeout)
    }

    func testAPIDisabledIsReported() {
        reader.app.errors[kAXFocusedUIElementAttribute] = .apiDisabled

        let result = capture().resolve(copiedText: "there")

        XCTAssertEqual(reason(of: result), .apiDisabled)
    }

    func testNoFocusedElement() {
        let result = capture().resolve(copiedText: "there")

        XCTAssertEqual(reason(of: result), .noFocusedElement)
    }

    func testWindowRoleIsUnusable() {
        reader.app.elements[kAXFocusedUIElementAttribute] = window

        let result = capture().resolve(copiedText: "there")

        XCTAssertEqual(reason(of: result), .windowOrApplicationRole)
        XCTAssertTrue(reader.readAttributes(of: "window").allSatisfy {
            $0 == kAXRoleAttribute || $0 == kAXSubroleAttribute
        })
    }

    func testMissingSelectionRangeIsUnusable() {
        let field = focus("Hello there", "there")
        field.ranges[kAXSelectedTextRangeAttribute] = nil

        let result = capture().resolve(copiedText: "there")

        XCTAssertEqual(reason(of: result), .rangeUnavailable)
        XCTAssertTrue(reader.rangeReads.isEmpty)
    }

    func testRangeBeyondCharacterCountIsUnusable() {
        let field = focus("Hello there", "there")
        field.integers[kAXNumberOfCharactersAttribute] = 3

        let result = capture().resolve(copiedText: "there")

        XCTAssertEqual(reason(of: result), .rangeUnavailable)
    }

    func testWholeFieldSelectedHasNoSurroundingText() {
        focus("Hello there", "Hello there")

        let result = capture().resolve(copiedText: "Hello there")

        XCTAssertEqual(reason(of: result), .noSurroundingText)
    }

    func testMostlyObjectReplacementCharactersIsUnusable() {
        let placeholders = String(repeating: "\u{FFFC}", count: 10)
        focus(placeholders + " ok " + placeholders, "ok")

        let result = capture().resolve(copiedText: "ok")

        XCTAssertEqual(reason(of: result), .mostlyPlaceholderText)
    }

    // MARK: - Helpers

    /// Focuses a text area holding `value` with the first `selected`
    /// occurrence selected.
    @discardableResult
    private func focus(_ value: String, _ selected: String) -> FakeAXNode {
        let selection = (value as NSString).range(of: selected)
        let field = FakeAXNode.textArea(value, selection: selection)
        reader.app.elements[kAXFocusedUIElementAttribute] = field
        return field
    }

    private func request(
        mode: AccessibilityContextMode = .field,
        bundleId: String = "com.tinyspeck.slackmacgap"
    ) -> AccessibilityContextRequest {
        AccessibilityContextRequest(
            mode: mode,
            processID: 42,
            appName: "Slack",
            bundleId: bundleId,
            bundleURL: nil
        )
    }

    private func capture(
        mode: AccessibilityContextMode = .field,
        bundleId: String = "com.tinyspeck.slackmacgap"
    ) -> AccessibilityContextCapture {
        AccessibilityContextCapturer(reader: reader)
            .capture(request(mode: mode, bundleId: bundleId))
    }

    private func usableContext(
        copiedText: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> AccessibilityContext {
        let result = capture().resolve(copiedText: copiedText)
        switch result {
        case .usable(let context):
            return context
        case .unusable(let reason, let partial):
            XCTFail("Unusable: \(reason)", file: file, line: line)
            return partial
        }
    }

    private func reason(
        of result: AccessibilityContextResult
    ) -> AccessibilityContext.UnusableReason? {
        guard case .unusable(let reason, _) = result else { return nil }
        return reason
    }
}
